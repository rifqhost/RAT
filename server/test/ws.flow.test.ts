import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { WebSocket } from 'ws';
import { createApp } from '../src/index.js';

let server: http.Server;
let base: string;
let wsBase: string;
const permissions = ['SCREEN', 'TOUCH', 'CAMERA', 'MICROPHONE', 'FILES', 'CLIPBOARD', 'DEVICE_INFO'];

before(async () => {
  const { app, hub } = createApp();
  server = http.createServer(app);
  hub.attach(server);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (typeof address === 'object' && address !== null) {
    base = `http://127.0.0.1:${address.port}`;
    wsBase = `ws://127.0.0.1:${address.port}/ws`;
  } else {
    throw new Error('failed to bind server');
  }
});

after(() => {
  server.close();
});

async function post(path: string, body: unknown, token?: string): Promise<{ status: number; json: any }> {
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

function connect(): Promise<{ ws: WebSocket; next: (pred?: (m: any) => boolean, timeoutMs?: number) => Promise<any> }> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsBase);
    const queue: any[] = [];
    const waiters: Array<{ pred: (m: any) => boolean; resolve: (m: any) => void; reject: (e: Error) => void; timer: NodeJS.Timeout }> = [];
    ws.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());
      const idx = waiters.findIndex((w) => w.pred(msg));
      if (idx >= 0) {
        const w = waiters.splice(idx, 1)[0];
        clearTimeout(w.timer);
        w.resolve(msg);
      } else {
        queue.push(msg);
      }
    });
    ws.on('open', () => {
      resolve({
        ws,
        next: (pred?: (m: any) => boolean, timeoutMs = 5000) =>
          new Promise((res, rej) => {
            const match = pred ?? (() => true);
            const ti = setTimeout(() => {
              const i = waiters.findIndex((w) => w.pred === pred);
              if (i >= 0) waiters.splice(i, 1);
              rej(new Error('timeout waiting for message'));
            }, timeoutMs);
            const qi = queue.findIndex(match);
            if (qi >= 0) {
              clearTimeout(ti);
              res(queue.splice(qi, 1)[0]);
              return;
            }
            waiters.push({ pred: match, resolve: res, reject: rej, timer: ti });
          }),
      });
    });
    ws.on('error', reject);
  });
}

test('full pairing + session signaling flow over WebSocket', async () => {
  let step = '';
  const marker = (label: string) => { step = label; };

  // 1. register account and two devices
  const email = `flow-${Date.now()}@example.com`;
  const reg = await post('/api/auth/register', { name: 'Owner', email, password: 'password123' });
  const token = reg.json.token;

  const c = await post('/api/devices/register', { role: 'controller', name: 'HP A' }, token);
  const controller = c.json;
  const a = await post('/api/devices/register', { role: 'agent', name: 'HP B' }, token);
  const agent = a.json;

  // 2. agent connects and requests a pairing code
  const agentConn = await connect();
  agentConn.ws.send(JSON.stringify({ id: 'm1', type: 'AUTH', ts: Date.now(), payload: { deviceId: agent.device.id, role: 'agent', token: agent.deviceToken, name: 'HP B' } }));
  marker('agent AUTH_OK');
  await agentConn.next((m) => m.type === 'AUTH_OK');

  agentConn.ws.send(JSON.stringify({ id: 'm2', type: 'PAIR_REQUEST', ts: Date.now(), payload: { deviceId: agent.device.id } }));
  marker('PAIR_RESPONSE');
  const pairResponse = await agentConn.next((m) => m.type === 'PAIR_RESPONSE');
  assert.equal(pairResponse.payload.deviceId, agent.device.id);
  const code = pairResponse.payload.code as string;
  assert.match(code, /^\d{6}$/);

  // 3. controller connects, pairs using code, agent approves
  const controllerConn = await connect();
  controllerConn.ws.send(JSON.stringify({ id: 'm3', type: 'AUTH', ts: Date.now(), payload: { deviceId: controller.device.id, role: 'controller', token: controller.deviceToken, name: 'HP A' } }));
  marker('controller AUTH_OK');
  await controllerConn.next((m) => m.type === 'AUTH_OK');

  const pairRes = await post('/api/devices/pair', { deviceId: agent.device.id, code }, controller.deviceToken);
  assert.equal(pairRes.status, 201);
  const pairId = pairRes.json.pairId as string;

  marker('PAIR_APPROVAL');
  const approval = await agentConn.next((m) => m.type === 'PAIR_APPROVAL');
  assert.equal(approval.payload.pairId, pairId);
  agentConn.ws.send(JSON.stringify({ id: 'm4', type: 'PAIR_APPROVED', ts: Date.now(), payload: { pairId } }));
  marker('PAIR_APPROVED');
  await controllerConn.next((m) => m.type === 'PAIR_APPROVED');

  // 4. controller requests remote session, agent accepts with reduced permissions
  const sessRes = await post('/api/sessions', { agentDeviceId: agent.device.id, permissions }, controller.deviceToken);
  assert.equal(sessRes.status, 201);
  const sessionId = sessRes.json.sessionId as string;

  marker('SESSION_REQUEST');
  const sessionRequest = await agentConn.next((m) => m.type === 'SESSION_REQUEST');
  assert.equal(sessionRequest.payload.sessionId, sessionId);
  const granted = ['SCREEN', 'TOUCH', 'CAMERA'];
  agentConn.ws.send(JSON.stringify({ id: 'm5', type: 'SESSION_ACCEPT', ts: Date.now(), payload: { sessionId, permissions: granted } }));

  marker('SESSION_ACCEPTED');
  const accepted = await controllerConn.next((m) => m.type === 'SESSION_ACCEPTED');
  assert.equal(accepted.payload.sessionId, sessionId);
  assert.deepEqual(accepted.payload.permissions, granted);

  // 5. WebRTC signaling relay controller -> agent (offer)
  controllerConn.ws.send(JSON.stringify({ id: 'm6', type: 'OFFER', ts: Date.now(), payload: { sessionId, sdp: 'test-sdp' } }));
  marker('OFFER');
  const offer = await agentConn.next((m) => m.type === 'OFFER');
  assert.equal(offer.payload.sessionId, sessionId);
  assert.equal(offer.payload.sdp, 'test-sdp');

  // 6. controller sends touch event, agent relays it back (P2P would carry it, signaling relays for validation here)
  controllerConn.ws.send(JSON.stringify({
    id: 'm7', type: 'TOUCH_EVENT', ts: Date.now(),
    payload: { sessionId, eventType: 'tap', x: 0.5, y: 0.5, timestamp: Date.now(), screenWidth: 1080, screenHeight: 2400 },
  }));
  marker('TOUCH_EVENT');
  const touch = await agentConn.next((m) => m.type === 'TOUCH_EVENT');
  assert.equal(touch.payload.eventType, 'tap');
  assert.equal(touch.payload.x, 0.5);

  // 7. agent revokes a permission -> controller learns of it
  agentConn.ws.send(JSON.stringify({ id: 'm8', type: 'PERMISSION_UPDATE', ts: Date.now(), payload: { sessionId, permission: 'CAMERA', granted: false } }));
  marker('PERMISSION_UPDATE');
  const permUpdate = await controllerConn.next((m) => m.type === 'PERMISSION_UPDATE');
  assert.equal(permUpdate.payload.permission, 'CAMERA');
  assert.equal(permUpdate.payload.granted, false);

  // 8. controller stops session
  controllerConn.ws.send(JSON.stringify({ id: 'm9', type: 'DISCONNECT', ts: Date.now(), payload: { sessionId, reason: 'done' } }));
  marker('SESSION_ENDED');
  const ended = await agentConn.next((m) => m.type === 'SESSION_ENDED');
  assert.equal(ended.payload.sessionId, sessionId);

  agentConn.ws.close();
  controllerConn.ws.close();
  void step;
});

