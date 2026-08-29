import { Router } from 'express';
import { z } from 'zod';
import { Store } from '../store.js';
import { WsHub } from '../ws/hub.js';
import { asyncHandler, HttpError, requireAuth, requireRole } from '../auth.js';
import { permissionListSchema } from '../protocol.js';
import { randomToken, signSessionToken } from '../crypto.js';

const createSessionSchema = z.object({
  agentDeviceId: z.string().regex(/^RMDZ-[A-Z0-9]{6,10}$/),
  permissions: permissionListSchema,
});

export function sessionRoutes(store: Store, hub: WsHub): Router {
  const router = Router();

  router.post(
    '/',
    requireAuth,
    requireRole('controller'),
    asyncHandler(async (req, res) => {
      const controllerId = req.auth!.sub;
      if (!controllerId.startsWith('RMDZ-')) {
        throw new HttpError(400, 'controller_device_required', 'This client must be a registered controller device.');
      }
      const parsed = createSessionSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', parsed.error.issues[0]?.message ?? 'Invalid session payload.');
      }
      const { agentDeviceId, permissions } = parsed.data;

      const agent = store.getDevice(agentDeviceId);
      if (!agent || agent.role !== 'agent') {
        throw new HttpError(404, 'agent_not_found', 'No agent device with that ID.');
      }
      if (!agent.online) {
        throw new HttpError(409, 'agent_offline', 'The agent device is offline.');
      }
      const pair = store.getPairByDevices(controllerId, agentDeviceId);
      if (!pair || pair.status !== 'approved') {
        throw new HttpError(403, 'not_paired', 'This device is not paired and approved.');
      }

      const session = store.createSession({
        id: randomToken(14),
        controllerDeviceId: controllerId,
        agentDeviceId,
        status: 'requested',
        permissions,
        createdAt: new Date().toISOString(),
        lastActivityAt: new Date().toISOString(),
      });
      store.audit('SESSION_REQUESTED', controllerId, `${session.id} -> ${agentDeviceId}`);
      const delivered = hub.requestSession(agentDeviceId, session.id, controllerId, req.auth?.name ?? 'RMODZ Controller', permissions);
      if (!delivered) {
        store.updateSession(session.id, { status: 'ended', endedAt: new Date().toISOString(), endedReason: 'agent_offline' });
        throw new HttpError(409, 'agent_offline', 'Could not reach the agent device.');
      }
      res.status(201).json({ sessionId: session.id, status: session.status });
    }),
  );

  router.get(
    '/',
    requireAuth,
    asyncHandler(async (req, res) => {
      const deviceId = req.auth!.sub;
      if (!deviceId.startsWith('RMDZ-')) {
        res.json({ sessions: [] });
        return;
      }
      const device = store.getDevice(deviceId);
      if (!device) {
        res.json({ sessions: [] });
        return;
      }
      const sessions =
        device.role === 'controller'
          ? store.listSessions({ controllerDeviceId: deviceId })
          : store.listSessions({ agentDeviceId: deviceId });
      res.json({
        sessions: sessions
          .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
          .slice(0, 50)
          .map((s) => ({ id: s.id, status: s.status, permissions: s.permissions, createdAt: s.createdAt, controllers: [s.controllerDeviceId] })),
      });
    }),
  );

  router.delete(
    '/:id',
    requireAuth,
    asyncHandler(async (req, res) => {
      const session = store.getSession(req.params.id);
      if (!session) {
        throw new HttpError(404, 'session_not_found', 'No such session.');
      }
      const deviceId = req.auth!.sub;
      if (session.controllerDeviceId !== deviceId && session.agentDeviceId !== deviceId) {
        throw new HttpError(403, 'forbidden', 'You are not part of this session.');
      }
      const device = store.getDevice(deviceId);
      const endedBy = device?.role === 'agent' ? 'agent' : 'controller';
      if (session.status !== 'ended') {
        hub.endSession(session.id, `${endedBy}_stop`, endedBy);
      }
      res.json({ ok: true, sessionId: session.id, status: 'ended' });
    }),
  );

  // Current active session info
  router.get(
    '/active',
    requireAuth,
    asyncHandler(async (req, res) => {
      const deviceId = req.auth!.sub;
      if (!deviceId.startsWith('RMDZ-')) {
        res.json({ session: null });
        return;
      }
      const active = store
        .listSessions({ status: 'active' })
        .find((s) => s.controllerDeviceId === deviceId || s.agentDeviceId === deviceId);
      if (!active) {
        res.json({ session: null });
        return;
      }
      let sessionToken: string | undefined;
      const device = store.getDevice(deviceId);
      if (device?.role === 'controller') {
        sessionToken = signSessionToken(active.id);
      }
      res.json({
        session: {
          id: active.id,
          controllerDeviceId: active.controllerDeviceId,
          agentDeviceId: active.agentDeviceId,
          permissions: active.permissions,
          startedAt: active.startedAt,
        },
        sessionToken,
      });
    }),
  );

  return router;
}