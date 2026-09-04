import { audio } from '@kit.AudioKit';
import { CallStatus, CallDirection, Contact, CallRecord, StoreKey } from '../model/CallTypes';
import { CONTACTS } from '../model/MockData';
import { Config } from './Config';
import { SignalingClient, SignalMessage } from './SignalingClient';
import { AudioEngine } from './AudioEngine';

const TAG: string = '[CallManager]';

export class CallManager {
  private static instance: CallManager | undefined = undefined;

  private tickTimer: number = -1;
  private stageTimer: number = -1;
  private peer: Contact | null = null;
  private direction: CallDirection = CallDirection.OUT;
  private answered: boolean = false;
  private records: CallRecord[] = [];

  private signaling: SignalingClient = new SignalingClient();
  private engine: AudioEngine = new AudioEngine();

  static get(): CallManager {
    if (CallManager.instance === undefined) {
      CallManager.instance = new CallManager();
    }
    return CallManager.instance;
  }

  init(): void {
    AppStorage.setOrCreate<number>(StoreKey.STATUS, CallStatus.IDLE);
    AppStorage.setOrCreate<string>(StoreKey.PEER_NAME, '');
    AppStorage.setOrCreate<string>(StoreKey.PEER_HANDLE, '');
    AppStorage.setOrCreate<string>(StoreKey.PEER_COLOR, '#7360F2');
    AppStorage.setOrCreate<number>(StoreKey.DURATION, 0);
    AppStorage.setOrCreate<boolean>(StoreKey.MUTED, false);
    AppStorage.setOrCreate<boolean>(StoreKey.SPEAKER, false);
    AppStorage.setOrCreate<CallRecord[]>(StoreKey.RECORDS, []);
    AppStorage.setOrCreate<boolean>(StoreKey.LINKED, false);
    AppStorage.setOrCreate<string>(StoreKey.TOAST, '');

    if (Config.USE_NETWORK) {
      this.wireNetwork();
    }
  }

  private wireNetwork(): void {

    this.engine.onFrame = (frame: ArrayBuffer) => this.signaling.sendAudio(frame);
    this.signaling.onAudio = (frame: ArrayBuffer) => this.engine.pushRemote(frame);

    this.signaling.onStateChange = (connected: boolean) => {
      AppStorage.setOrCreate<boolean>(StoreKey.LINKED, connected);
      if (!connected && this.currentStatus() !== CallStatus.IDLE) {
        this.hangup();
      }
    };

    this.signaling.onSignal = (msg: SignalMessage) => this.handleSignal(msg);
    this.signaling.connect(Config.SERVER_URL, Config.MY_ID, Config.MY_NAME);
  }

  private handleSignal(msg: SignalMessage): void {
    switch (msg.t) {
      case 'welcome':
        console.info(`${TAG} registration to the server complete: ${msg.id}`);
        break;

      case 'invite':
        this.onRemoteInvite(msg);
        break;

      case 'ringing':
        break;

      case 'accept':
        if (this.currentStatus() === CallStatus.OUTGOING) {
          this.clearStageTimer();
          this.setStatus(CallStatus.CONNECTING);
          this.openMedia();
        }
        break;

      case 'reject':
      case 'bye':
        this.hangup();
        break;

      case 'unavailable':
        console.info(`${TAG} ulaşılamıyor: ${msg.reason}`);
        this.hangup();
        break;

      default:
        console.warn(`${TAG} bilinmeyen sinyal: ${msg.t}`);
    }
  }

  private onRemoteInvite(msg: SignalMessage): void {

    if (this.currentStatus() !== CallStatus.IDLE) {
      this.signaling.sendSignal({ t: 'reject' });
      return;
    }
    const fromId: string = msg.from ?? '';
    const known: Contact | undefined = CONTACTS.find((c: Contact) => c.id === fromId);
    const fallback: Contact = {
      id: fromId,
      name: msg.name ?? 'Unknown',
      handle: `@${fromId}`,
      color: '#7360F2',
      online: true
    };
    this.beginIncoming(known ?? fallback);
  }

  private openMedia(): void {
    this.engine.start().then(() => {
      this.engine.setMuted(AppStorage.get<boolean>(StoreKey.MUTED) ?? false);
      this.goActive();
    }).catch(() => {
      console.error(`${TAG} mikrofona erişilemedi`);
      this.hangup();
    });
  }

  startOutgoing(contact: Contact): void {
    if (this.currentStatus() !== CallStatus.IDLE) {
      return;
    }
    if (Config.USE_NETWORK && !this.signaling.isConnected()) {
      console.info(`${TAG} sunucuya bağlı değil`);
      return;
    }

    this.peer = contact;
    this.direction = CallDirection.OUT;
    this.answered = true;
    this.publishPeer(contact);
    AppStorage.setOrCreate<number>(StoreKey.DURATION, 0);
    this.setStatus(CallStatus.OUTGOING);
    console.info(`${TAG} Calling: ${contact.id}`);

    if (Config.USE_NETWORK) {
      this.signaling.sendSignal({ t: 'invite', to: contact.id, name: Config.MY_NAME });
      this.stageTimer = setTimeout(() => {
        if (this.currentStatus() === CallStatus.OUTGOING) {
          console.info(`${TAG} missing call`);
          this.hangup();
        }
      }, Config.RING_TIMEOUT_MS);
    } else {

      this.stageTimer = setTimeout(() => {
        if (this.currentStatus() === CallStatus.OUTGOING) {
          this.setStatus(CallStatus.CONNECTING);
          this.stageTimer = setTimeout(() => this.goActive(), 900);
        }
      }, 3000);
    }
  }

