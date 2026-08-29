# RMODZ Remote — Server

Authentication, device registry, pairing, WebRTC signaling and session
management backend for the RMODZ Remote remote-support system.

## Stack

- Node.js 20+ / TypeScript (ESM, `NodeNext`)
- Express 4 (REST API) + `ws` (WebSocket signaling)
- `zod` for request/message validation
- `jsonwebtoken` for user/device/session tokens
- JSON-file data store (in-memory snapshot persisted to `data/store.json`)

## Getting started

```bash
npm install
cp .env.example .env   # then edit secrets (see below)
npm run dev            # or: npm run build && npm start
```

The server listens on `PORT` (default `8080`) at `/ws` for signaling and `/api`
for REST.

## Configuration

See `.env.example`. At a minimum, set unique secrets in production:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

- `JWT_SECRET` — signs user auth tokens and device tokens.
- `PAIRING_TOKEN_SECRET` — signs pairing/session tokens.
- `DATA_FILE` — where registered users, devices, pairs and sessions are stored.
  Point this outside the repo in production.
- `STUN_SERVERS` / `TURN_SERVERS` — advertised to clients for WebRTC
  connectivity. Add your own TURN servers to make P2P work across NATs.

## Scripts

| Command           | Purpose                                  |
|-------------------|------------------------------------------|
| `npm run dev`     | Watch-mode dev server via `tsx`          |
| `npm run build`   | Compile TypeScript to `dist/`            |
| `npm start`       | Run the compiled server                  |
| `npm test`        | Build + run the node:test suite          |
| `npm run lint`    | Type-check only                          |

## REST API

| Method | Path                        | Auth     | Purpose                                  |
|--------|-----------------------------|----------|------------------------------------------|
| GET    | `/health`                   | –        | Liveness                                  |
| POST   | `/api/auth/register`        | –        | Create a user account                     |
| POST   | `/api/auth/login`           | –        | Log in, get a user token                  |
| POST   | `/api/devices/register`     | user     | Register a controller/agent device        |
| POST   | `/api/devices/agent/register` | –      | Agent self-registration (returns its own device token) |
| GET    | `/api/devices`              | user     | List the caller's devices                 |
| POST   | `/api/devices/pair`         | user     | Start pairing with an agent using a code  |
| POST   | `/api/sessions`             | user     | Request a session on a paired agent       |
| GET    | `/api/sessions`             | user     | List sessions                             |
| GET    | `/api/sessions/active`      | user     | Get the caller's active session           |
| DELETE | `/api/sessions/:id`         | user     | End a session                             |

## Testing

```bash
npm test
```

The suite covers REST (register/login, device registration, agent
self-registration) and a full WebSocket flow (pairing → session → signaling →
permission revoke → disconnect), including a negative permission-denied test.
