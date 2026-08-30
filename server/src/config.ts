import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(__dirname, '..');

export interface IceServerConfig {
  urls: string | string[];
  username?: string;
  credential?: string;
}

function parseIceServers(value: string | undefined, fallback: string[]): IceServerConfig[] {
  if (!value) return fallback.map((u) => ({ urls: u }));
  let parsed: unknown[];
  try {
    const decoded = JSON.parse(value);
    if (!Array.isArray(decoded)) return fallback.map((u) => ({ urls: u }));
    parsed = decoded;
  } catch {
    return fallback.map((u) => ({ urls: u }));
  }
  return parsed.map((entry) => {
    if (typeof entry === 'string') return { urls: entry };
    if (typeof entry === 'object' && entry !== null) {
      const e = entry as Record<string, unknown>;
      const urls = e['urls'];
      return {
        urls: urls as string | string[],
        ...(e['username'] !== undefined ? { username: String(e['username']) } : {}),
        ...(e['credential'] !== undefined ? { credential: String(e['credential']) } : {}),
      };
    }
    return { urls: String(entry) };
  });
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
  stunServers: parseIceServers(process.env.STUN_SERVERS, [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ]),
  turnServers: parseIceServers(process.env.TURN_SERVERS, []),
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((s) => s.trim()),
} as const;
