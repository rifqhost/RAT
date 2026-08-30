export type Role = 'controller' | 'agent';
export type PairStatus = 'pending' | 'approved' | 'revoked';
export type SessionStatus = 'requested' | 'active' | 'ended';
export type SessionEndReason =
  | 'controller_disconnect'
  | 'agent_disconnect'
  | 'controller_stop'
  | 'agent_stop'
  | 'permission_revoked'
  | 'agent_offline'
  | 'expired'
  | 'error';

export type Permission =
  | 'SCREEN'
  | 'TOUCH'
  | 'CAMERA'
  | 'MICROPHONE'
  | 'FILES'
  | 'CLIPBOARD'
  | 'DEVICE_INFO';

export type SessionMessageType =
  | 'AUTH'
  | 'AUTH_OK'
  | 'AUTH_ERROR'
  | 'ERROR'
  | 'HELLO'
  | 'PAIR_REQUEST'
  | 'PAIR_RESPONSE'
  | 'PAIR_APPROVAL'
  | 'PAIR_APPROVED'
  | 'PAIR_DENIED'
  | 'SESSION_REQUEST'
  | 'SESSION_ACCEPT'
  | 'SESSION_DENY'
  | 'SESSION_ACCEPTED'
  | 'SESSION_REJOIN'
  | 'SESSION_ENDED'
  | 'OFFER'
  | 'ANSWER'
  | 'ICE_CANDIDATE'
  | 'TOUCH_EVENT'
  | 'CONTROL_EVENT'
  | 'FILE_REQUEST'
  | 'FILE_ACCEPT'
  | 'FILE_DECLINE'
  | 'FILE_PROGRESS'
  | 'FILE_COMPLETE'
  | 'CLIPBOARD_EVENT'
  | 'PERMISSION_UPDATE'
  | 'DISCONNECT'
  | 'PING'
  | 'PONG';

export interface User {
  id: string;
  name: string;
  email: string;
  passSalt: string;
  passHash: string;
  createdAt: string;
}

export interface Device {
  id: string;
  role: Role;
  userId: string;
  name: string;
  model?: string;
  androidVersion?: string;
  appVersion?: string;
  createdAt: string;
  lastSeenAt: string;
  online: boolean;
  wsClientId?: string;
}

export interface Pair {
  id: string;
  controllerDeviceId: string;
  agentDeviceId: string;
  status: PairStatus;
  createdAt: string;
  approvedAt?: string;
  revokedAt?: string;
  autoApprove?: boolean;
}

export interface PairingCode {
  id: string;
  deviceId: string;
  codeHash: string;
  createdAt: string;
  expiresAt: string;
  used: boolean;
}

export interface Session {
  id: string;
  controllerDeviceId: string;
  agentDeviceId: string;
  status: SessionStatus;
  permissions: Permission[];
  createdAt: string;
  startedAt?: string;
  endedAt?: string;
  endedReason?: SessionEndReason;
  lastActivityAt: string;
  controllerWsId?: string;
  agentWsId?: string;
}

export interface AuditLog {
  id: string;
  ts: string;
  event: string;
  actor: string;
  details: string;
}

export interface Envelope<T = unknown> {
  id: string;
  type: SessionMessageType;
  payload: T;
  ts: number;
}