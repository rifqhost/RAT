import { Router } from 'express';
import { z } from 'zod';
import { Store } from '../store.js';
import { WsHub } from '../ws/hub.js';
import { asyncHandler, HttpError, requireAuth, requireRole } from '../auth.js';
import { generateDeviceId, randomToken, sha256, signDeviceToken } from '../crypto.js';

const registerDeviceSchema = z.object({
  role: z.enum(['controller', 'agent']),
  name: z.string().min(2).max(64),
  model: z.string().max(64).optional(),
  androidVersion: z.string().max(32).optional(),
  appVersion: z.string().max(32).optional(),
});

const pairSchema = z.object({
  deviceId: z.string().regex(/^RMDZ-[A-Z0-9]{6,10}$/),
  code: z.string().regex(/^\d{6}$/),
});

export function deviceRoutes(store: Store, hub: WsHub): Router {
  const router = Router();

  router.post(
    '/register',
    requireAuth,
    asyncHandler(async (req, res) => {
      const parsed = registerDeviceSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', parsed.error.issues[0]?.message ?? 'Invalid device registration.');
      }
      const userId = req.auth!.sub;
      const device = store.createDevice({
        id: generateDeviceId('RMDZ'),
        role: parsed.data.role,
        userId,
        name: parsed.data.name,
        model: parsed.data.model,
        androidVersion: parsed.data.androidVersion,
        appVersion: parsed.data.appVersion,
        createdAt: new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
        online: false,
      });
      store.audit('DEVICE_REGISTERED', device.id, `${device.role} ${device.id}`);
      const deviceToken = signDeviceToken({
        sub: device.id,
        typ: 'device',
        role: device.role,
        name: device.name,
      });
      res.status(201).json({ device: { id: device.id, role: device.role, name: device.name }, deviceToken });
    }),
  );

  // Agent self-registration. The agent generates its own identity on first run.
  // The returned device token is the credential used to authenticate its WS
  // connection. Pairing codes + explicit approval gate the controller->agent link.
  router.post(
    '/agent/register',
    asyncHandler(async (req, res) => {
      const parsed = z
        .object({
          name: z.string().min(2).max(64).optional(),
          model: z.string().max(64).optional(),
          androidVersion: z.string().max(32).optional(),
          appVersion: z.string().max(32).optional(),
          deviceId: z.string().regex(/^RMDZ-[A-Z0-9]{6}$/).optional(),
        })
        .safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', 'Invalid agent registration.');
      }
      // Prefer a device id generated on-device so it stays stable across re-installs;
      // otherwise allocate one server-side.
      const id = parsed.data.deviceId
        ? (store.getDevice(parsed.data.deviceId) ? null : parsed.data.deviceId)
        : undefined;
      if (parsed.data.deviceId && !id) {
        throw new HttpError(409, 'device_taken', 'That device id is already in use.');
      }
      const device = store.createDevice({
        id: id ?? generateDeviceId('RMDZ'),
        role: 'agent',
        userId: `agent:${id ?? 'new'}`,
        name: parsed.data.name ?? 'RMODZ Agent',
        model: parsed.data.model,
        androidVersion: parsed.data.androidVersion,
        appVersion: parsed.data.appVersion,
        createdAt: new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
        online: false,
      });
      store.audit('DEVICE_REGISTERED', device.id, `agent ${device.id}`);
      const deviceToken = signDeviceToken({
        sub: device.id,
        typ: 'device',
        role: 'agent',
        name: device.name,
      });
      res.status(201).json({ device: { id: device.id, role: 'agent', name: device.name }, deviceToken });
    }),
  );

  router.get(
    '/',
    requireAuth,
    requireRole('controller'),
    asyncHandler(async (req, res) => {
      const controllerId = req.auth!.sub;
      if (!controllerId.startsWith('RMDZ-')) {
        // Authenticated as a user account, resolve its controller devices.
        const devices = store.getDevicesByUser(req.auth!.sub);
        const list = devices.filter((d) => d.role === 'controller');
        res.json({ devices: list.map(toPublicDevice) });
        return;
      }
      const pairs = store.listApprovedPairs(controllerId);
      const devices = pairs
        .map((pair) => store.getDevice(pair.agentDeviceId))
        .filter((d): d is NonNullable<typeof d> => d !== null)
        .map((d) => ({ ...toPublicDevice(d), pairId: pairs.find((p) => p.agentDeviceId === d.id)?.id }));
      res.json({ devices });
    }),
  );

  router.post(
    '/pair',
    requireAuth,
    requireRole('controller'),
    asyncHandler(async (req, res) => {
      const parsed = pairSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', parsed.error.issues[0]?.message ?? 'Invalid pairing payload.');
      }
      const { deviceId: agentDeviceId, code } = parsed.data;
      const controllerId = req.auth!.sub;
      if (!controllerId.startsWith('RMDZ-')) {
        throw new HttpError(400, 'controller_device_required', 'This client must be a registered controller device.');
      }
      const agent = store.getDevice(agentDeviceId);
      if (!agent || agent.role !== 'agent') {
        throw new HttpError(404, 'agent_not_found', 'No agent device with that ID.');
      }
      const live = store.getLivePairingCode(agentDeviceId);
      if (!live) {
        throw new HttpError(410, 'pairing_expired', 'Pairing code has expired. Ask the agent for a new one.');
      }
      if (sha256(code) !== live.codeHash) {
        throw new HttpError(401, 'invalid_pairing_code', 'Pairing code is invalid.');
      }
      store.usePairingCode(live.id);

      const existing = store.getPairByDevices(controllerId, agentDeviceId);
      if (existing && existing.status === 'approved') {
        res.json({ pairId: existing.id, status: existing.status, requiresApproval: false });
        return;
      }
      const pair = store.createPair({
        id: randomToken(12),
        controllerDeviceId: controllerId,
        agentDeviceId,
        status: 'pending',
        createdAt: new Date().toISOString(),
      });
      store.audit('PAIR_STARTED', controllerId, agentDeviceId);
      const delivered = hub.requestPairApproval(pair.id, agentDeviceId, controllerId, req.auth!.name ?? 'RMODZ Controller');
      res.status(201).json({ pairId: pair.id, status: pair.status, requiresApproval: true, agentNotified: delivered });
    }),
  );

  return router;
}

function toPublicDevice(d: {
  id: string;
  role: string;
  name: string;
  model?: string;
  androidVersion?: string;
  appVersion?: string;
  online: boolean;
  lastSeenAt: string;
}) {
  return {
    id: d.id,
    name: d.name,
    model: d.model,
    androidVersion: d.androidVersion,
    appVersion: d.appVersion,
    online: d.online,
    lastSeenAt: d.lastSeenAt,
  };
}

export { toPublicDevice };