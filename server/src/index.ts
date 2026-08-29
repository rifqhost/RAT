import express from 'express';
import cors from 'cors';
import http from 'node:http';
import { config } from './config.js';
import { Store } from './store.js';
import { WsHub } from './ws/hub.js';
import { errorMiddleware } from './auth.js';
import { RateLimiter } from './rateLimit.js';
import { authRoutes } from './routes/auth.routes.js';
import { deviceRoutes } from './routes/devices.routes.js';
import { sessionRoutes } from './routes/sessions.routes.js';

void errorMiddleware;

export function createApp() {
  const app = express();
  const limiter = new RateLimiter();
  const store = new Store(config.dataFile);
  const hub = new WsHub(store, [
    ...config.stunServers.map((u) => ({ urls: u })),
    ...(config.turnServers as unknown as { urls: string[] }[]).map((t) => ({ urls: t.urls })),
  ]);

  app.set('trust proxy', true);
  app.use((req, _res, next) => {
    req.clientIp = req.ip;
    next();
  });
  app.use(cors({ origin: config.corsOrigins.includes('*') ? '*' : config.corsOrigins }));
  app.use(express.json({ limit: '1mb' }));
  app.use('/api', limiter.middleware());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptime: process.uptime(), ts: Date.now() });
  });

  app.use('/api/auth', authRoutes(store));
  app.use('/api/devices', deviceRoutes(store, hub));
  app.use('/api/sessions', sessionRoutes(store, hub));

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found', message: 'Route not found.' });
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
    errorMiddleware(err as Error, req, res, _next);
  });

  return { app, store, hub };
}

if (import.meta.url === new URL(process.argv[1] ?? '', 'file:').href) {
  const { app, hub } = createApp();
  const server = http.createServer(app);
  hub.attach(server);
  server.listen(config.port, config.host, () => {
    console.log(`[rmodz] server listening on http://${config.host}:${config.port}`);
  });
}