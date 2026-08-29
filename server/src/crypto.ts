import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from './config.js';

/** Generates a device id similar to RMDZ-A7F92K using a confusion-free base32 alphabet. */
export function generateDeviceId(prefix: string): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  const bytes = crypto.randomBytes(6);
  for (let i = 0; i < bytes.length; i++) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return `${prefix}-${out}`;
}

/** A short-lived numeric pairing code. */
export function generatePairingCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

export function sha256(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export interface HashResult {
  salt: string;
  hash: string;
  iterations: number;
}

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LEN = 64;

export function hashSecret(secret: string, salt = crypto.randomBytes(16).toString('hex')): HashResult {
  const hash = crypto.scryptSync(secret, salt, KEY_LEN, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P });
  return { salt, hash: hash.toString('hex'), iterations: SCRYPT_N };
}

export function verifySecret(secret: string, salt: string, expectedHash: string): boolean {
  const hash = crypto.scryptSync(secret, salt, KEY_LEN, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P });
  const a = Buffer.from(hash.toString('hex'));
  const b = Buffer.from(expectedHash);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

export interface DeviceTokenPayload {
  sub: string;
  typ: 'device';
  role: 'controller' | 'agent';
  name?: string;
}

export interface SessionTokenPayload {
  sub: string;
  typ: 'session';
}

/** Short-lived device token used for REST auth and WS auth. */
export function signDeviceToken(payload: DeviceTokenPayload, ttlSeconds = config.authTokenTtl): string {
  return jwt.sign({ ...payload, typ: 'device' }, config.jwtSecret, { expiresIn: ttlSeconds });
}

export function verifyDeviceToken(token: string): DeviceTokenPayload | null {
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as { sub: string; typ: string; role: string; name?: string };
    if (decoded.typ !== 'device') return null;
    if (decoded.role !== 'controller' && decoded.role !== 'agent') return null;
    return { sub: decoded.sub, typ: 'device', role: decoded.role, name: decoded.name };
  } catch {
    return null;
  }
}

/** Short-lived session token that authorizes WS rejoin during an active session. */
export function signSessionToken(sessionId: string, ttlSeconds = config.sessionTokenTtl): string {
  return jwt.sign({ sub: sessionId, typ: 'session' }, config.jwtSecret, { expiresIn: ttlSeconds });
}

export function verifySessionToken(token: string): { sessionId: string } | null {
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as { sub: string; typ: string };
    if (decoded.typ !== 'session' || !decoded.sub) return null;
    return { sessionId: decoded.sub };
  } catch {
    return null;
  }
}

/** HMAC used to bind a pairing code to a device so codes cannot be replayed elsewhere. */
export function pairCodeToken(deviceId: string, code: string, expiresAt: number): string {
  return crypto
    .createHmac('sha256', config.pairingTokenSecret)
    .update(`${deviceId}:${code}:${expiresAt}`)
    .digest('hex');
}

export function randomToken(byteLength = 24): string {
  return crypto.randomBytes(byteLength).toString('hex');
}