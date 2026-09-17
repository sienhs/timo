import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Concurrent active-user capacity test for the real DB-backed booking-entry flow:
// concert -> sections -> seats -> hold -> release.
// Login happens only in setup(), outside the measured flow.
const BASE_URL = (__ENV.BASE_URL || '').replace(/\/$/, '');
const CONCERT_ID = Number(__ENV.CONCERT_ID || 1);
const SECTION_ID = __ENV.SECTION_ID ? Number(__ENV.SECTION_ID) : null;
const MAX_CONCURRENT_USERS = Number(__ENV.MAX_CONCURRENT_USERS || 1000);
const ACCOUNT_COUNT = Number(__ENV.ACCOUNT_COUNT || MAX_CONCURRENT_USERS);
const LOGIN_BATCH_SIZE = Number(__ENV.LOGIN_BATCH_SIZE || 10);

if (!BASE_URL) throw new Error('BASE_URL is required. Example: https://your-real-api-domain');
if (!/^https?:\/\/[^\s/]+(?:\/[^\s]*)?$/.test(BASE_URL)) {
  throw new Error('BASE_URL must be a raw URL such as https://your-real-api-domain, not a Markdown link.');
}
if (BASE_URL.includes('api.example.com')) {
  throw new Error('BASE_URL still uses api.example.com, which is only a documentation placeholder.');
}
if (!Number.isInteger(CONCERT_ID) || CONCERT_ID < 1) throw new Error('CONCERT_ID must be a positive integer.');
if (SECTION_ID !== null && (!Number.isInteger(SECTION_ID) || SECTION_ID < 1)) {
  throw new Error('SECTION_ID must be a positive integer when supplied.');
}
if (!Number.isInteger(MAX_CONCURRENT_USERS) || MAX_CONCURRENT_USERS < 1) {
  throw new Error('MAX_CONCURRENT_USERS must be a positive integer.');
}
if (ACCOUNT_COUNT < MAX_CONCURRENT_USERS) {
  throw new Error('ACCOUNT_COUNT must be at least MAX_CONCURRENT_USERS so every VU has its own account.');
}

const completedFlows = new Counter('booking_entry_flow_completed');
const flowCompletion = new Rate('booking_entry_flow_completion');
const flowDuration = new Trend('booking_entry_flow_duration', true);
const holdDuration = new Trend('seat_hold_duration', true);
const serverErrorRate = new Rate('server_error_rate');

const USER_LEVELS = [0.1, 0.2, 0.3, 0.5, 0.75, 1]
  .map((ratio) => Math.round(MAX_CONCURRENT_USERS * ratio));
const VU_STAGES = [];
for (const users of USER_LEVELS) {
  VU_STAGES.push({ duration: '1m', target: users });
  VU_STAGES.push({ duration: '5m', target: users });
}
VU_STAGES.push({ duration: '2m', target: 0 });

// A 409 can occur if another test VU gets the same AVAILABLE seat immediately
// before this VU. It is tracked as a failed flow, but not as a transport error.
http.setResponseCallback(http.expectedStatuses({ min: 200, max: 299 }, 409));

