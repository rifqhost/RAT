import http from 'node:http';
import { WebSocket, WebSocketServer, RawData } from 'ws';
import { Store } from '../store.js';
import { config } from '../config.js';
import {
  generatePairingCode,
  randomToken,
  sha256,
  signSessionToken,
  verifyDeviceToken,
  verifySessionToken,
} from '../crypto.js';
import { validateMessage, permissionListSchema } from '../protocol.js';
import { Envelope, Permission, Session, SessionMessageType } from '../types.js';

interface ClientMeta {
  ws: WebSocket;
  deviceId?: string;
  role?: 'controller' | 'agent';
  sessionId?: string;
  authed: boolean;
}

interface IceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
}

function envelope<T>(type: SessionMessageType, payload: T): Envelope<T> {
  return { id: randomToken(10), type, payload, ts: Date.now() };
}

export class WsHub {
  private readonly clients = new Map<string, ClientMeta>();
  private readonly rooms = new Map<string, Set<string>>();

  constructor(
    private readonly store: Store,
    private readonly iceServers: IceServer[],
  ) {}

  attach(server: http.Server): void {
    const wss = new WebSocketServer({ server, path: '/ws' });
    wss.on('connection', (ws) => this.onConnection(ws));
    wss.on('error', (err) => console.error('[ws] server error:', err));
  }

  // ------------------------------------------------------------------ conn
  private onConnection(ws: WebSocket): void {
    const meta: ClientMeta = { ws, authed: false };
    const clientId = randomToken(10);
    this.clients.set(clientId, meta);
    this.sendTo(meta, envelope('HELLO', { status: 'ok', clientId }));

    ws.on('message', (raw: RawData) => {
      try {
        this.handleMessage(clientId, raw.toString());
      } catch (err) {
        console.error('[ws] message handler error:', err);
        this.sendTo(meta, envelope('ERROR', { code: 'internal_error', message: 'Failed to process message.' }));
      }
    });

    ws.on('close', () => this.onClose(clientId));
    ws.on('error', () => this.onClose(clientId));
  }

  private onClose(clientId: string): void {
    const meta = this.clients.get(clientId);
    if (!meta) return;
    if (meta.deviceId && meta.role) {
      this.store.setDeviceOnline(meta.deviceId, false);
    }
    const sessionId = meta.sessionId;
    if (sessionId) {
      const endedBy = meta.role ?? 'server';
      this.endSession(sessionId, `${endedBy}_disconnect`, endedBy, clientId);
    }
    this.leaveRoom(sessionId, clientId);
    this.clients.delete(clientId);
  }

  // ---------------------------------------------------------------- auth
  private handleMessage(clientId: string, raw: string): void {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      this.sendError(clientId, 'bad_json', 'Message is not valid JSON.');
      return;
    }
    const validation = validateMessage(parsed);
    if (!validation.ok) {
      this.sendError(clientId, 'validation_failed', validation.error);
      return;
    }
    const env = validation.value;
    const meta = this.clients.get(clientId);
    if (!meta) return;

