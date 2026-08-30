import { z } from 'zod';
import { Envelope, SessionMessageType } from './types.js';

export const permissionSchema = z.enum([
  'SCREEN',
  'TOUCH',
  'CAMERA',
  'MICROPHONE',
  'FILES',
  'CLIPBOARD',
  'DEVICE_INFO',
]);

export const permissionListSchema = z.array(permissionSchema).max(7);

const idString = z.string().min(1).max(128);
const tokenString = z.string().min(1).max(2048);
const reasonSchema = z.string().min(1).max(200);

export const messageSchemas: Record<SessionMessageType, z.ZodTypeAny> = {
  AUTH: z.object({
    deviceId: idString,
    role: z.enum(['controller', 'agent']),
    token: tokenString,
    name: z.string().max(64).optional(),
    model: z.string().max(64).optional(),
    androidVersion: z.string().max(32).optional(),
    appVersion: z.string().max(32).optional(),
    rejoin: z.object({ sessionId: idString, sessionToken: tokenString }).optional(),
  }),

  AUTH_OK: z.object({
    deviceId: idString,
    role: z.enum(['controller', 'agent']),
    onlineDevices: z.array(z.string()),
    activeSessionId: z.string().optional(),
  }),

  AUTH_ERROR: z.object({ code: idString, message: z.string() }).optional(),

  ERROR: z.object({ code: idString, message: z.string(), refId: idString.optional() }).optional(),

  HELLO: z.object({ status: z.string() }),

  // Agent requests a fresh pairing code
  PAIR_REQUEST: z.object({ deviceId: idString }),

  PAIR_RESPONSE: z.object({
    deviceId: idString,
    code: z.string(),
    expiresAt: z.number(),
    expiresIn: z.number(),
  }),

  // Server -> agent: someone wants to pair with this agent
  PAIR_APPROVAL: z.object({
    pairId: idString,
    controllerDeviceId: idString,
    controllerName: z.string(),
    requestedAt: z.number(),
  }),

  // Agent -> server: approve/deny pairing
  PAIR_APPROVED: z.object({ pairId: idString }),
  PAIR_DENIED: z.object({ pairId: idString }),

  // Server -> agent: a controller is requesting remote access
  SESSION_REQUEST: z.object({
    sessionId: idString,
    controllerDeviceId: idString,
    controllerName: z.string(),
    permissions: permissionListSchema,
    iceServers: z.array(z.unknown()).default([]),
    requestedAt: z.number(),
  }),

  // Agent -> server (accept/deny/reduce), then server -> controller
  SESSION_ACCEPT: z.object({
    sessionId: idString,
    permissions: permissionListSchema,
  }),
  SESSION_DENY: z.object({ sessionId: idString, reason: reasonSchema.optional() }),

  // Server -> controller: session established + session token for rejoin
  SESSION_ACCEPTED: z.object({
    sessionId: idString,
    permissions: permissionListSchema,
    sessionToken: tokenString,
    iceServers: z.array(z.unknown()).default([]),
  }),

  // Rejoin after network flip
  SESSION_REJOIN: z.object({ sessionId: idString, sessionToken: tokenString }),

  // Server -> both: session ended
  SESSION_ENDED: z.object({
    sessionId: idString,
    reason: reasonSchema,
    endedBy: z.enum(['controller', 'agent', 'server']),
  }),

  OFFER: z.object({ sessionId: idString, sdp: z.string().min(1) }),
  ANSWER: z.object({ sessionId: idString, sdp: z.string().min(1) }),
  ICE_CANDIDATE: z.object({
    sessionId: idString,
    candidate: z.unknown(),
  }),

  TOUCH_EVENT: z.object({
    sessionId: idString,
    eventType: z.enum(['touch_down', 'touch_move', 'touch_up', 'tap', 'long_press', 'swipe']),
    x: z.number().min(0).max(1),
    y: z.number().min(0).max(1),
    timestamp: z.number(),
    screenWidth: z.number().int().positive(),
    screenHeight: z.number().int().positive(),
    action: z.number().int().optional(),
  }),

  CONTROL_EVENT: z.object({
    sessionId: idString,
    kind: z.enum([
      'NAV_BACK',
      'NAV_HOME',
      'NAV_RECENTS',
      'TEXT_INPUT',
      'CAMERA_ON',
      'CAMERA_OFF',
      'MIC_ON',
      'MIC_OFF',
      'DEVICE_STATUS',
      'PERMISSION_GRANT',
      'PERMISSION_REVOKE',
    ]),
    value: z.union([z.string(), z.number(), z.boolean(), z.object({}).passthrough()]).optional(),
  }),

  FILE_REQUEST: z.object({
    sessionId: idString,
    transferId: idString,
    fileName: z.string().max(255),
    fileSize: z.number().int().nonnegative(),
    mimeType: z.string().max(128),
    sha256: z.string().max(64).optional(),
    chunkSize: z.number().int().positive().optional(),
  }),

  FILE_ACCEPT: z.object({ sessionId: idString, transferId: idString }),
  FILE_DECLINE: z.object({ sessionId: idString, transferId: idString, reason: reasonSchema.optional() }),

  FILE_PROGRESS: z.object({
    sessionId: idString,
    transferId: idString,
    transferred: z.number().int().nonnegative(),
  }),

  FILE_COMPLETE: z.object({
    sessionId: idString,
    transferId: idString,
    sha256: z.string().max(64).optional(),
  }),

  CLIPBOARD_EVENT: z.object({
    sessionId: idString,
    direction: z.enum(['controller_to_agent', 'agent_to_controller']),
    text: z.string().max(1048576),
  }),

  PERMISSION_UPDATE: z.object({
    sessionId: idString,
    permission: permissionSchema,
    granted: z.boolean(),
  }),

  DISCONNECT: z.object({ sessionId: idString, reason: reasonSchema.optional() }),

  PING: z.object({ ts: z.number() }),
  PONG: z.object({ ts: z.number() }),
};

export function validateMessage(input: unknown): { ok: true; value: Envelope } | { ok: false; error: string } {
  if (typeof input !== 'object' || input === null) return { ok: false, error: 'expected object' };
  const raw = input as Record<string, unknown>;
  const type = raw.type as SessionMessageType;
  const schema = messageSchemas[type];
  if (!schema) return { ok: false, error: `unknown message type: ${String(raw.type)}` };
  const id = typeof raw.id === 'string' ? raw.id : '';
  if (!id) return { ok: false, error: 'missing message id' };
  const ts = typeof raw.ts === 'number' ? raw.ts : Date.now();
  const parsed = schema.safeParse(raw.payload);
  if (!parsed.success) {
    return { ok: false, error: `invalid payload for ${type}: ${parsed.error.issues[0]?.message ?? 'validation failed'}` };
  }
  return { ok: true, value: { id, type, payload: parsed.data, ts } };
}