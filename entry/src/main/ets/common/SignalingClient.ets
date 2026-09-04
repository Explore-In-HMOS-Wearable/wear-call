import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = '[Signaling]';

export interface SignalMessage {
  t: string;
  id?: string;
  from?: string;
  to?: string;
  name?: string;
  reason?: string;
}

export class SignalingClient {
  private ws: webSocket.WebSocket | undefined = undefined;
  private connected: boolean = false;
  private myId: string = '';
  private myName: string = '';

  onSignal: (msg: SignalMessage) => void = () => {};
  onAudio: (frame: ArrayBuffer) => void = () => {};
  onStateChange: (connected: boolean) => void = () => {};

  connect(url: string, myId: string, myName: string): void {
    this.myId = myId;
    this.myName = myName;
    this.close();

    this.ws = webSocket.createWebSocket();

    this.ws.on('open', () => {
      this.connected = true;
      this.onStateChange(true);
      console.info(`${TAG} connected`);
      this.sendSignal({ t: 'hello', id: this.myId, name: this.myName });
    });

    this.ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        return;
      }
      if (typeof value === 'string') {
        try {
          this.onSignal(JSON.parse(value) as SignalMessage);
        } catch (e) {
          console.error(`${TAG} JSON Parse Fail`);
        }
      } else {
        this.onAudio(value);
      }
    });

    this.ws.on('close', () => {
      this.connected = false;
      this.onStateChange(false);
    });

    this.ws.on('error', (err: BusinessError) => {
      this.connected = false;
      this.onStateChange(false);
      console.error(`${TAG} Error: ${err.message}`);
    });

    this.ws.connect(url, (err: BusinessError) => {
      if (err) {
        console.error(`${TAG} Connect fail: ${err.message}`);
      }
    });
  }

  isConnected(): boolean {
    return this.connected;
  }

  sendSignal(msg: SignalMessage): void {
    if (this.ws === undefined || !this.connected) {
      return;
    }
    this.ws.send(JSON.stringify(msg)).catch((e: BusinessError) => {
      console.error(`${TAG} could not send: ${e.message}`);
    });
  }

  sendAudio(frame: ArrayBuffer): void {
    if (this.ws === undefined || !this.connected) {
      return;
    }
    this.ws.send(frame).catch(() => {});
  }

  close(): void {
    if (this.ws !== undefined) {
      this.ws.off('message');
      this.ws.off('open');
      this.ws.off('close');
      this.ws.off('error');
      this.ws.close().catch(() => {});
      this.ws = undefined;
    }
    this.connected = false;
  }
}