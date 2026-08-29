import { Router } from 'express';
import { z } from 'zod';
import { Store } from '../store.js';
import { asyncHandler, HttpError, requireAuth } from '../auth.js';
import { hashSecret, randomToken, signDeviceToken, verifySecret } from '../crypto.js';

const registerSchema = z.object({
  name: z.string().min(2).max(64),
  email: z.string().email().max(128),
  password: z.string().min(8).max(128),
});

const loginSchema = z.object({
  email: z.string().email().max(128),
  password: z.string().min(1).max(128),
});

export function authRoutes(store: Store): Router {
  const router = Router();

  router.post(
    '/register',
    asyncHandler(async (req, res) => {
      const parsed = registerSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', parsed.error.issues[0]?.message ?? 'Invalid registration.');
      }
      const { name, email, password } = parsed.data;
      if (store.getUserByEmail(email)) {
        throw new HttpError(409, 'email_taken', 'An account with this email already exists.');
      }
      const { salt, hash } = hashSecret(password);
      const user = store.createUser({
        id: randomToken(12),
        name,
        email,
        passSalt: salt,
        passHash: hash,
        createdAt: new Date().toISOString(),
      });
      store.audit('USER_REGISTERED', user.id, email);
      const token = signDeviceToken({ sub: `user:${user.id}`, typ: 'device', role: 'controller', name: user.name });
      res.status(201).json({ token, user: { id: user.id, name: user.name, email: user.email } });
    }),
  );

  router.post(
    '/login',
    asyncHandler(async (req, res) => {
      const parsed = loginSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new HttpError(400, 'validation_error', parsed.error.issues[0]?.message ?? 'Invalid login.');
      }
      const { email, password } = parsed.data;
      const user = store.getUserByEmail(email);
      if (!user || !verifySecret(password, user.passSalt, user.passHash)) {
        throw new HttpError(401, 'invalid_credentials', 'Email or password is incorrect.');
      }
      store.audit('USER_LOGIN', user.id);
      const token = signDeviceToken({ sub: `user:${user.id}`, typ: 'device', role: 'controller', name: user.name });
      res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    }),
  );

  router.get('/me', requireAuth, asyncHandler(async (req, res) => {
    res.json({ sub: req.auth?.sub, role: req.auth?.role, name: req.auth?.name });
  }));

  return router;
}