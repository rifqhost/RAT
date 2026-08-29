import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(__dirname, '..');

function parseJsonList(value: string | undefined, fallback: unknown[]): unknown[] {
  if (!value) return fallback;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : fallback;
  } catch {
    return fallback;
  }
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  host: process.env.HOST ?? '0.0.0.0',
  publicBaseUrl: process.env.PUBLIC_BASE_URL ?? `http://localhost:${process.env.PORT ?? 8080}`,
  jwtSecret: process.env.JWT_SECRET ?? 'dev-only-insecure-secret-change-me',
  pairingTokenSecret: process.env.PAIRING_TOKEN_SECRET ?? 'dev-only-pairing-secret-change-me',
  authTokenTtl: Number(process.env.AUTH_TOKEN_TTL ?? 3600),
  pairingCodeTtl: Number(process.env.PAIRING_CODE_TTL ?? 300),
  sessionTokenTtl: Number(process.env.SESSION_TOKEN_TTL ?? 3600),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX ?? 120),
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS ?? 60000),
  dataFile: process.env.DATA_FILE ?? path.join(serverRoot, 'data', 'store.json'),
  stunServers: parseJsonList(process.env.STUN_SERVERS, [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ]).map((s) => String(s)),
  turnServers: parseJsonList(process.env.TURN_SERVERS, []).map((s) => String(s)),
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((s) => s.trim()),
} as const;