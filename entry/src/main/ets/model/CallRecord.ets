import { CallDirection } from './CallTypes';

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