  simulateIncoming(contact: Contact): void {
    if (this.currentStatus() !== CallStatus.IDLE) {
      return;
    }
    if (Config.USE_NETWORK) {
      console.info(`${TAG} In network mode: call from another device`);
      return;
    }
    this.beginIncoming(contact);
    this.stageTimer = setTimeout(() => {
      if (this.currentStatus() === CallStatus.INCOMING) {
        this.hangup();
      }
    }, 25000);
  }

  accept(): void {
    if (this.currentStatus() !== CallStatus.INCOMING) {
      return;
    }
    this.clearStageTimer();
    this.answered = true;
    this.setStatus(CallStatus.CONNECTING);

    if (Config.USE_NETWORK) {
      this.signaling.sendSignal({ t: 'accept' });
      this.openMedia();
    } else {
      this.stageTimer = setTimeout(() => this.goActive(), 900);
    }
  }

  hangup(): void {
    const status: CallStatus = this.currentStatus();
    if (status === CallStatus.IDLE || status === CallStatus.ENDED) {
      return;
    }

    if (Config.USE_NETWORK) {
      this.signaling.sendSignal({ t: status === CallStatus.INCOMING ? 'reject' : 'bye' });
      this.engine.stop();
    }

    this.clearStageTimer();
    this.clearTickTimer();
    this.applySpeaker(false);

    const duration: number = AppStorage.get<number>(StoreKey.DURATION) ?? 0;
    const missed: boolean = this.direction === CallDirection.IN && !this.answered;
    this.saveRecord(duration, missed);

    this.setStatus(CallStatus.ENDED);
    console.info(`${TAG} Closed`);

    this.stageTimer = setTimeout(() => this.reset(), 1400);
  }

  toggleMute(): void {
    const next: boolean = !(AppStorage.get<boolean>(StoreKey.MUTED) ?? false);
    AppStorage.setOrCreate<boolean>(StoreKey.MUTED, next);
    this.engine.setMuted(next);
  }

  toggleSpeaker(): void {
    const next: boolean = !(AppStorage.get<boolean>(StoreKey.SPEAKER) ?? false);
    AppStorage.setOrCreate<boolean>(StoreKey.SPEAKER, next);
    this.applySpeaker(next);
  }

  clearRecords(): void {
    this.records = [];
    AppStorage.setOrCreate<CallRecord[]>(StoreKey.RECORDS, []);
  }

  private beginIncoming(c: Contact): void {
    this.peer = c;
    this.direction = CallDirection.IN;
    this.answered = false;
    this.publishPeer(c);
    AppStorage.setOrCreate<number>(StoreKey.DURATION, 0);
    this.setStatus(CallStatus.INCOMING);
    console.info(`${TAG} Incoming: ${c.id}`);
  }

  private currentStatus(): CallStatus {
    return AppStorage.get<number>(StoreKey.STATUS) ?? CallStatus.IDLE;
  }

  private setStatus(s: CallStatus): void {
    AppStorage.setOrCreate<number>(StoreKey.STATUS, s);
  }

  private publishPeer(c: Contact): void {
    AppStorage.setOrCreate<string>(StoreKey.PEER_NAME, c.name);
    AppStorage.setOrCreate<string>(StoreKey.PEER_HANDLE, c.handle);
    AppStorage.setOrCreate<string>(StoreKey.PEER_COLOR, c.color);
  }

  private goActive(): void {
    this.setStatus(CallStatus.ACTIVE);
    AppStorage.setOrCreate<number>(StoreKey.DURATION, 0);
    this.clearTickTimer();
    this.tickTimer = setInterval(() => {
      const d: number = AppStorage.get<number>(StoreKey.DURATION) ?? 0;
      AppStorage.setOrCreate<number>(StoreKey.DURATION, d + 1);
    }, 1000);
  }

  private reset(): void {
    this.peer = null;
    this.answered = false;
    AppStorage.setOrCreate<number>(StoreKey.DURATION, 0);
    AppStorage.setOrCreate<string>(StoreKey.PEER_NAME, '');
    AppStorage.setOrCreate<string>(StoreKey.PEER_HANDLE, '');
    this.setStatus(CallStatus.IDLE);
  }

  private saveRecord(durationSec: number, missed: boolean): void {
    if (this.peer === null) {
      return;
    }
    const rec: CallRecord = {
      id: `r${Date.now()}`,
      name: this.peer.name,
      handle: this.peer.handle,
      color: this.peer.color,
      direction: this.direction,
      missed: missed,
      durationSec: durationSec,
      timestamp: Date.now()
    };

    this.records = [rec].concat(this.records);
    AppStorage.setOrCreate<CallRecord[]>(StoreKey.RECORDS, this.records);
  }

  private applySpeaker(on: boolean): void {
    try {
      const routing: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
      routing.setCommunicationDevice(audio.CommunicationDeviceType.SPEAKER, on)
        .catch(() => console.error(`${TAG} speakers could not set`));
    } catch (e) {
      console.error(`${TAG} audio routing error`);
    }
  }

  private clearTickTimer(): void {
    if (this.tickTimer !== -1) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }
  }

  private clearStageTimer(): void {
    if (this.stageTimer !== -1) {
      clearTimeout(this.stageTimer);
      this.stageTimer = -1;
    }
  }
}