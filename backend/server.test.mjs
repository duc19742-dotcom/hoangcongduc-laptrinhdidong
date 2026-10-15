import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp, normalizePhone, twilioProvider } from './server.mjs';

test('Vietnamese phone normalization rejects invalid numbers', () => {
  assert.equal(normalizePhone('0912 345 678'), '+84912345678');
  assert.equal(normalizePhone('+84912345678'), '+84912345678');
  assert.throws(() => normalizePhone('123'));
});

test('Twilio requires actual credentials; no fake SMS fallback', async () => {
  await assert.rejects(twilioProvider({}).send('+84912345678'), /chưa cấu hình/);
});

test('registration and login require OTP, reject wrong credentials, replay, and unlisted recipients', async t => {
  let clock = Date.now(), sends = 0;
  const phone = '+84912345678';
  const server = createApp({
    allowedPhones: [phone], now: () => clock,
    provider: { send: async p => { assert.equal(p, phone); sends++; }, check: async (p, code) => p === phone && code === '654321' },
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}`;
  async function post(path, body, token) {
    const r = await fetch(url + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: JSON.stringify(body) });
    return { status: r.status, data: await r.json() };
  }
  const account = { name: 'Người demo', username: 'demo_user', password: 'DemoPass123!', phone: '0912345678' };
  assert.equal((await post('/auth/register', { ...account, phone: '0987654321' })).status, 403);
  const registered = await post('/auth/register', account);
  assert.equal(registered.status, 200);
  assert.equal(sends, 1);
  assert.equal(registered.data.token, undefined);
  assert.equal((await fetch(url + '/auth/me')).status, 401);
  assert.equal((await post('/auth/resend', { challengeId: registered.data.challengeId })).status, 429);
  assert.equal((await post('/auth/verify', { challengeId: registered.data.challengeId, code: '000000' })).status, 400);
  const verified = await post('/auth/verify', { challengeId: registered.data.challengeId, code: '654321' });
  assert.equal(verified.status, 200);
  assert.ok(verified.data.token);
  assert.equal((await post('/auth/verify', { challengeId: registered.data.challengeId, code: '654321' })).status, 401);
  assert.equal((await fetch(url + '/auth/me', { headers: { Authorization: 'Bearer ' + verified.data.token } })).status, 200);
  assert.equal((await post('/auth/logout', {}, verified.data.token)).status, 200);
  assert.equal((await fetch(url + '/auth/me', { headers: { Authorization: 'Bearer ' + verified.data.token } })).status, 401);
  clock += 61000;
  assert.equal((await post('/auth/login', { ...account, password: 'WrongPass123' })).status, 401);
  const login = await post('/auth/login', account);
  assert.equal(login.status, 200);
  assert.equal(login.data.token, undefined);
  assert.equal(sends, 2);
  for (let i = 0; i < 5; i++) await post('/auth/verify', { challengeId: login.data.challengeId, code: '000000' });
  assert.equal((await post('/auth/verify', { challengeId: login.data.challengeId, code: '654321' })).status, 401);
  clock += 61000;
  const expired = await post('/auth/login', account);
  clock += 301000;
  assert.equal((await post('/auth/verify', { challengeId: expired.data.challengeId, code: '654321' })).status, 401);
});

test('failed SMS keeps account recoverable and never grants access', async t => {
  let fail = true, clock = Date.now();
  const server = createApp({ allowedPhones: ['+84912345678'], now: () => clock,
    provider: { send: async () => { if (fail) throw new Error('offline'); }, check: async () => true } });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}`;
  const account = { name: 'Demo', username: 'demo', password: 'Password123', phone: '0912345678' };
  const post = async path => fetch(url + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(account) });
  assert.equal((await post('/auth/register')).status, 500);
  assert.equal((await fetch(url + '/auth/me')).status, 401);
  fail = false; clock += 61000;
  assert.equal((await post('/auth/login')).status, 200);
});
