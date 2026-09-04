import { Contact } from './CallTypes';

export const CONTACTS: Contact[] = [
  { id: 'c1', name: 'Elif Demir',    handle: '@elifdemir',  color: '#7360F2', online: true },
  { id: 'c2', name: 'Mert Kaya',     handle: '@mertkaya',   color: '#E8734A', online: true },
  { id: 'c3', name: 'Zeynep Arslan', handle: '@zeyneparslan', color: '#2FAE8F', online: false },
  { id: 'c4', name: 'Baran Kurt',  handle: '@barankurt', color: '#C7417B', online: true }
];

export function initialsOf(name: string): string {
  const parts: string[] = name.trim().split(' ')
  if(parts.length === 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }

  return (parts[0].substring(0,1) + parts[parts.length - 1].substring(0,1).toUpperCase());
}

export function formatDuration(sec: number): string {
  const m: number = Math.floor(sec / 60);
  const s: number = sec % 60;
  const mm: string = m < 10 ? `0${m}` : `${m}`;
  const ss: string = s < 10 ? `0${s}` : `${s}`;
  return `${mm}:${ss}`;
}

export function formatClock(ts: number): string {
  const d: Date = new Date(ts);
  const h: number = d.getHours();
  const m: number = d.getMinutes();
  return `${h < 10 ? `0${h}` : `${h}`}:${m < 10 ? `0${m}` : `${m}`}`;
}