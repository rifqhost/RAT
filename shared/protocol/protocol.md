# RMODZ Remote Signaling Protocol

This document is the single source of truth for messages exchanged between the
controller app, the agent app, and the signaling server. Both Flutter apps
mirror these schemas (see `controller/lib/core/protocol.dart` and
`agent/lib/core/protocol.dart`); the server validates them with zod
(`server/src/protocol.ts`).

## Transport

- REST over HTTP for auth / device / session setup.
- WebSocket at `GET /ws` for all realtime signaling.
- WebRTC (via `flutter_webrtc`) carries the actual audio/video/data.

## Message envelope

Every WebSocket message is a JSON object:

```json
{
  "id": "<opaque message id>",
  "type": "<MESSAGE_TYPE>",
  "payload": { },
  "ts": 1699999999999
}
```

## Message types

### Lifespan / connection

| Sender  → Receiver | Type              | Payload                                                      |
|--------------------|-------------------|--------------------------------------------------------------|
| server → client    | `HELLO`           | `{ status, clientId }`                                       |
| client → server    | `AUTH`            | `{ deviceId, role, token, name?, model?, androidVersion?, appVersion?, rejoin? }` |
| server → client    | `AUTH_OK`         | `{ deviceId, role, onlineDevices[], activeSessionId? }`      |
| server → client    | `AUTH_ERROR`      | `{ code, message }`                                          |
| client → server    | `SESSION_REJOIN`  | `{ sessionId, sessionToken }`                                |
| either → server    | `PING`            | `{ ts }`                                                     |
| server → client    | `PONG`            | `{ ts }`                                                     |
| server → client    | `ERROR`           | `{ code, message, refId? }`                                  |

### Pairing

| Sender  → Receiver | Type            | Payload                                              |
|--------------------|-----------------|------------------------------------------------------|
| agent → server     | `PAIR_REQUEST`  | `{ deviceId }`                                        |
| server → agent     | `PAIR_RESPONSE` | `{ deviceId, code, expiresAt, expiresIn }`           |
| server → agent     | `PAIR_APPROVAL` | `{ pairId, controllerDeviceId, controllerName, requestedAt }` |
| agent → server     | `PAIR_APPROVED` | `{ pairId }`                                         |
| agent → server     | `PAIR_DENIED`   | `{ pairId }`                                         |
| server → controller| `PAIR_APPROVED` | `{ pairId }`                                         |
| server → controller| `PAIR_DENIED`   | `{ pairId }`                                         |

### Sessions

| Sender  → Receiver | Type                 | Payload                                              |
|--------------------|----------------------|------------------------------------------------------|
| server → agent     | `SESSION_REQUEST`    | `{ sessionId, controllerDeviceId, controllerName, permissions[], requestedAt }` |
| agent → server     | `SESSION_ACCEPT`     | `{ sessionId, permissions[] }`                       |
| agent → server     | `SESSION_DENY`       | `{ sessionId, reason? }`                             |
| server → controller| `SESSION_ACCEPTED`   | `{ sessionId, permissions[], sessionToken, iceServers[] }` |
| server → controller| `SESSION_DENY`       | `{ sessionId, reason? }`                             |
| server → all       | `SESSION_ENDED`      | `{ sessionId, reason, endedBy }`                     |
| either → server    | `DISCONNECT`         | `{ sessionId, reason? }`                             |
| either → server    | `PERMISSION_UPDATE`  | `{ sessionId, permission, granted }`                 |

### WebRTC signaling (controller ⇄ agent, relayed by server)

| Type           | Payload                                                       |
|----------------|---------------------------------------------------------------|
| `OFFER`        | `{ sessionId, sdp }`                                          |
| `ANSWER`       | `{ sessionId, sdp }`                                          |
| `ICE_CANDIDATE`| `{ sessionId, candidate: { candidate, sdpMid, sdpMLineIndex } }` |

### Control

| Type             | Payload                                                                 |
|------------------|-------------------------------------------------------------------------|
| `TOUCH_EVENT`    | `{ sessionId, eventType, x, y, timestamp, screenWidth, screenHeight, action? }` (x/y are 0..1 normalized) |
| `CONTROL_EVENT`  | `{ sessionId, kind, value? }` — kind ∈ `NAV_BACK|NAV_HOME|NAV_RECENTS|TEXT_INPUT|CAMERA_ON|CAMERA_OFF|MIC_ON|MIC_OFF` |
| `CLIPBOARD_EVENT`| `{ sessionId, direction, text }` — direction ∈ `controller_to_agent|agent_to_controller` |

### File transfer

| Type            | Payload                                                   |
|-----------------|-----------------------------------------------------------|
| `FILE_REQUEST`  | `{ sessionId, transferId, fileName, fileSize, mimeType, sha256?, chunkSize? }` |
| `FILE_ACCEPT`   | `{ sessionId, transferId }`                               |
| `FILE_DECLINE`  | `{ sessionId, transferId, reason? }`                     |
| `FILE_PROGRESS` | `{ sessionId, transferId, transferred }`                  |
| `FILE_COMPLETE` | `{ sessionId, transferId, sha256? }`                     |

File **bytes** travel over the WebRTC `file` data channel as raw binary chunks
(64 KiB by default). The agent assembles chunks until it has `fileSize` bytes,
then optionally verifies the SHA-256.

## Permissions

Identifiers shared between controller, agent and server:

```
SCREEN, TOUCH, CAMERA, MICROPHONE, FILES, CLIPBOARD, DEVICE_INFO
```

The agent grants only the permissions it wants to expose; the server enforces a
permission guard per message type and rejects any control message the agent has
not granted.
