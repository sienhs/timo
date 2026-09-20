// Node.js + AWS CLI + Terraform; works from PowerShell and Linux.
import { execFileSync, spawnSync } from 'node:child_process';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.dirname(fileURLToPath(import.meta.url));
const temp = path.join(root, '.tmp');
let resultDirectory;
process.on('uncaughtException', error => {
  if (resultDirectory) fs.writeFileSync(path.join(resultDirectory, 'report.md'), `# 실행 오류\n\n- 판정: 측정 무효\n- 원인: ${error.message}\n- 조치: SSM 명령/앱 상태 확인 후 재실행\n`);
  console.error(error.message);
  process.exitCode = 1;
});
fs.mkdirSync(temp, { recursive: true });
const cli = (name, args) => execFileSync(name, args, { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
const config = JSON.parse(cli('terraform', [`-chdir=${path.join(root, '../infra/loadtest')}`, 'output', '-json', 'test']));
const aws = (...args) => JSON.parse(cli('aws', [...args, '--region', config.region, '--output', 'json']));
const quote = s => "'" + String(s).replaceAll("'", "'\\''") + "'";
function readHttpStatuses(rawPath) {
  const statuses = {};
  for (const line of fs.readFileSync(rawPath, 'utf8').split(/\r?\n/)) {
    if (!line) continue;
    const point = JSON.parse(line);
    if (point.type !== 'Point' || point.metric !== 'http_req_duration') continue;
    const tags = point.data.tags || {};
    const endpoint = tags.name || 'unclassified';
    const status = tags.status || (tags.error_code ? `network:${tags.error_code}` : 'unknown');
    const key = `${endpoint} ${status}`;
    statuses[key] = (statuses[key] || 0) + 1;
  }
  return statuses;
}
async function remote(instance, script, timeout = 3600) {
  const file = path.join(temp, 'command.json');
  fs.writeFileSync(file, JSON.stringify({ DocumentName: 'AWS-RunShellScript', InstanceIds: [instance], Parameters: { commands: [script], executionTimeout: [String(timeout)] } }), { mode: 0o600 });
  let id;
  try { id = aws('ssm', 'send-command', '--cli-input-json', `file://${file}`).Command.CommandId; }
  finally { fs.unlinkSync(file); }
  const deadline = Date.now() + (timeout + 120) * 1000;
  while (Date.now() < deadline) {
    await new Promise(r => setTimeout(r, 5000));
    let r;
    try { r = aws('ssm', 'get-command-invocation', '--command-id', id, '--instance-id', instance); }
    catch (e) { if (String(e.stderr).includes('InvocationDoesNotExist')) continue; throw e; }
    if (['Pending', 'InProgress', 'Delayed'].includes(r.Status)) continue;
    if (r.Status !== 'Success') throw new Error(`SSM ${id}: ${r.Status}\n${r.StandardOutputContent}\n${r.StandardErrorContent}`);
    return r.StandardOutputContent;
  }
  throw new Error(`SSM wait expired: ${id}. Inspect/cancel this command before retrying.`);
}
function upload(files) {
  return 'set -eu\nmkdir -p /opt/loadtest\nchmod 700 /opt/loadtest\n' + files.map(([source, destination]) =>
    `printf %s ${quote(fs.readFileSync(source).toString('base64'))} | base64 -d > /opt/loadtest/${destination}`).join('\n') + '\n';
}
async function collectAppDiagnostics(dir, since) {
  try {
    const output = await remote(config.app_id, `set -eu
if docker container inspect timo-loadtest >/dev/null 2>&1; then
  printf '%s\\n' '=== docker stats ==='
  docker stats --no-stream --format '{{json .}}' timo-loadtest || true
  printf '%s\\n' '=== recent application log ==='
  docker logs --since ${quote(since)} --tail 600 timo-loadtest 2>&1 || true
fi`, 120);
    fs.writeFileSync(path.join(dir, 'app-log-tail.txt'), output);
  } catch (error) {
    fs.writeFileSync(path.join(dir, 'app-log-tail.txt'), `Could not collect app diagnostics: ${error.message}\n`);
  }
}
const action = process.argv[2];
if (action === 'prepare') {
  const password = process.env.TF_VAR_db_password;
  if (!password || /[\r\n]/.test(password)) throw new Error('TF_VAR_db_password required');
  console.log('Preparing empty test DB and application (SSM app must be Online)...');
  await remote(config.app_id, upload([[path.join(root, '../infra/bootstrap/init.sql'), 'schema.sql'], [path.join(root, 'seed.py'), 'seed.py'], [path.join(root, 'prepare.sh'), 'prepare.sh']]) +
    `export TEST_DB_PASSWORD=${quote(password)} DB_HOST=${quote(config.db_host)} IMAGE=${quote(config.image)} AWS_REGION=${quote(config.region)}\nbash /opt/loadtest/prepare.sh`, 1800);
  console.log('Ready.');
} else if (action === 'run') {
  const users = Number(process.argv[3] || 50);
  const duration = process.argv[4] || '5m';
  if (!Number.isInteger(users) || users < 1 || users > 2000 || !/^\d+[ms]$/.test(duration)) throw new Error('run USERS(1..2000) DURATION(e.g. 5m)');
  const seconds = parseInt(duration) * (duration.endsWith('m') ? 60 : 1);
  if (seconds < 1 || seconds > 1800) throw new Error('Duration must be 1s..30m');
  const stamp = new Date().toISOString().replaceAll(':', '-');
  const dir = path.join(root, 'results', `${stamp}-${users}vu`);
  fs.mkdirSync(dir, { recursive: true });
  resultDirectory = dir;
  const generator = { location: 'local', os: `${os.platform()} ${os.release()}`, cpu: os.cpus()[0]?.model, logicalCpus: os.cpus().length, memoryGiB: Math.round(os.totalmem() / 1024 ** 3), k6: cli('k6', ['version']).trim() };
  fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify({ ...config, generator, users, duration, started: stamp }, null, 2));
  const started = new Date().toISOString();
  console.log(`Running ${users} VUs for ${duration}; results: ${dir}`);
  // Each invocation has its own thresholds and summary. k6 exit 99 is a measured failure.
  const summaryPath = path.join(dir, 'summary.json');
  const rawPath = path.join(dir, 'k6-raw.json');
  const run = spawnSync('k6', ['run', '--out', `json=${rawPath}`, path.join(root, 'booking.js')], {
    stdio: 'inherit',
    env: { ...process.env, BASE_URL: config.base_url, USERS: String(users), DURATION: duration, SUMMARY_PATH: summaryPath },
  });
  await collectAppDiagnostics(dir, started);
  if (run.error) throw run.error;
  if (![0, 99].includes(run.status)) throw new Error(`Local k6 failed: exit=${run.status}, signal=${run.signal}`);
  const metrics = JSON.parse(fs.readFileSync(summaryPath, 'utf8')).metrics;
  const failed = Object.values(metrics).some(m => Object.values(m.thresholds || {}).some(t => !t.ok));
  const value = (name, key) => metrics[name]?.values?.[key];
  const monitoring = {};
  for (const [label, namespace, metric, dimension, id] of [
    ['app_cpu', 'AWS/EC2', 'CPUUtilization', 'InstanceId', config.app_id],
    ['app_credits', 'AWS/EC2', 'CPUCreditBalance', 'InstanceId', config.app_id],
    ['db_cpu', 'AWS/RDS', 'CPUUtilization', 'DBInstanceIdentifier', config.db_id],
    ['db_connections', 'AWS/RDS', 'DatabaseConnections', 'DBInstanceIdentifier', config.db_id],
  ]) {
    try { monitoring[label] = aws('cloudwatch', 'get-metric-statistics', '--namespace', namespace, '--metric-name', metric, '--dimensions', `Name=${dimension},Value=${id}`, '--start-time', started, '--end-time', new Date().toISOString(), '--period', '60', '--statistics', 'Maximum', 'Minimum'); }
    catch { monitoring[label] = { error: 'Metric unavailable; check CloudWatch manually' }; }
  }
  fs.writeFileSync(path.join(dir, 'cloudwatch.json'), JSON.stringify(monitoring, null, 2));
  const statuses = readHttpStatuses(rawPath);
  fs.writeFileSync(path.join(dir, 'http-status.json'), JSON.stringify(statuses, null, 2));
  const failedStatuses = Object.entries(statuses)
    .filter(([name]) => !name.endsWith(' 200'))
    .sort(([, left], [, right]) => right - left)
    .map(([name, count]) => `- ${name}: ${count}건`)
    .join('\n') || '- 없음';
  const report = `# 부하테스트 ${stamp}\n\n- 환경: t3.medium / ${config.db_class} / MySQL ${config.db_engine} / ${config.cpu_credits}\n- 이미지: \`${config.image}\`\n- 발생기: 로컬 PC / ${generator.cpu} / ${generator.memoryGiB} GiB / ${generator.k6}\n- 측정 경로: 로컬 인터넷 → 앱 public IP (네트워크 지연 포함)\n- 조건: ${users}명, ${duration}, 회차별 2초 대기, 계정·좌석 2,000개\n- 범위: 공연 → 구역 → 좌석 → 선점 → 해제 (로그인·결제 제외)\n\n| 성공률 | 흐름 p95 | 선점 p95 | 완료 flows/s | SLO 판정 |\n|---:|---:|---:|---:|---|\n| ${((value('flow_success','rate') || 0)*100).toFixed(2)}% | ${value('flow_ms','p(95)')?.toFixed(1) ?? '-'} ms | ${value('hold_ms','p(95)')?.toFixed(1) ?? '-'} ms | ${value('completed_flows','rate')?.toFixed(2) ?? '0'} | ${failed ? '실패' : '통과'} |\n\n## 실패 HTTP 상태\n\n${failedStatuses}\n\n- 원본 상태 집계: \`http-status.json\`\n- 앱 로그·메모리: \`app-log-tail.txt\`\n- 병목/자원 확인: 미기록 (cloudwatch.json, 앱 메모리, 발생기 포화 확인 후 작성)\n- 최종 판단: 미확정 (워밍업·발생기 포화 구간 제외, 30분 유지 통과 시 확정)\n`;
  fs.writeFileSync(path.join(dir, 'report.md'), report);
  console.log(report);
  if (failed) process.exitCode = 2;
} else {
  throw new Error('Usage: node loadtest/run.mjs prepare | run USERS DURATION');
}
