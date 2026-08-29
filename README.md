# RMODZ Remote

A consent-based remote-support system for Android. A **controller** app (running
on one device) pairs with and remotely views/controls an **agent** app (running
on another device) over a peer-to-peer WebRTC connection, coordinated by a
signaling server. Everything requires explicit user consent on the agent — no
stealth, no bypass.

> **Pengguna Indonesia / step-by-step instalasi & pakai: lihat [USAGE.md](docs/USAGE.md).**

## Monorepo layout

```
├─ controller/   Flutter app: the "helper" device that connects & controls
├─ agent/        Flutter app: the "helped" device that is paired and controlled
├─ server/       Node.js/TypeScript signaling + auth backend
├─ shared/       Cross-app contracts (protocol docs)
└─ docs/         Additional documentation
```

Only official Android APIs are used (MediaProjection for screen capture,
AccessibilityService for touch/navigation/text, CameraX via flutter_webrtc for
camera/mic).

## How it works

1. **Server** runs the signaling + auth backend.
2. **Agent** self-registers, connects to the WebSocket, and can generate a
   6-digit **pairing code** to display on screen.
3. **Controller** signs in, enters that code, and the agent's user approves the
   pairing.
4. The controller requests a **session**, listing the permissions it wants.
   The agent's user reviews and grants (or denies) each one.
5. The agent (offerer) starts capturing **screen** (MediaProjection),
   **camera**, and **mic** tracks per granted permission and offers a WebRTC
   connection; the controller answers and can view the screen, tap (touch
   control), navigate, type, and send files over a data channel.
6. Either side can **end the session** or **revoke a permission** at any time.

## Requirements

- Flutter 3.47+ / Dart 3.13+
- Android SDK with API 34/35
- Node.js 20+
- Two Android devices (or a device + emulator) running API 23–35

## Server

```bash
cd server
npm install
cp .env.example .env     # set secrets
npm run dev              # or npm run build && npm start
```

See `server/README.md` for full configuration (ports, secrets, STUN/TURN).

## Controller app

```bash
cd controller
flutter pub get
flutter analyze
flutter test
flutter build apk --debug     # or --release
```

APK output: `controller/build/app/outputs/flutter-apk/app-debug.apk`

Configure the server address at build time with `--dart-define=RMODZ_SERVER_URL=...`
(defaults to `http://10.0.2.2:8080`, the emulator loopback for the host machine):
`flutter build apk --release --dart-define=RMODZ_SERVER_URL=http://192.168.1.10:8080`

## Agent app

```bash
cd agent
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK output: `agent/build/app/outputs/flutter-apk/app-debug.apk`

Configure the server address at build time with `--dart-define=RMODZ_SERVER_URL=...`
(defaults to `http://10.0.2.2:8080`). On device, enable the **RMODZ accessibility
service** (Settings → Accessibility) when you want touch control.

## Testing on devices

1. Start the server.
2. Install the **controller** APK on device A and the **agent** APK on device B
   (both pointing at the server).
3. Both devices must reach the server. For a LAN setup, point `baseUrl` at the
   server machine's LAN IP (e.g. `http://192.168.1.10:8080`); add your own TURN
   server for connectivity across different networks.
4. On the agent, tap **Generate pairing code**; on the controller, enter it and
   request a session; approve on the agent.

## Protocol

See [shared/protocol/protocol.md](shared/protocol/protocol.md).

## License

MIT — see [LICENSE](LICENSE).
