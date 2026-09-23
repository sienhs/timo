// Node.js + AWS CLI + Terraform; works from PowerShell and Linux.
import { execFileSync, spawn } from 'node:child_process';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { randomBytes } from 'node:crypto';
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
async function readHttpStatuses(rawPath) {
  const statuses = {};
  const lines = readline.createInterface({ input: fs.createReadStream(rawPath, { encoding: 'utf8' }), crlfDelay: Infinity });
  for await (const line of lines) {
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
  const file = path.join(temp, `command-${randomBytes(8).toString('hex')}.json`);
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
const pause = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
async function preauthenticate(users) {
  const concurrency = Number(process.env.PRELOGIN_CONCURRENCY || 20);
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 100) throw new Error('PRELOGIN_CONCURRENCY must be 1..100');
  const tokens = new Array(users);
  let next = 0;
  async function worker() {
    while (true) {
      const index = next++;
      if (index >= users) return;
      let lastError = 'unknown error';
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const response = await fetch(`${config.base_url}/api/v1/auth/login`, {
            method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Device-Id': `loadtest-${index + 1}` },
            body: JSON.stringify({ username: `loadtest${String(index + 1).padStart(4, '0')}`, password: 'password' }), signal: AbortSignal.timeout(30000),
          });
          const body = await response.json().catch(() => ({}));
          if (response.status === 200 && body.accessToken) { tokens[index] = body.accessToken; break; }
          lastError = `HTTP ${response.status}`;
        } catch (error) { lastError = error.message; }
        await pause((attempt + 1) * 1000);
      }
      if (!tokens[index]) throw new Error(`Pre-login failed for user ${index + 1}: ${lastError}`);
      await pause(200);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, users) }, worker));
  return tokens;
}
async function collectAppDiagnostics(dir, since) {
  const diagnostics = await Promise.all(config.app_ids.map(async instance => {
    try {
      const output = await remote(instance, `set -eu
if docker container inspect timo-loadtest >/dev/null 2>&1; then
  printf '%s\\n' '=== docker stats ==='
  docker stats --no-stream --format '{{json .}}' timo-loadtest || true
  printf '%s\\n' '=== recent application log ==='
  docker logs --since ${quote(since)} --tail 600 timo-loadtest 2>&1 || true
fi`, 120);
      return `=== ${instance} ===\n${output}`;
    } catch (error) { return `=== ${instance} ===\nCould not collect app diagnostics: ${error.message}\n`; }
  }));
  fs.writeFileSync(path.join(dir, 'app-log-tail.txt'), diagnostics.join('\n'));
}
const action = process.argv[2];
if (action === 'prepare') {
  const password = process.env.TF_VAR_db_password;
  if (!password || /[\r\n]/.test(password)) throw new Error('TF_VAR_db_password required');
  console.log(`Preparing empty test DB and ${config.app_ids.length} application instances (SSM must be Online)...`);
  let online = false;
  let lastInfo = [];
  for (let attempt = 0; attempt < 120; attempt++) {
    const info = aws('ssm', 'describe-instance-information', '--filters', `Key=InstanceIds,Values=${config.app_ids.join(',')}`).InstanceInformationList;
    lastInfo = info;
    online = config.app_ids.every(id => info.some(i => i.InstanceId === id && i.PingStatus === 'Online'));
    if (online) break;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  if (!online) {
    const status = config.app_ids.map(id => {
      const instance = lastInfo.find(info => info.InstanceId === id);
      return `${id}: ${instance ? instance.PingStatus : 'not registered'}`;
    }).join(', ');
    throw new Error(`Application SSM agents did not become Online within 10 minutes (${status})`);
  }
  const sharedSecrets = { JWT_SECRET: randomBytes(32).toString('hex'), ENTRY_PASS_SECRET: randomBytes(32).toString('hex'), WALLET_MASTER_KEY: randomBytes(32).toString('hex') };
  const dbPoolSize = process.env.LOADTEST_DB_POOL_SIZE || '20';
  const sharedEnvironment = `export TEST_DB_PASSWORD=${quote(password)} DB_HOST=${quote(config.db_host)} REDIS_HOST=${quote(config.redis_host)} REDIS_PORT=${quote(config.redis_port)} REDIS_PASSWORD=${quote(process.env.TF_VAR_redis_auth_token)} WAITING_QUEUE_ACTIVE_LIMIT=${quote(config.queue_active_limit)} IMAGE=${quote(config.image)} AWS_REGION=${quote(config.region)} LOADTEST_USERS=${quote(process.env.LOADTEST_USERS || '10000')} APP_INSTANCE_COUNT=${quote(config.app_ids.length)} DB_POOL_SIZE=${quote(dbPoolSize)} JWT_SECRET=${quote(sharedSecrets.JWT_SECRET)} ENTRY_PASS_SECRET=${quote(sharedSecrets.ENTRY_PASS_SECRET)} WALLET_MASTER_KEY=${quote(sharedSecrets.WALLET_MASTER_KEY)}`;
  const files = upload([[path.join(root, '../infra/bootstrap/init.sql'), 'schema.sql'], [path.join(root, 'seed.py'), 'seed.py'], [path.join(root, 'prepare.sh'), 'prepare.sh']]);
  await remote(config.app_ids[0], `${files}${sharedEnvironment} INITIALIZE_DB=true\nbash /opt/loadtest/prepare.sh`, 1800);
  await Promise.all(config.app_ids.slice(1).map(instance => remote(instance, `${files}${sharedEnvironment}\nbash /opt/loadtest/prepare.sh`, 1800)));
  let healthy = false;
  for (let attempt = 0; attempt < 60; attempt++) {
    const targets = aws('elbv2', 'describe-target-health', '--target-group-arn', config.target_group_arn).TargetHealthDescriptions;
    healthy = config.app_ids.every(id => targets.some(t => t.Target.Id === id && t.TargetHealth.State === 'healthy'));
    if (healthy) break;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  if (!healthy) throw new Error('Not all application instances became healthy in ALB within 5 minutes');
  console.log('Ready.');
} else if (action === 'run') {
  const users = Number(process.argv[3] || 50);
  const duration = process.argv[4] || '5m';
  if (!Number.isInteger(users) || users < 1 || users > 10000 || !/^\d+[ms]$/.test(duration)) throw new Error('run USERS(1..10000) DURATION(e.g. 5m)');
  const seconds = parseInt(duration) * (duration.endsWith('m') ? 60 : 1);
  if (seconds < 1 || seconds > 3600) throw new Error('Duration must be 1s..60m');
  const stamp = new Date().toISOString().replaceAll(':', '-');
  const dir = path.join(root, 'results', `${stamp}-${users}vu`);
  fs.mkdirSync(dir, { recursive: true });
  resultDirectory = dir;
  const generator = { location: 'local', os: `${os.platform()} ${os.release()}`, cpu: os.cpus()[0]?.model, logicalCpus: os.cpus().length, memoryGiB: Math.round(os.totalmem() / 1024 ** 3), k6: cli('k6', ['version']).trim() };
  const dbPoolSize = process.env.LOADTEST_DB_POOL_SIZE || '20';
  const ingressSpreadSeconds = Number(process.env.QUEUE_INGRESS_SPREAD_SECONDS || 0);
  if (!Number.isFinite(ingressSpreadSeconds) || ingressSpreadSeconds < 0 || ingressSpreadSeconds > 600) throw new Error('QUEUE_INGRESS_SPREAD_SECONDS must be 0..600');
  fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify({ ...config, generator, users, duration, dbPoolSize, ingressSpreadSeconds, started: stamp }, null, 2));
  console.log(`Pre-authenticating ${users} users at low concurrency; login is excluded from the measurement...`);
  const tokenPath = path.join(temp, `tokens-${randomBytes(8).toString('hex')}.json`);
  const tokens = await preauthenticate(users);
  fs.writeFileSync(tokenPath, JSON.stringify(tokens), { mode: 0o600 });
  const started = new Date().toISOString();
  console.log(`Running ${users} VUs for ${duration}; queue ingress spread: ${ingressSpreadSeconds}s; results: ${dir}`);
  // Each invocation has its own thresholds and summary. k6 exit 99 is a measured failure.
  const summaryPath = path.join(dir, 'summary.json');
  const rawPath = path.join(dir, 'k6-raw.json');
  const resourceSamples = [];
  let previousCpu = os.cpus();
  const sampler = setInterval(() => {
    const current = os.cpus();
    let idle = 0, total = 0;
    current.forEach((cpu, index) => { for (const key of Object.keys(cpu.times)) { const delta = cpu.times[key] - previousCpu[index].times[key]; total += delta; if (key === 'idle') idle += delta; } });
    previousCpu = current;
    resourceSamples.push({ at: new Date().toISOString(), hostCpuPercent: total ? 100 * (1 - idle / total) : 0, freeMemoryBytes: os.freemem(), totalMemoryBytes: os.totalmem() });
  }, 5000);
  let run;
  try {
    run = await new Promise((resolve, reject) => {
      const child = spawn('k6', ['run', '--out', `json=${rawPath}`, path.join(root, 'booking.js')], {
        stdio: 'inherit',
        env: { ...process.env, BASE_URL: config.base_url, USERS: String(users), DURATION: duration, SUMMARY_PATH: summaryPath, TOKEN_PATH: tokenPath, QUEUE_INGRESS_SPREAD_SECONDS: String(ingressSpreadSeconds) },
      });
      child.on('error', reject);
      child.on('close', (status, signal) => resolve({ status, signal }));
    });
  } finally {
    clearInterval(sampler);
    fs.rmSync(tokenPath, { force: true });
    fs.writeFileSync(path.join(dir, 'generator-resources.json'), JSON.stringify(resourceSamples, null, 2));
  }
  await collectAppDiagnostics(dir, started);
  if (run.error) throw run.error;
  if (![0, 99].includes(run.status)) throw new Error(`Local k6 failed: exit=${run.status}, signal=${run.signal}`);
  const metrics = JSON.parse(fs.readFileSync(summaryPath, 'utf8')).metrics;
  const failed = run.status === 99 || metrics.completed_flows?.values?.count !== users || metrics.iterations?.values?.count !== users || Object.values(metrics).some(m => Object.values(m.thresholds || {}).some(t => !t.ok));
  const value = (name, key) => metrics[name]?.values?.[key];
  const monitoring = {};
  monitoring.app_cpu = Object.fromEntries(config.app_ids.map(id => {
    try {
      return [id, aws('cloudwatch', 'get-metric-statistics', '--namespace', 'AWS/EC2', '--metric-name', 'CPUUtilization', '--dimensions', `Name=InstanceId,Value=${id}`, '--start-time', started, '--end-time', new Date().toISOString(), '--period', '60', '--statistics', 'Maximum', 'Minimum')];
    } catch { return [id, { error: 'Metric unavailable; check CloudWatch manually' }]; }
  }));
  for (const [label, namespace, metric, dimension, id] of [
    ['db_cpu', 'AWS/RDS', 'CPUUtilization', 'DBInstanceIdentifier', config.db_id],
    ['db_connections', 'AWS/RDS', 'DatabaseConnections', 'DBInstanceIdentifier', config.db_id],
    ['redis_engine_cpu', 'AWS/ElastiCache', 'EngineCPUUtilization', 'CacheClusterId', config.redis_cluster_id],
    ['redis_connections', 'AWS/ElastiCache', 'CurrConnections', 'CacheClusterId', config.redis_cluster_id],
    ['redis_freeable_memory', 'AWS/ElastiCache', 'FreeableMemory', 'CacheClusterId', config.redis_cluster_id],
  ]) {
    try { monitoring[label] = aws('cloudwatch', 'get-metric-statistics', '--namespace', namespace, '--metric-name', metric, '--dimensions', `Name=${dimension},Value=${id}`, '--start-time', started, '--end-time', new Date().toISOString(), '--period', '60', '--statistics', 'Maximum', 'Minimum'); }
    catch { monitoring[label] = { error: 'Metric unavailable; check CloudWatch manually' }; }
  }
  fs.writeFileSync(path.join(dir, 'cloudwatch.json'), JSON.stringify(monitoring, null, 2));
  const statuses = await readHttpStatuses(rawPath);
  fs.writeFileSync(path.join(dir, 'http-status.json'), JSON.stringify(statuses, null, 2));
  const failedStatuses = Object.entries(statuses)
    .filter(([name]) => !/ 2\d\d$/.test(name))
    .sort(([, left], [, right]) => right - left)
    .map(([name, count]) => `- ${name}: ${count}건`)
    .join('\n') || '- 없음';
  const report = `# 부하테스트 ${stamp}\n\n- 환경: ${config.app_instance_count} x ${config.app_instance_type} + ALB / ${config.db_class} / MySQL ${config.db_engine} / Hikari ${dbPoolSize} per app\n- 이미지: \`${config.image}\`\n- 발생기: 로컬 PC / ${generator.cpu} / ${generator.memoryGiB} GiB / ${generator.k6}\n- 측정 경로: 로컬 인터넷 → ALB\n- 조건: ${users}명, ${duration}, 사용자별 1회 실행, 최대 대기 30분, 최초 대기열 진입 ${ingressSpreadSeconds}초 균등 분산, 시드 10,000명\n- 사전 로그인: 20명씩 저부하로 완료한 뒤, 대기열 진입부터 측정\n- 범위: 대기열 진입 → 공연 → 구역 → 좌석 → 선점 → 해제 (로그인·결제 제외)\n\n| 성공률 | 흐름 p95 | 선점 p95 | 완료 flows/s | SLO 판정 |\n|---:|---:|---:|---:|---|\n| ${((value('flow_success','rate') || 0)*100).toFixed(2)}% | ${value('flow_ms','p(95)')?.toFixed(1) ?? '-'} ms | ${value('hold_ms','p(95)')?.toFixed(1) ?? '-'} ms | ${value('completed_flows','rate')?.toFixed(2) ?? '0'} | ${failed ? '실패' : '통과'} |\n\n## 실패 HTTP 상태\n\n${failedStatuses}\n\n- 원본 상태 집계: \`http-status.json\`\n- 앱 로그·메모리: \`app-log-tail.txt\`\n- 병목/자원 확인: 미기록 (cloudwatch.json, 앱 메모리, 발생기 포화 확인 후 작성)\n- 판정 범위: 고유 사용자 ${users}명 각 1회 완료; 지속 동시 접속 수용량은 별도 검증. 발생기 자원: generator-resources.json\n`;
  const queueDiagnostics = '\n\n## 대기열 승격\n\n'
    + '- 입장 대기 p95: ' + (value('queue_admission_ms', 'p(95)')?.toFixed(1) ?? '-') + ' ms\n'
    + '- 폴링 횟수: ' + (value('queue_poll_attempts', 'count') ?? 0) + '\n'
    + '- 입장 응답: ' + (value('queue_admitted_responses', 'count') ?? 0) + '\n'
    + '- 대기 응답: ' + (value('queue_waiting_responses', 'count') ?? 0) + '\n'
    + '- 폴링 시간 초과: ' + (value('queue_admission_timeouts', 'count') ?? 0) + '\n'
    + '- Redis 자원 지표: cloudwatch.json\n';
  fs.writeFileSync(path.join(dir, 'report.md'), report + queueDiagnostics);
  console.log(report + queueDiagnostics);
  if (failed) process.exitCode = 2;
} else {
  throw new Error('Usage: node loadtest/run.mjs prepare | run USERS DURATION');
}
