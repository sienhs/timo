import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = fs.readFileSync(new URL('./booking.js', import.meta.url), 'utf8')
  .replace(/^import .*;\n/gm, '').replace('export default function', 'function flow').replaceAll('export ', '');
function execute(failAt) {
  const metrics = {}, calls = [], sleeps = [];
  class Metric { constructor(name) { this.name = name; metrics[name] = []; } add(v) { metrics[this.name].push(v); } }
  function request(method, url) {
    calls.push([method, url]);
    return { status: calls.length === failAt ? 0 : 200, timings: { duration: 10 }, json: key => key === 'sections' || key === 'seats' ? [{ id: 1 }] : 'token' };
  }
  const ctx = vm.createContext({ __ENV: { BASE_URL: 'http://test', USERS: '1', TOKEN_PATH: 'tokens.json' }, __VU: 1, open: () => '["token"]', SharedArray: class { constructor(name, load) { return load(); } }, http: { get: u => request('get',u), post: u => request('post',u), del: u => request('del',u) }, sleep: n => sleeps.push(n), Rate: Metric, Trend: Metric, Counter: Metric });
  vm.runInContext(source + '\nflow();', ctx);
  if (!failAt) assert.deepEqual(sleeps, []);
  assert.equal(metrics.flow_success[0], !failAt || failAt === 1);
  assert.equal(metrics.flow_ms.length, 1);
  return calls;
}
assert.equal(execute().length, 7);
assert.equal(execute(1).length, 8); // transient queue-join failure retries and recovers
assert.equal(execute(3).at(-1)[0], 'del');
assert.equal(execute(5).at(-1)[0], 'del');
assert.equal(execute(6).length, 7);
assert.equal(execute(7).length, 7);
const summaryContext = vm.createContext({
  __ENV: { BASE_URL: 'http://test', USERS: '1', TOKEN_PATH: 'tokens.json', SUMMARY_PATH: 'C:/results/test run/summary.json' },
  open: () => '["token"]', SharedArray: class { constructor(name, load) { return load(); } }, Rate: class {}, Trend: class {}, Counter: class {},
});
const summary = vm.runInContext(source + '\nhandleSummary({metrics: {}, setup_data: ["token"]});', summaryContext);
assert.equal(summary['C:/results/test run/summary.json'], '{\n  "metrics": {}\n}');
console.log('PASS: successful flow, early failure pacing, hold-timeout cleanup, release failure');
console.log('PASS: local summary output path, including spaces');
