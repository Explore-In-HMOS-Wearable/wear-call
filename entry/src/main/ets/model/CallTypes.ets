export enum CallStatus {
  IDLE = 0,
  OUTGOING = 1,
  INCOMING = 2,
  CONNECTING = 3,
  ACTIVE = 4,
  ENDED = 5
}

export enum CallDirection {
  IN = 0,
  OUT = 1
}

export interface Contact {
  id: string;
  name: string;
  handle: string;
  color: string;
  online: boolean;
}

export class StoreKey {
  static readonly STATUS: string = 'call_status';
  static readonly PEER_NAME: string = 'call_peer_name';
  static readonly PEER_HANDLE: string = 'call_peer_handle';
  static readonly PEER_COLOR: string = 'call_peer_color';
  static readonly DURATION: string = 'call_duration';
  static readonly MUTED: string = 'call_muted';
  static readonly SPEAKER: string = 'call_speaker';
  static readonly TOAST: string = 'call_toast';
  static readonly RECORDS: string = 'call_records';
  static readonly LINKED: string = 'call_linked';
}

export interface CallRecord {
  id: string;
  name: string;
  handle: string;
  color: string;
  direction: CallDirection;
  missed: boolean;
  durationSec: number;
  timestamp: number;
}