test('controller cannot request touch events without TOUCH permission', async () => {
  // register a fresh pair quickly
  const email = `flow2-${Date.now()}@example.com`;
  const reg = await post('/api/auth/register', { name: 'Owner', email, password: 'password123' });
  const token = reg.json.token;
  const c = await post('/api/devices/register', { role: 'controller', name: 'HP A' }, token);
  const controller = c.json;
  const a = await post('/api/devices/register', { role: 'agent', name: 'HP B' }, token);
  const agent = a.json;

  const agentConn = await connect();
  agentConn.ws.send(JSON.stringify({ id: 'g1', type: 'AUTH', ts: Date.now(), payload: { deviceId: agent.device.id, role: 'agent', token: agent.deviceToken } }));
  await agentConn.next((m) => m.type === 'AUTH_OK');
  agentConn.ws.send(JSON.stringify({ id: 'g2', type: 'PAIR_REQUEST', ts: Date.now(), payload: { deviceId: agent.device.id } }));
  const pr = await agentConn.next((m) => m.type === 'PAIR_RESPONSE');

  const controllerConn = await connect();
  controllerConn.ws.send(JSON.stringify({ id: 'g3', type: 'AUTH', ts: Date.now(), payload: { deviceId: controller.device.id, role: 'controller', token: controller.deviceToken } }));
  await controllerConn.next((m) => m.type === 'AUTH_OK');

  const pairRes = await post('/api/devices/pair', { deviceId: agent.device.id, code: pr.payload.code }, controller.deviceToken);
  const pairId = pairRes.json.pairId;
  await agentConn.next((m) => m.type === 'PAIR_APPROVAL');
  agentConn.ws.send(JSON.stringify({ id: 'g4', type: 'PAIR_APPROVED', ts: Date.now(), payload: { pairId } }));
  await controllerConn.next((m) => m.type === 'PAIR_APPROVED');

  const sessRes = await post('/api/sessions', { agentDeviceId: agent.device.id, permissions: ['SCREEN'] }, controller.deviceToken);
  const sessionId = sessRes.json.sessionId;
  await agentConn.next((m) => m.type === 'SESSION_REQUEST');
  agentConn.ws.send(JSON.stringify({ id: 'g5', type: 'SESSION_ACCEPT', ts: Date.now(), payload: { sessionId, permissions: ['SCREEN'] } }));
  await controllerConn.next((m) => m.type === 'SESSION_ACCEPTED');

  controllerConn.ws.send(JSON.stringify({
    id: 'g6', type: 'TOUCH_EVENT', ts: Date.now(),
    payload: { sessionId, eventType: 'tap', x: 0.5, y: 0.5, timestamp: Date.now(), screenWidth: 1080, screenHeight: 2400 },
  }));

  // server must NOT relay touch; controller should get an ERROR
  const err = await controllerConn.next((m) => m.type === 'ERROR');
  assert.equal(err.payload.code, 'permission_denied');

  agentConn.ws.close();
  controllerConn.ws.close();
});
