import { NextFunction, Request, Response } from 'express';
import { config } from './config.js';

interface Bucket {
  count: number;
  resetAt: number;
}

/**
 * Fixed-window in-memory rate limiter, keyed by client IP + route.
 * Used to slow brute-force attempts on auth and pairing endpoints.
 */
export class RateLimiter {
  private readonly buckets = new Map<string, Bucket>();
  private readonly max: number;
  private readonly windowMs: number;

  constructor(max = config.rateLimitMax, windowMs = config.rateLimitWindowMs) {
    this.max = max;
    this.windowMs = windowMs;
  }

  private keyFor(req: Request): string {
    const ip = req.clientIp ?? req.ip ?? 'unknown';
    return `${ip}:${req.path}`;
  }

  isLimited(req: Request): boolean {
    const now = Date.now();
    const key = this.keyFor(req);
    let bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + this.windowMs };
      this.buckets.set(key, bucket);
    }
    bucket.count += 1;
    return bucket.count > this.max;
  }

  middleware() {
    return (req: Request, res: Response, next: NextFunction): void => {
      if (this.isLimited(req)) {
        res.status(429).json({ error: 'rate_limited', message: 'Too many requests. Please slow down.' });
        return;
      }
      next();
    };
  }
}