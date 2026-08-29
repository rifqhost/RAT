import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createApp } from '../src/index.js';

let server: http.Server;
let base: string;

before(async () => {
  const { app } = createApp();
  server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (typeof address === 'object' && address !== null) {
    base = `http://127.0.0.1:${address.port}`;
  } else {
    throw new Error('failed to bind server');
  }
});

after(() => {
  server.close();
});

async function post(path: string, body: unknown, token?: string): Promise<{ status: number; json: unknown }> {
  const res = await fetch(base + path, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json() };
}

async function get(path: string, token?: string): Promise<{ status: number; json: unknown }> {
  const res = await fetch(base + path, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  return { status: res.status, json: await res.json() };
}

test('health reports ok', async () => {
  const res = await get('/health');
  assert.equal(res.status, 200);
  const body = res.json as { status: string };
  assert.equal(body.status, 'ok');
});

test('auth register + login', async () => {
  const email = `test-${Date.now()}@example.com`;
  const reg = await post('/api/auth/register', { name: 'Tester', email, password: 'password123' });
  assert.equal(reg.status, 201);
  const regBody = reg.json as { token: string; user: { id: string } };
  assert.ok(regBody.token);
  assert.ok(regBody.user.id);

  const login = await post('/api/auth/login', { email, password: 'password123' });
  assert.equal(login.status, 200);
  const loginBody = login.json as { token: string };
  assert.ok(loginBody.token);

  const bad = await post('/api/auth/login', { email, password: 'wrongpassword' });
  assert.equal(bad.status, 401);
});

test('device registration requires auth', async () => {
  const res = await post('/api/devices/register', { role: 'agent', name: 'HP B' });
  assert.equal(res.status, 401);
});

test('register controller + agent devices', async () => {
  const email = `dev-${Date.now()}@example.com`;
  const reg = await post('/api/auth/register', { name: 'Owner', email, password: 'password123' });
  const token = (reg.json as { token: string }).token;

  const c = await post('/api/devices/register', { role: 'controller', name: 'Controller' }, token);
  assert.equal(c.status, 201);
  const controller = c.json as { device: { id: string }; deviceToken: string };
  assert.match(controller.device.id, /^RMDZ-[A-Z0-9]{6}$/);
  assert.ok(controller.deviceToken);

  const a = await post('/api/devices/register', { role: 'agent', name: 'HP B', model: 'Pixel', androidVersion: '14' }, token);
  assert.equal(a.status, 201);
  const agent = a.json as { device: { id: string }; deviceToken: string };
  assert.ok(agent.deviceToken);
});

test('agent self-registration works without a user account', async () => {
  const res = await post('/api/devices/agent/register', { name: 'RMODZ Agent', model: 'Pixel 8', androidVersion: '15' });
  assert.equal(res.status, 201);
  const body = res.json as { device: { id: string; role: string }; deviceToken: string };
  assert.equal(body.device.role, 'agent');
  assert.match(body.device.id, /^RMDZ-[A-Z0-9]{6}$/);
  assert.ok(body.deviceToken);

  const dup = await post('/api/devices/agent/register', { deviceId: body.device.id });
  assert.equal(dup.status, 409);
});
