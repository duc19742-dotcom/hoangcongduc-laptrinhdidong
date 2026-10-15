import { createServer } from 'node:http';
import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function normalizePhone(value) {
  let phone = String(value ?? '').replace(/[\s().-]/g, '');
  if (phone.startsWith('0')) phone = '+84' + phone.slice(1);
  if (!/^\+84[35789]\d{8}$/.test(phone)) throw new ApiError(400, 'Số điện thoại Việt Nam không hợp lệ.');
  return phone;
}
const token = () => randomBytes(32).toString('hex');
const publicUser = u => ({ username: u.username, name: u.name, phone: u.phone });

export function twilioProvider(env) {
  async function request(path, params) {
    if (!/^AC[\da-f]{32}$/i.test(env.TWILIO_ACCOUNT_SID ?? '') ||
        !/^VA[\da-f]{32}$/i.test(env.TWILIO_VERIFY_SERVICE_SID ?? '') ||
        !env.TWILIO_AUTH_TOKEN || env.TWILIO_AUTH_TOKEN === 'REPLACE_ME') {
      throw new ApiError(503, 'Backend chưa cấu hình Twilio. Xem HUONG_DAN_OTP.md.');
    }
    let response;
    try {
      response = await fetch(`https://verify.twilio.com/v2/Services/${env.TWILIO_VERIFY_SERVICE_SID}/${path}`, {
        method: 'POST', signal: AbortSignal.timeout(15000),
        headers: { Authorization: 'Basic ' + Buffer.from(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`).toString('base64'), 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(params),
      });
    } catch { throw new ApiError(502, 'Không kết nối được Twilio. Vui lòng thử lại.'); }
    const data = await response.json();
    if (!response.ok) {
      if (data.code === 20404) throw new ApiError(400, 'OTP đã hết hạn hoặc đã sử dụng. Hãy đăng nhập lại.');
      if (response.status === 429 || data.code === 60203) throw new ApiError(429, 'Đã vượt hạn mức OTP. Vui lòng thử lại sau.');
      if (data.code === 21608) throw new ApiError(400, 'Số nhận chưa được xác minh trong Twilio Trial.');
      throw new ApiError(502, 'Twilio từ chối yêu cầu. Kiểm tra cấu hình, số nhận và hạn mức trong Twilio Console.');
    }
    return data;
  }
  return {
    send: async phone => {
      const data = await request('Verifications', { To: phone, Channel: 'sms' });
      if (data.status !== 'pending') throw new ApiError(502, 'Chưa gửi được OTP.');
    },
    check: async (phone, code) => (await request('VerificationCheck', { To: phone, Code: code })).status === 'approved',
  };
}

export function createApp({ dbPath = ':memory:', provider, allowedPhones = [], now = Date.now } = {}) {
  const db = new DatabaseSync(dbPath);
  db.exec('CREATE TABLE IF NOT EXISTS users (username TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT UNIQUE NOT NULL, salt TEXT NOT NULL, hash TEXT NOT NULL, verified INTEGER NOT NULL DEFAULT 0)');
  const challenges = new Map(), sessions = new Map(), limits = new Map(), phoneSend = new Map();
  const prune = () => {
    for (const map of [challenges, sessions, limits]) for (const [key, value] of map) if (value.expires <= now()) map.delete(key);
    for (const [key, time] of phoneSend) if (time + 60000 <= now()) phoneSend.delete(key);
  };
  function limit(key, max, duration) {
    let entry = limits.get(key);
    if (!entry || entry.expires <= now()) { entry = { count: 0, expires: now() + duration }; limits.set(key, entry); }
    if (++entry.count > max) throw new ApiError(429, 'Thao tác quá nhiều lần. Vui lòng thử lại sau.');
  }
  async function send(phone) {
    if (!allowedPhones.includes(phone)) throw new ApiError(403, 'Số điện thoại chưa nằm trong danh sách demo của backend.');
    if ((phoneSend.get(phone) ?? 0) + 60000 > now()) throw new ApiError(429, 'Vui lòng chờ 60 giây trước khi gửi lại OTP.');
    limit('sms:' + phone, 5, 3600000);
    phoneSend.set(phone, now());
    await provider.send(phone);
  }
  function createChallenge(user, purpose) {
    for (const [id, c] of challenges) if (c.username === user.username) challenges.delete(id);
    const id = token();
    challenges.set(id, { username: user.username, phone: user.phone, purpose, attempts: 0, busy: false, expires: now() + 300000 });
    return { challengeId: id, maskedPhone: user.phone.slice(0, 3) + '******' + user.phone.slice(-3), expiresIn: 300, resendAfter: 60 };
  }
  async function body(req) {
    let raw = '';
    for await (const chunk of req) { raw += chunk; if (raw.length > 8192) throw new ApiError(413, 'Dữ liệu quá lớn.'); }
    try { return JSON.parse(raw || '{}'); } catch { throw new ApiError(400, 'Dữ liệu không hợp lệ.'); }
  }
  const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    const reply = (status, data) => { res.writeHead(status); res.end(JSON.stringify(data)); };
    try {
      prune();
      const path = new URL(req.url, 'http://localhost').pathname;
      const ip = req.socket.remoteAddress;
      if (req.method === 'GET' && path === '/health') return reply(200, { ok: true });
      if (path === '/auth/me' || path === '/auth/logout') {
        const id = req.headers.authorization?.replace(/^Bearer /, '');
        const session = sessions.get(id);
        if (!session) throw new ApiError(401, 'Phiên đăng nhập đã hết hạn.');
        if (path === '/auth/me' && req.method === 'GET') return reply(200, { user: publicUser(db.prepare('SELECT * FROM users WHERE username = ?').get(session.username)) });
        if (path === '/auth/logout' && req.method === 'POST') { sessions.delete(id); return reply(200, { ok: true }); }
        throw new ApiError(405, 'Phương thức không hợp lệ.');
      }
      if (req.method !== 'POST') throw new ApiError(404, 'Không tìm thấy API.');
      limit('ip:' + ip, 60, 600000);
      const b = await body(req);
      if (path === '/auth/register' || path === '/auth/login') {
        const username = String(b.username ?? '').trim().toLowerCase();
        const password = b.password;
        if (!/^[a-z0-9_]{3,30}$/.test(username) || typeof password !== 'string' || password.length < 8 || password.length > 128) throw new ApiError(400, 'Tài khoản gồm 3–30 chữ, số hoặc dấu _. Mật khẩu gồm 8–128 ký tự.');
        limit('login:' + username, 10, 600000);
        let user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
        if (path === '/auth/register') {
          const name = String(b.name ?? '').trim();
          const phone = normalizePhone(b.phone);
          if (!name || name.length > 80) throw new ApiError(400, 'Họ tên gồm 1–80 ký tự.');
          if (!allowedPhones.includes(phone)) throw new ApiError(403, 'Số điện thoại chưa nằm trong danh sách demo của backend.');
          if (user || db.prepare('SELECT username FROM users WHERE phone = ?').get(phone)) throw new ApiError(409, 'Tài khoản hoặc số điện thoại đã được đăng ký. Hãy đăng nhập để tiếp tục xác minh.');
          const salt = randomBytes(16).toString('hex');
          const hash = scryptSync(password, salt, 64).toString('hex');
          db.prepare('INSERT INTO users (username,name,phone,salt,hash) VALUES (?,?,?,?,?)').run(username, name, phone, salt, hash);
          user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
        } else {
          const hash = scryptSync(password, user?.salt ?? 'invalid-user-salt', 64);
          if (!user || !timingSafeEqual(hash, Buffer.from(user.hash, 'hex'))) throw new ApiError(401, 'Tài khoản hoặc mật khẩu không đúng.');
        }
        try { await send(user.phone); } catch (e) {
          if (path === '/auth/register') e.message += ' Tài khoản đã được lưu; hãy dùng Đăng nhập để thử lại.';
          throw e;
        }
        return reply(200, createChallenge(user, user.verified ? 'login' : 'register'));
      }
      if (path === '/auth/verify' || path === '/auth/resend') {
        const c = challenges.get(b.challengeId);
        if (!c) throw new ApiError(401, 'Yêu cầu OTP đã hết hạn. Hãy đăng nhập lại.');
        if (c.busy) throw new ApiError(409, 'Đang xử lý OTP. Vui lòng chờ.');
        c.busy = true;
        try {
          if (path === '/auth/resend') {
            await send(c.phone);
            return reply(200, { resendAfter: 60 });
          }
          if (!/^\d{6}$/.test(String(b.code ?? ''))) throw new ApiError(400, 'OTP gồm 6 chữ số.');
          c.attempts++;
          if (c.attempts > 5) { challenges.delete(b.challengeId); throw new ApiError(401, 'Nhập sai quá nhiều lần. Hãy đăng nhập lại.'); }
          const approved = await provider.check(c.phone, b.code);
          if (!approved) {
            if (c.attempts >= 5) { challenges.delete(b.challengeId); throw new ApiError(401, 'Nhập sai quá nhiều lần. Hãy đăng nhập lại.'); }
            throw new ApiError(400, 'Mã OTP không đúng.');
          }
          if (challenges.get(b.challengeId) !== c || c.expires <= now()) throw new ApiError(401, 'Yêu cầu OTP đã hết hạn. Hãy đăng nhập lại.');
          challenges.delete(b.challengeId);
          db.prepare('UPDATE users SET verified = 1 WHERE username = ?').run(c.username);
          const id = token(); sessions.set(id, { username: c.username, expires: now() + 28800000 });
          return reply(200, { token: id, user: publicUser(db.prepare('SELECT * FROM users WHERE username = ?').get(c.username)) });
        } finally { c.busy = false; }
      }
      throw new ApiError(404, 'Không tìm thấy API.');
    } catch (e) { reply(e.status ?? 500, { message: e.status ? e.message : 'Lỗi backend. Vui lòng thử lại.' }); }
  });
  server.on('close', () => db.close());
  return server;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  mkdirSync(new URL('./data/', import.meta.url), { recursive: true });
  const allowedPhones = (process.env.DEMO_ALLOWED_PHONES ?? '').split(',').filter(Boolean).map(normalizePhone);
  const server = createApp({ dbPath: fileURLToPath(new URL('./data/users.sqlite', import.meta.url)), provider: twilioProvider(process.env), allowedPhones });
  server.listen(Number(process.env.PORT ?? 3000), process.env.HOST ?? '0.0.0.0', () => console.log('OTP backend listening on port ' + (process.env.PORT ?? 3000)));
}
