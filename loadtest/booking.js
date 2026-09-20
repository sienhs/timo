import http from 'k6/http';
import { sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const base = __ENV.BASE_URL;
const users = Number(__ENV.USERS || 50);
if (!base || !Number.isInteger(users) || users < 1 || users > 2000) throw new Error('BASE_URL and USERS (1..2000) required');
const success = new Rate('flow_success');
const duration = new Trend('flow_ms', true);
const holdTime = new Trend('hold_ms', true);
const completed = new Counter('completed_flows');
export const options = {
  setupTimeout: '15m',
  scenarios: { booking: { executor: 'constant-vus', vus: users, duration: __ENV.DURATION || '5m', gracefulStop: '30s' } },
  // status and name are exported into k6's raw output and used to explain a
  // failed plateau without storing request headers or authentication tokens.
  systemTags: ['status', 'name', 'error', 'error_code'],
  thresholds: { flow_success: ['rate>=0.99'], flow_ms: ['p(95)<=3000'], hold_ms: ['p(95)<=1500'], completed_flows: ['count>0'] },
};
export function setup() {
  const tokens = [];
  for (let i = 1; i <= users; i++) {
    const r = http.post(`${base}/api/v1/auth/login`, JSON.stringify({ username: `loadtest${String(i).padStart(4, '0')}`, password: 'password' }), {
      headers: { 'Content-Type': 'application/json', 'X-Device-Id': `loadtest-${i}` }, tags: { name: 'setup_login' }, timeout: '10s',
    });
    if (r.status !== 200 || !r.json('accessToken')) throw new Error(`Login failed for account ${i}: ${r.status}`);
    tokens.push(r.json('accessToken'));
  }
  return tokens;
}
export default function (tokens) {
  const params = (name) => ({ headers: { Authorization: `Bearer ${tokens[__VU - 1]}` }, tags: { name }, timeout: '10s' });
  const section = Math.ceil(__VU / 100);
  const start = Date.now();
  let ok = false;
  try {
    if (http.get(`${base}/api/v1/concerts/1`, params('concert')).status !== 200) return;
    const sections = http.get(`${base}/api/v1/sections?concertId=1`, params('sections'));
    if (sections.status !== 200 || !sections.json('sections').some(s => s.id === section)) return;
    const seats = http.get(`${base}/api/v1/seats?concertId=1&sectionId=${section}`, params('seats'));
    if (seats.status !== 200 || !seats.json('seats').some(s => s.id === __VU)) return;
    const hold = http.post(`${base}/api/v1/seats/${__VU}/hold?concertId=1`, null, params('hold'));
    holdTime.add(hold.timings.duration);
    // Also release after a timeout: the server may have committed the hold.
    const release = http.del(`${base}/api/v1/seats/${__VU}/hold?concertId=1`, null, params('release'));
    ok = hold.status === 200 && release.status === 200;
    if (ok) completed.add(1);
  } finally {
    success.add(ok);
    duration.add(Date.now() - start);
    sleep(2); // Pace failures too; avoid a retry storm.
  }
}
export function handleSummary(data) {
  // setup_data holds access tokens. Test summaries must never persist them.
  delete data.setup_data;
  return { [__ENV.SUMMARY_PATH || 'summary.json']: JSON.stringify(data, null, 2) };
}