export const options = {
  // setup() logs in up to 1,000 accounts in small batches so authentication
  // does not spike the target. k6 defaults this phase to 60 seconds.
  setupTimeout: '5m',
  scenarios: {
    booking_entry_throughput: {
      // Fixed VU plateaus establish the maximum stable concurrent-user count.
      executor: 'ramping-vus',
      startVUs: 0,
      stages: VU_STAGES,
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    server_error_rate: ['rate<0.001'],
    booking_entry_flow_completion: ['rate>0.99'],
    booking_entry_flow_duration: ['p(95)<3000'],
    seat_hold_duration: ['p(95)<1500'],
  },
};

function authParams(token, name) {
  return { headers: { Authorization: `Bearer ${token}` }, tags: { name } };
}

function accountName(index) {
  return `loadtest${String(index).padStart(4, '0')}`;
}

function loginRequest(index) {
  return {
    method: 'POST',
    url: `${BASE_URL}/api/v1/auth/login`,
    body: JSON.stringify({ username: accountName(index), password: 'password' }),
    params: {
      headers: {
        'Content-Type': 'application/json',
        'X-Device-Id': `k6-seat-throughput-${String(index).padStart(4, '0')}`,
      },
      tags: { name: 'login_setup' },
    },
  };
}

function readLogin(index, response) {
  const valid = check(response, {
    'setup login returned 200': (r) => r.status === 200,
    'setup login returned access token': (r) => {
      try { return Boolean(r.json('accessToken')); } catch (_) { return false; }
    },
  });
  if (!valid) throw new Error(`Login failed for ${accountName(index)} (HTTP ${response.status}).`);
  return { index, token: response.json('accessToken') };
}

export function setup() {
  // Authentication overhead must not influence booking-flow throughput.
  const accounts = [];
  for (let first = 1; first <= ACCOUNT_COUNT; first += LOGIN_BATCH_SIZE) {
    const last = Math.min(first + LOGIN_BATCH_SIZE - 1, ACCOUNT_COUNT);
    const indexes = [];
    const requests = [];
    for (let index = first; index <= last; index += 1) {
      indexes.push(index);
      requests.push(loginRequest(index));
    }
    const responses = http.batch(requests);
    for (let offset = 0; offset < responses.length; offset += 1) {
      accounts.push(readLogin(indexes[offset], responses[offset]));
    }
  }
  return { accounts };
}

function accountForThisVu(data) {
  return data.accounts[__VU - 1];
}

function recordServerError(response) {
  serverErrorRate.add(response.status >= 500 && response.status < 600);
}

function selectSection(token) {
  const response = http.get(
    `${BASE_URL}/api/v1/sections?concertId=${CONCERT_ID}`,
    authParams(token, 'sections'),
  );
  recordServerError(response);
  if (!check(response, { 'section query returned 200': (r) => r.status === 200 })) return null;

  const sections = response.json('sections');
  if (!Array.isArray(sections)) return null;
  if (SECTION_ID !== null) return sections.find((section) => section.id === SECTION_ID) || null;
  return sections.find((section) => section.availableCount > 0) || null;
}

function selectSeat(token, sectionId, account) {
  const response = http.get(
    `${BASE_URL}/api/v1/seats?concertId=${CONCERT_ID}&sectionId=${sectionId}`,
    authParams(token, 'seats'),
  );
  recordServerError(response);
  if (!check(response, { 'seat query returned 200': (r) => r.status === 200 })) return null;

  const seats = response.json('seats');
  if (!Array.isArray(seats)) return null;
  const available = seats.filter((seat) => seat.status === 'AVAILABLE');
  if (available.length === 0) return null;
  // Spread users across seats. A same-seat race is intentionally out of scope.
  return available[(account.index * 37 + __ITER) % available.length];
}

function holdAndRelease(token, seatId) {
  const hold = http.post(
    `${BASE_URL}/api/v1/seats/${seatId}/hold?concertId=${CONCERT_ID}`,
    null,
    authParams(token, 'seat_hold'),
  );
  recordServerError(hold);
  holdDuration.add(hold.timings.duration);
  if (!check(hold, { 'seat hold returned 200': (r) => r.status === 200 })) return false;

  const release = http.del(
    `${BASE_URL}/api/v1/seats/${seatId}/hold?concertId=${CONCERT_ID}`,
    null,
    authParams(token, 'seat_hold_cancel'),
  );
  recordServerError(release);
  return check(release, { 'seat hold release returned 200': (r) => r.status === 200 });
}

export default function (data) {
  const startedAt = Date.now();
  const account = accountForThisVu(data);
  let completed = false;

  // 1. Concert detail: user enters the concert page.
  const concert = http.get(
    `${BASE_URL}/api/v1/concerts/${CONCERT_ID}`,
    authParams(account.token, 'concert_detail'),
  );
  recordServerError(concert);
  if (!check(concert, { 'concert detail returned 200': (r) => r.status === 200 })) {
    flowCompletion.add(false);
    return;
  }

  // 2. Sections provide sectionId required by the seat map.
  const section = selectSection(account.token);
  if (section === null) {
    flowCompletion.add(false);
    return;
  }

  // 3. Seat map, 4. seat hold, then test-data cleanup.
  const seat = selectSeat(account.token, section.id, account);
  if (seat !== null) completed = holdAndRelease(account.token, seat.id);

  flowCompletion.add(completed);
  if (completed) {
    completedFlows.add(1);
    flowDuration.add(Date.now() - startedAt);
  }

  sleep(0.2 + Math.random() * 0.3);
}
