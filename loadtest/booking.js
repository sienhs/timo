import http from 'k6/http';
import { sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { Rate, Trend, Counter } from 'k6/metrics';

const base = __ENV.BASE_URL;
const users = Number(__ENV.USERS || 50);
const ignoreFlowSlo = __ENV.IGNORE_FLOW_SLO === 'true';
const waitSeconds = Number(__ENV.QUEUE_WAIT_SECONDS || 1800);
const ingressSpreadSeconds = Number(__ENV.QUEUE_INGRESS_SPREAD_SECONDS || 0);
if (!base || !Number.isInteger(users) || users < 1 || users > 10000) throw new Error('BASE_URL and USERS (1..10000) required');
if (!__ENV.TOKEN_PATH) throw new Error('TOKEN_PATH required; run through loadtest/run.mjs');
if (!Number.isFinite(ingressSpreadSeconds) || ingressSpreadSeconds < 0 || ingressSpreadSeconds > 600) throw new Error('QUEUE_INGRESS_SPREAD_SECONDS must be 0..600');
const tokens = new SharedArray('preauthenticated load-test tokens', () => JSON.parse(open(__ENV.TOKEN_PATH)));
if (tokens.length !== users) throw new Error(`Expected ${users} preauthenticated tokens, got ${tokens.length}`);
const success = new Rate('flow_success');
const duration = new Trend('flow_ms', true);
const holdTime = new Trend('hold_ms', true);
const queueJoinTime = new Trend('queue_join_ms', true);
const queueAdmissionTime = new Trend('queue_admission_ms', true);
const queuePolls = new Counter('queue_poll_attempts');
const queueWaitingResponses = new Counter('queue_waiting_responses');
const queueAdmittedResponses = new Counter('queue_admitted_responses');
const queueAdmissionTimeouts = new Counter('queue_admission_timeouts');
const completed = new Counter('completed_flows');
export const options = {
  setupTimeout: '45m',
  scenarios: { booking: { executor: 'per-vu-iterations', vus: users, iterations: 1, maxDuration: __ENV.DURATION || '35m', gracefulStop: '30s' } },
  // The ALB is immutable for one disposable test. Retain the initial IPv4
  // answers so a 5-minute DNS cache expiry cannot re-resolve thousands of
  // pollers concurrently on the local Windows resolver.
  dns: { ttl: 'inf', select: 'roundRobin', policy: 'onlyIPv4' },
  // status and name are exported into k6's raw output and used to explain a
  // failed plateau without storing request headers or authentication tokens.
  systemTags: ['status', 'name', 'error', 'error_code'],
  thresholds: {
    flow_success: ['rate==1'],
    http_req_failed: ['rate==0'],
    ...(ignoreFlowSlo ? {} : { flow_ms: ['p(95)<=4000'], hold_ms: ['p(95)<=1500'], queue_join_ms: ['p(95)<=1000'] }),
    completed_flows: [`count==${users}`],
  },
};
export default function () {
  const token = tokens[__VU - 1];
  // Preserve a 10,000-user arrival event without opening 10,000 local TCP
  // connections at the same instant. The polling cadence below is unchanged.
  if (ingressSpreadSeconds > 0) sleep((__VU - 1) * ingressSpreadSeconds / users);
  let joined = false;
  let holdAttempted = false;
  const params = (name) => ({ headers: { Authorization: `Bearer ${token}` }, tags: { name }, timeout: '30s' });
  const section = Math.ceil(__VU / 100);
  const start = Date.now();
  let ok = false;
  try {
    const queueStart = Date.now();
    joined = true;
    let queue;
    for (let attempt = 0; attempt < 3; attempt++) {
      queue = http.post(`${base}/api/v1/concerts/1/queue`, null, params('queue_join'));
      if (queue.status === 200) break;
      sleep(attempt + 1);
    }
    queueJoinTime.add(queue.timings.duration);
    if (queue.status !== 200) return;
    let admission = queue.json('admissionToken');
    if (admission) queueAdmittedResponses.add(1);
    else queueWaitingResponses.add(1);
    while (!admission && Date.now() - queueStart < waitSeconds * 1000) {
      sleep(0.8 + Math.random() * 0.4);
      queuePolls.add(1);
      const status = http.get(`${base}/api/v1/concerts/1/queue`, params('queue_status'));
      if (status.status !== 200) return;
      admission = status.json('admissionToken');
      if (admission) queueAdmittedResponses.add(1);
      else queueWaitingResponses.add(1);
    }
    queueAdmissionTime.add(Date.now() - queueStart);
    if (!admission) {
      queueAdmissionTimeouts.add(1);
      return;
    }
    if (http.get(`${base}/api/v1/concerts/1`, params('concert')).status !== 200) return;
    const sections = http.get(`${base}/api/v1/sections?concertId=1`, params('sections'));
    if (sections.status !== 200 || !sections.json('sections').some(s => s.id === section)) return;
    const seats = http.get(`${base}/api/v1/seats?concertId=1&sectionId=${section}`, params('seats'));
    if (seats.status !== 200 || !seats.json('seats').some(s => s.id === __VU)) return;
    holdAttempted = true;
    const hold = http.post(`${base}/api/v1/seats/${__VU}/hold?concertId=1`, null, params('hold'));
    holdTime.add(hold.timings.duration);
    ok = hold.status === 200;
  } finally {
    if (holdAttempted) {
      const release = http.del(`${base}/api/v1/seats/${__VU}/hold?concertId=1`, null, params('release'));
      ok = release.status === 200 && ok;
    }
    if (joined) {
      const leave = http.del(`${base}/api/v1/concerts/1/queue`, null, params('queue_leave'));
      ok = (leave.status === 200 || leave.status === 204) && ok;
    }
    if (ok) completed.add(1);
    success.add(ok);
    duration.add(Date.now() - start);
  }
}
export function handleSummary(data) {
  // setup_data holds access tokens. Test summaries must never persist them.
  delete data.setup_data;
  return { [__ENV.SUMMARY_PATH || 'summary.json']: JSON.stringify(data, null, 2) };
}
