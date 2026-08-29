import fs from 'node:fs';
import path from 'node:path';
import { AuditLog, Device, Pair, PairingCode, Session, User } from './types.js';
import { randomToken } from './crypto.js';

interface StoreData {
  users: User[];
  devices: Device[];
  pairs: Pair[];
  pairingCodes: PairingCode[];
  sessions: Session[];
  auditLogs: AuditLog[];
}

const empty = (): StoreData => ({
  users: [],
  devices: [],
  pairs: [],
  pairingCodes: [],
  sessions: [],
  auditLogs: [],
});

/**
 * A simple file-backed store. Production deployments should swap the persistence
 * layer (e.g. Postgres) but keep the same repository API.
 */
export class Store {
  private data: StoreData = empty();
  private readonly file: string;

  constructor(file: string) {
    this.file = file;
    this.load();
  }

  private load(): void {
    try {
      if (fs.existsSync(this.file)) {
        const raw = fs.readFileSync(this.file, 'utf8');
        this.data = { ...empty(), ...(JSON.parse(raw) as Partial<StoreData>) };
      }
    } catch (err) {
      console.warn('[store] failed to load, starting empty:', err);
      this.data = empty();
    }
  }

  save(): void {
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2), 'utf8');
    fs.renameSync(tmp, this.file);
  }

  // ------------------------------------------------------------------ audit
  audit(event: string, actor: string, details: string = ''): void {
    this.data.auditLogs.push({
      id: randomToken(12),
      ts: new Date().toISOString(),
      event,
      actor,
      details,
    });
    if (this.data.auditLogs.length > 5000) {
      this.data.auditLogs = this.data.auditLogs.slice(-5000);
    }
    this.save();
  }

  // ------------------------------------------------------------------ users
  getUserByEmail(email: string): User | null {
    return this.data.users.find((u) => u.email === email) ?? null;
  }

  getUserById(id: string): User | null {
    return this.data.users.find((u) => u.id === id) ?? null;
  }

  createUser(user: User): User {
    this.data.users.push(user);
    this.save();
    return user;
  }

  // ----------------------------------------------------------------- devices
  getDevice(id: string): Device | null {
    return this.data.devices.find((d) => d.id === id) ?? null;
  }

  getDevicesByUser(userId: string): Device[] {
    return this.data.devices.filter((d) => d.userId === userId);
  }

  createDevice(device: Device): Device {
    this.data.devices.push(device);
    this.save();
    return device;
  }

  updateDevice(id: string, patch: Partial<Device>): Device | null {
    const device = this.getDevice(id);
    if (!device) return null;
    Object.assign(device, patch);
    this.save();
    return device;
  }

  setDeviceOnline(deviceId: string, online: boolean, wsClientId?: string): void {
    const device = this.getDevice(deviceId);
    if (!device) return;
    device.online = online;
    device.wsClientId = online ? wsClientId : undefined;
    device.lastSeenAt = new Date().toISOString();
    this.save();
  }

  // ------------------------------------------------------------------- pairs
  getPair(id: string): Pair | null {
    return this.data.pairs.find((p) => p.id === id) ?? null;
  }

  getPairByDevices(controllerDeviceId: string, agentDeviceId: string): Pair | null {
    return this.data.pairs.find(
      (p) => p.controllerDeviceId === controllerDeviceId && p.agentDeviceId === agentDeviceId,
    ) ?? null;
  }

  listApprovedPairs(controllerDeviceId: string): Pair[] {
    return this.data.pairs.filter(
      (p) => p.controllerDeviceId === controllerDeviceId && p.status === 'approved',
    );
  }

  createPair(pair: Pair): Pair {
    this.data.pairs.push(pair);
    this.save();
    return pair;
  }

  updatePair(id: string, patch: Partial<Pair>): Pair | null {
    const pair = this.getPair(id);
    if (!pair) return null;
    Object.assign(pair, patch);
    this.save();
    return pair;
  }

  revokePair(pairId: string): Pair | null {
    const pair = this.getPair(pairId);
    if (!pair) return null;
    if (pair.status === 'approved') {
      pair.status = 'revoked';
      pair.revokedAt = new Date().toISOString();
      this.save();
    }
    return pair;
  }

  // ------------------------------------------------------------ pairing codes
  getLivePairingCode(deviceId: string): PairingCode | null {
    const now = Date.now();
    return (
      this.data.pairingCodes.find(
        (c) => !c.used && c.deviceId === deviceId && new Date(c.expiresAt).getTime() > now,
      ) ?? null
    );
  }

  createPairingCode(code: PairingCode): PairingCode {
    this.data.pairingCodes.push(code);
    this.save();
    return code;
  }

  usePairingCode(id: string): void {
    const code = this.data.pairingCodes.find((c) => c.id === id);
    if (code) {
      code.used = true;
      this.save();
    }
  }

  // --------------------------------------------------------------- sessions
  getSession(id: string): Session | null {
    return this.data.sessions.find((s) => s.id === id) ?? null;
  }

  listSessions(filter: Partial<Pick<Session, 'controllerDeviceId' | 'agentDeviceId' | 'status'>>): Session[] {
    return this.data.sessions.filter((s) => {
      if (filter.controllerDeviceId && s.controllerDeviceId !== filter.controllerDeviceId) return false;
      if (filter.agentDeviceId && s.agentDeviceId !== filter.agentDeviceId) return false;
      if (filter.status && s.status !== filter.status) return false;
      return true;
    });
  }

  createSession(session: Session): Session {
    this.data.sessions.push(session);
    this.save();
    return session;
  }

  updateSession(id: string, patch: Partial<Session>): Session | null {
    const session = this.getSession(id);
    if (!session) return null;
    Object.assign(session, patch, { lastActivityAt: new Date().toISOString() });
    this.save();
    return session;
  }
}