import { NextFunction, Request, Response } from 'express';
import { verifyDeviceToken, DeviceTokenPayload } from './crypto.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: DeviceTokenPayload;
      clientIp?: string;
    }
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const payload = token ? verifyDeviceToken(token) : null;
  if (!payload) {
    res.status(401).json({ error: 'unauthorized', message: 'A valid access token is required.' });
    return;
  }
  req.auth = payload;
  next();
}

export function requireRole(role: 'controller' | 'agent') {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.auth || req.auth.role !== role) {
      res.status(403).json({ error: 'forbidden', message: `This endpoint requires a ${role} account/device.` });
      return;
    }
    next();
  };
}

export function requireAuthOptional(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  req.auth = token ? (verifyDeviceToken(token) ?? undefined) : undefined;
  next();
}

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    void fn(req, res, next).catch(next);
  };
}

export function errorMiddleware(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof HttpError) {
    res.status(err.status).json({ error: err.code, message: err.message });
    return;
  }
  console.error('[error]', err);
  res.status(500).json({ error: 'internal_error', message: 'Something went wrong. Please try again.' });
}