    switch (env.type) {
      case 'PING':
        this.sendTo(meta, envelope('PONG', env.payload));
        break;
      case 'AUTH':
        this.handleAuth(clientId, env.payload as never);
        break;
      case 'SESSION_REJOIN':
        this.handleRejoin(clientId, env.payload as never);
        break;
      default:
        this.routeAuthedMessage(clientId, meta, env as Envelope<never>);
    }
  }

  private handleAuth(clientId: string, p: {
    deviceId: string;
    role: 'controller' | 'agent';
    token: string;
    name?: string;
    model?: string;
    androidVersion?: string;
    appVersion?: string;
    rejoin?: { sessionId: string; sessionToken: string };
  }): void {
    const meta = this.clients.get(clientId);
    if (!meta) return;
    const token = verifyDeviceToken(p.token);
    const device = this.store.getDevice(p.deviceId);
    if (!token || !device || device.id !== token.sub || device.role !== p.role) {
      this.sendTo(meta, envelope('AUTH_ERROR', { code: 'auth_failed', message: 'Invalid credentials or device mismatch.' }));
      this.clients.delete(clientId);
      meta.ws.close(4001, 'auth_failed');
      return;
    }
    meta.authed = true;
    meta.deviceId = device.id;
    meta.role = device.role;
    this.store.setDeviceOnline(device.id, true, clientId);
    if (p.name || p.model || p.androidVersion || p.appVersion) {
      this.store.updateDevice(device.id, {
        name: p.name ?? device.name,
        model: p.model ?? device.model,
        androidVersion: p.androidVersion ?? device.androidVersion,
        appVersion: p.appVersion ?? device.appVersion,
      });
    }
    this.store.audit('DEVICE_ONLINE', device.id, `${device.role} ${device.id}`);

    let activeSessionId: string | undefined;
    if (p.rejoin) {
      const joined = this.tryRejoin(clientId, p.rejoin.sessionId, p.rejoin.sessionToken);
      activeSessionId = joined ? p.rejoin.sessionId : undefined;
    } else {
      const active = this.store
        .listSessions({ status: 'active' })
        .find((s) => s.controllerDeviceId === device.id || s.agentDeviceId === device.id);
      activeSessionId = active?.id;
      if (active) this.joinRoom(active.id, clientId);
    }

    const onlineDevices = device.role === 'controller' ? this.onlineAgentsFor(device.id) : [];
    this.sendTo(meta, envelope('AUTH_OK', { deviceId: device.id, role: device.role, onlineDevices, activeSessionId }));
  }

  private onlineAgentsFor(controllerDeviceId: string): string[] {
    const pairs = this.store.listApprovedPairs(controllerDeviceId);
    const result: string[] = [];
    for (const pair of pairs) {
      const agent = this.store.getDevice(pair.agentDeviceId);
      if (agent?.online) result.push(agent.id);
    }
    return result;
  }

  private tryRejoin(clientId: string, sessionId: string, sessionToken: string): boolean {
    const meta = this.clients.get(clientId);
    const verified = verifySessionToken(sessionToken);
    if (!verified || verified.sessionId !== sessionId) return false;
    const deviceId = meta?.deviceId;
    const session = this.store.getSession(sessionId);
    if (!deviceId || !session || session.status !== 'active') return false;
    if (session.controllerDeviceId !== deviceId && session.agentDeviceId !== deviceId) return false;
    this.joinRoom(sessionId, clientId);
    meta!.sessionId = sessionId;
    return true;
  }

  private handleRejoin(clientId: string, p: { sessionId: string; sessionToken: string }): void {
    const meta = this.clients.get(clientId);
    if (!meta) return;
    if (this.tryRejoin(clientId, p.sessionId, p.sessionToken)) {
      this.sendTo(meta, envelope('AUTH_OK', {
        deviceId: meta.deviceId ?? '',
        role: meta.role ?? 'agent',
        onlineDevices: [],
        activeSessionId: p.sessionId,
      }));
    } else {
      this.sendError(clientId, 'rejoin_failed', 'Session is no longer valid.');
    }
  }

  // --------------------------------------------------------------- routing
  private routeAuthedMessage(clientId: string, meta: ClientMeta, env: Envelope): void {
    if (!meta.authed || !meta.deviceId || !meta.role) {
      this.sendError(clientId, 'not_authenticated', 'Authenticate before sending messages.');
      return;
    }
    const p = env.payload as { sessionId?: string };

    switch (env.type) {
      case 'PAIR_REQUEST':
        this.handlePairRequest(clientId, meta, env.payload as never);
        return;
      case 'PAIR_APPROVED':
        this.handlePairDecision(clientId, meta, env.payload as never, true);
        return;
      case 'PAIR_DENIED':
        this.handlePairDecision(clientId, meta, env.payload as never, false);
        return;
      case 'SESSION_ACCEPT':
        this.handleSessionAccept(clientId, meta, env.payload as never);
        return;
      case 'SESSION_DENY':
        this.handleSessionDeny(clientId, meta, env.payload as never);
        return;
      case 'DISCONNECT': {
        const payload = env.payload as { sessionId: string; reason?: string };
        const session = this.sessionForDevice(meta, payload.sessionId);
        if (!session) return this.sendError(clientId, 'no_session', 'No such session.');
        const reason = session.agentDeviceId === meta.deviceId ? 'agent_stop' : 'controller_stop';
        const endedBy = session.agentDeviceId === meta.deviceId ? 'agent' : 'controller';
        this.endSession(session.id, reason, endedBy);
        return;
      }
      case 'PERMISSION_UPDATE': {
        const payload = env.payload as { sessionId: string; permission: Permission; granted: boolean };
        const session = this.sessionFor(meta, payload.sessionId);
        if (!session) return this.sendError(clientId, 'no_session', 'No such session.');
        const current = new Set(session.permissions);
        if (payload.granted) current.add(payload.permission);
        else current.delete(payload.permission);
        this.store.updateSession(session.id, { permissions: Array.from(current) });
        this.store.audit('PERMISSION_CHANGED', meta.deviceId, `${payload.permission}:${payload.granted}`);
        this.relay(clientId, session.id, env);
        return;
      }
      case 'SESSION_ENDED':
      case 'AUTH_OK':
      case 'AUTH_ERROR':
      case 'ERROR':
      case 'HELLO':
      case 'PAIR_RESPONSE':
      case 'PAIR_APPROVAL':
      case 'SESSION_REQUEST':
      case 'SESSION_ACCEPTED':
      case 'PING':
      case 'PONG':
        return this.sendError(clientId, 'invalid_message', `Clients cannot send ${env.type}.`);
      default:
        break;
    }

    if (!p?.sessionId || !meta.sessionId || p.sessionId !== meta.sessionId) {
      return this.sendError(clientId, 'no_session', 'Message is not part of an active session.');
    }
    const session = this.store.getSession(meta.sessionId);
    if (!session || session.status !== 'active') {
      return this.sendError(clientId, 'session_not_active', 'Session is not active.');
    }
    this.guardPermitted(clientId, meta, session, env);
    this.relay(clientId, meta.sessionId, env);
    this.store.updateSession(meta.sessionId, {});
  }

  private guardPermitted(clientId: string, meta: ClientMeta, session: Session, env: Envelope): void {
    const t = env.type;
    const has = (perm: Permission) => session.permissions.includes(perm);
    const forbid = () => this.sendError(clientId, 'permission_denied', 'The agent has not granted this permission.');

    switch (t) {
      case 'TOUCH_EVENT':
        if (meta.role !== 'controller' || !has('TOUCH')) return forbid();
        return;
      case 'CONTROL_EVENT': {
        if (meta.role !== 'controller') return forbid();
        const kind = (env.payload as { kind: string }).kind;
        if (kind.startsWith('NAV_') || kind === 'TEXT_INPUT') {
          if (!has('TOUCH')) return forbid();
        } else if (kind === 'CAMERA_ON' || kind === 'CAMERA_OFF') {
          if (!has('CAMERA')) return forbid();
        } else if (kind === 'MIC_ON' || kind === 'MIC_OFF') {
          if (!has('MICROPHONE')) return forbid();
        }
        return;
      }
      case 'FILE_REQUEST':
        if (meta.role !== 'controller' || !has('FILES')) return forbid();
        return;
      case 'CLIPBOARD_EVENT': {
        if (!has('CLIPBOARD')) return forbid();
        const direction = (env.payload as { direction: string }).direction;
        if (direction === 'controller_to_agent' && meta.role !== 'controller') return forbid();
        if (direction === 'agent_to_controller' && meta.role !== 'agent') return forbid();
        return;
      }
      case 'OFFER':
      case 'ANSWER':
      case 'ICE_CANDIDATE':
      case 'FILE_ACCEPT':
      case 'FILE_DECLINE':
      case 'FILE_PROGRESS':
      case 'FILE_COMPLETE':
        return;
      default:
        return forbid();
    }
  }

  private handlePairRequest(clientId: string, meta: ClientMeta, p: { deviceId: string }): void {
    if (meta.role !== 'agent' || p.deviceId !== meta.deviceId) {
      return this.sendError(clientId, 'forbidden', 'Only an agent device can request a pairing code for itself.');
    }
    const agent = this.store.getDevice(meta.deviceId);
    if (!agent) return this.sendError(clientId, 'no_device', 'Device not found.');
    const code = generatePairingCode();
    const expiresAt = Date.now() + config.pairingCodeTtl * 1000;
    const existing = this.store.getLivePairingCode(agent.id);
    if (existing) this.store.usePairingCode(existing.id);
    this.store.createPairingCode({
      id: randomToken(12),
      deviceId: agent.id,
      codeHash: sha256(code),
      createdAt: new Date().toISOString(),
      expiresAt: new Date(expiresAt).toISOString(),
      used: false,
    });
    this.store.audit('PAIR_REQUEST', agent.id);
    this.sendTo(this.clients.get(clientId)!, envelope('PAIR_RESPONSE', {
      deviceId: agent.id,
      code,
      expiresAt,
      expiresIn: config.pairingCodeTtl,
    }));
  }

  private handlePairDecision(clientId: string, meta: ClientMeta, p: { pairId: string }, approve: boolean): void {
    const pair = this.store.getPair(p.pairId);
    if (!pair || pair.agentDeviceId !== meta.deviceId) {
      return this.sendError(clientId, 'no_pair', 'Pairing record not found.');
    }
    if (pair.status !== 'pending') {
      return this.sendError(clientId, 'pair_closed', 'Pairing has already been resolved.');
    }
    if (approve) {
      this.store.updatePair(pair.id, { status: 'approved', approvedAt: new Date().toISOString() });
      this.store.audit('PAIR_ACCEPTED', meta.deviceId, `controller ${pair.controllerDeviceId}`);
      const controller = this.store.getDevice(pair.controllerDeviceId);
      if (controller?.online && controller.wsClientId) {
        this.sendTo(this.clients.get(controller.wsClientId)!, envelope('PAIR_APPROVED', { pairId: pair.id }));
      }
    } else {
      this.store.updatePair(pair.id, { status: 'revoked', revokedAt: new Date().toISOString() });
      this.store.audit('PAIR_DENIED', meta.deviceId, `controller ${pair.controllerDeviceId}`);
      const controller = this.store.getDevice(pair.controllerDeviceId);
      if (controller?.online && controller.wsClientId) {
        this.sendTo(this.clients.get(controller.wsClientId)!, envelope('PAIR_DENIED', { pairId: pair.id }));
      }
    }
  }

  private handleSessionAccept(clientId: string, meta: ClientMeta, p: { sessionId: string; permissions: Permission[] }): void {
    if (meta.role !== 'agent') return this.sendError(clientId, 'forbidden', 'Only the agent can accept a session.');
    const session = this.store.getSession(p.sessionId);
    if (!session || session.agentDeviceId !== meta.deviceId) {
      return this.sendError(clientId, 'no_session', 'Session not found.');
    }
    if (session.status !== 'requested') return this.sendError(clientId, 'session_closed', 'Session is already resolved.');
    const granted = permissionListSchema.parse(p.permissions);
    if (!granted.every((perm) => session.permissions.includes(perm))) {
      return this.sendError(clientId, 'permission_scope', 'Granted permissions must be a subset of requested permissions.');
    }
    const now = new Date().toISOString();
    this.store.updateSession(session.id, { status: 'active', permissions: granted, startedAt: now, agentWsId: clientId });
    const sessionToken = signSessionToken(session.id);
    this.joinRoom(session.id, clientId);
    meta.sessionId = session.id;
    this.store.audit('SESSION_STARTED', meta.deviceId, p.sessionId);
    const controller = this.store.getDevice(session.controllerDeviceId);
    const controllerClient = controller?.online ? this.clients.get(controller.wsClientId ?? '') : undefined;
    if (controllerClient && controller?.wsClientId) {
      this.joinRoom(session.id, controller.wsClientId);
      const cm = this.clients.get(controller.wsClientId);
      if (cm) cm.sessionId = session.id;
      this.sendTo(controllerClient, envelope('SESSION_ACCEPTED', {
        sessionId: session.id,
        permissions: granted,
        sessionToken,
        iceServers: this.iceServers,
      }));
    } else {
      this.store.audit('SESSION_CONTROLLER_OFFLINE', session.id);
      this.endSession(session.id, 'controller_disconnect', 'server');
    }
  }

  private handleSessionDeny(clientId: string, meta: ClientMeta, p: { sessionId: string; reason?: string }): void {
    if (meta.role !== 'agent') return this.sendError(clientId, 'forbidden', 'Only the agent can deny a session.');
    const session = this.store.getSession(p.sessionId);
    if (!session || session.agentDeviceId !== meta.deviceId) return this.sendError(clientId, 'no_session', 'Session not found.');
    this.store.audit('SESSION_DENIED', meta.deviceId, `${p.sessionId} ${p.reason ?? ''}`);
    this.store.updateSession(session.id, { status: 'ended', endedAt: new Date().toISOString(), endedReason: 'agent_stop' });
    const controller = this.store.getDevice(session.controllerDeviceId);
    if (controller?.online && controller.wsClientId) {
      this.sendTo(this.clients.get(controller.wsClientId)!, envelope('SESSION_DENY', { sessionId: session.id, reason: p.reason }));
    }
    this.leaveRoom(session.id);
  }

  // ---------------------------------------------------------------- rooms
  private sessionFor(meta: ClientMeta, sessionId: string): Session | null {
    const session = this.store.getSession(sessionId);
    if (!session) return null;
    if (session.controllerDeviceId === meta.deviceId || session.agentDeviceId === meta.deviceId) return session;
    return null;
  }

  private sessionForDevice(meta: ClientMeta, sessionId: string): Session | null {
    return this.sessionFor(meta, sessionId);
  }

  private joinRoom(sessionId: string, clientId: string): void {
    let room = this.rooms.get(sessionId);
    if (!room) {
      room = new Set();
      this.rooms.set(sessionId, room);
    }
    room.add(clientId);
    const meta = this.clients.get(clientId);
    if (meta) meta.sessionId = sessionId;
  }

  private leaveRoom(sessionId: string | undefined, except?: string): void {
    if (!sessionId) return;
    const room = this.rooms.get(sessionId);
    if (!room) return;
    for (const clientId of room) {
      if (clientId === except) continue;
      const meta = this.clients.get(clientId);
      if (meta) meta.sessionId = undefined;
    }
    this.rooms.delete(sessionId);
  }

  private relay(fromClientId: string, sessionId: string, env: Envelope): void {
    const room = this.rooms.get(sessionId);
    if (!room) return;
    for (const clientId of room) {
      if (clientId === fromClientId) continue;
      const meta = this.clients.get(clientId);
      if (meta) this.sendTo(meta, env);
    }
  }

  // ---------------------------------------------------- external (REST)
  pushToDevice(deviceId: string, env: Envelope): boolean {
    const device = this.store.getDevice(deviceId);
    if (!device?.online || !device.wsClientId) return false;
    const meta = this.clients.get(device.wsClientId);
    if (!meta) return false;
    this.sendTo(meta, env);
    return true;
  }

  requestPairApproval(pairId: string, agentDeviceId: string, controllerDeviceId: string, controllerName: string): boolean {
    return this.pushToDevice(agentDeviceId, envelope('PAIR_APPROVAL', {
      pairId,
      controllerDeviceId,
      controllerName,
      requestedAt: Date.now(),
    }));
  }

  requestSession(agentDeviceId: string, sessionId: string, controllerDeviceId: string, controllerName: string, permissions: Permission[]): boolean {
    return this.pushToDevice(agentDeviceId, envelope('SESSION_REQUEST', {
      sessionId,
      controllerDeviceId,
      controllerName,
      permissions,
      iceServers: this.iceServers,
      requestedAt: Date.now(),
    }));
  }

  // Auto-accept session for QR-paired devices with autoApprove=true
  // Called from REST endpoint when pair has autoApprove flag
  autoAcceptSession(
    sessionId: string,
    controllerDeviceId: string,
    agentDeviceId: string,
    permissions: Permission[],
    sessionToken: string,
  ): void {
    // Join controller to session room
    const controller = this.store.getDevice(controllerDeviceId);
    if (controller?.online && controller.wsClientId) {
      const controllerMeta = this.clients.get(controller.wsClientId);
      if (controllerMeta) {
        controllerMeta.sessionId = sessionId;
        this.joinRoom(sessionId, controller.wsClientId);
        this.sendTo(controllerMeta, envelope('SESSION_ACCEPTED', {
          sessionId,
          permissions,
          sessionToken,
          iceServers: this.iceServers,
        }));
      }
    }
    
    // Join agent to session room
    const agent = this.store.getDevice(agentDeviceId);
    if (agent?.online && agent.wsClientId) {
      const agentMeta = this.clients.get(agent.wsClientId);
      if (agentMeta) {
        agentMeta.sessionId = sessionId;
        this.joinRoom(sessionId, agent.wsClientId);
        this.sendTo(agentMeta, envelope('SESSION_ACCEPTED', {
          sessionId,
          permissions,
          sessionToken,
          iceServers: this.iceServers,
        }));
      }
    }
  }

  endSession(sessionId: string, reason: string, endedBy: 'controller' | 'agent' | 'server', exceptClientId?: string): void {
    const session = this.store.getSession(sessionId);
    if (!session) return;
    if (session.status !== 'ended') {
      this.store.updateSession(session.id, { status: 'ended', endedAt: new Date().toISOString(), endedReason: reason as never });
    }
    this.store.audit('SESSION_STOPPED', endedBy, `${sessionId} ${reason}`);
    const room = this.rooms.get(sessionId);
    if (room) {
      for (const clientId of room) {
        if (clientId === exceptClientId) continue;
        const meta = this.clients.get(clientId);
        if (meta) {
          this.sendTo(meta, envelope('SESSION_ENDED', { sessionId, reason, endedBy }));
          meta.sessionId = undefined;
        }
      }
    }
    this.rooms.delete(sessionId);
  }

  // ----------------------------------------------------------------- send
  private sendTo(meta: ClientMeta | undefined, env: Envelope): void {
    if (!meta || meta.ws.readyState !== WebSocket.OPEN) return;
    meta.ws.send(JSON.stringify(env));
  }

  private sendError(clientId: string, code: string, message?: string, payloadSessionId?: string): void {
    const meta = this.clients.get(clientId);
    if (!meta) return;
    this.sendTo(meta, envelope('ERROR', {
      code,
      message: message ?? code,
      refId: payloadSessionId,
    }));
  }
}