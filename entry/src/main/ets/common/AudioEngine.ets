import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = '[AudioEngine]';

/** 16 kHz, mono, 16-bit. Both endpoints must speak the same format. */
const STREAM_INFO: audio.AudioStreamInfo = {
  samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
  channels: audio.AudioChannel.CHANNEL_1,
  sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
  encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
};

/**
 * Buffers incoming network packets and feeds them to the playback callback
 * in whatever size it asks for. Absorbs network jitter; drops the oldest
 * data when it overflows.
 */
class PcmQueue {
  private chunks: Uint8Array[] = [];
  private total: number = 0;
  /** ~0.6 s. Anything beyond this is heard as latency, not smoothness. */
  private readonly maxBytes: number = 19200;

  push(buf: ArrayBuffer): void {
    this.chunks.push(new Uint8Array(buf.slice(0)));
    this.total += buf.byteLength;
    while (this.total > this.maxBytes && this.chunks.length > 1) {
      const dropped: Uint8Array | undefined = this.chunks.shift();
      if (dropped !== undefined) {
        this.total -= dropped.length;
      }
    }
  }

  /** Fills dest; pads with silence when there is not enough data. */
  read(dest: Uint8Array): void {
    let offset: number = 0;
    while (offset < dest.length && this.chunks.length > 0) {
      const head: Uint8Array = this.chunks[0];
      const need: number = dest.length - offset;
      if (head.length <= need) {
        dest.set(head, offset);
        offset += head.length;
        this.total -= head.length;
        this.chunks.shift();
      } else {
        dest.set(head.subarray(0, need), offset);
        this.chunks[0] = head.subarray(need);
        this.total -= need;
        offset += need;
      }
    }
    if (offset < dest.length) {
      dest.fill(0, offset);
    }
  }

  clear(): void {
    this.chunks = [];
    this.total = 0;
  }
}

export class AudioEngine {
  private capturer: audio.AudioCapturer | undefined = undefined;
  private renderer: audio.AudioRenderer | undefined = undefined;
  private queue: PcmQueue = new PcmQueue();
  private muted: boolean = false;
  private running: boolean = false;

  onFrame: (frame: ArrayBuffer) => void = () => {};

  onInterrupted: () => void = () => {};

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
    this.queue.clear();
    try {
      await this.startRenderer();
      await this.startCapturer();
      console.info(`${TAG} audio chain opened`);
    } catch (err) {
      console.error(`${TAG} failed to start: ${(err as BusinessError).message}`);
      await this.stop();
      throw err as Error;
    }
  }

  private async startCapturer(): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: STREAM_INFO,
      capturerInfo: {
        // VOICE_COMMUNICATION enables the system echo cancellation chain.
        source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
        capturerFlags: 0
      }
    };
    this.capturer = await audio.createAudioCapturer(options);

    this.capturer.on('audioInterrupt', (event: audio.InterruptEvent) => {
      this.handleInterrupt(event);
    });

    this.capturer.on('inputDeviceChange', (deviceInfo: audio.AudioDeviceDescriptors) => {
        console.info(`${TAG} input device changed`);
    });

    this.capturer.on('readData', (buffer: ArrayBuffer) => {
      if (!this.muted && this.running) {
        // The buffer is reused — sending it without a copy corrupts the audio.
        this.onFrame(buffer.slice(0));
      }
    });

    await this.capturer.start();
  }

  private async startRenderer(): Promise<void> {
    const options: audio.AudioRendererOptions = {
      streamInfo: STREAM_INFO,
      rendererInfo: {
        usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION,
        rendererFlags: 0
      }
    };
    this.renderer = await audio.createAudioRenderer(options);

    this.renderer.on('audioInterrupt', (event: audio.InterruptEvent) => {
      this.handleInterrupt(event);
    });

    this.renderer.on('outputDeviceChangeWithInfo', () => {
      console.info(`${TAG} output device changed`);
    });

    this.renderer.on('writeData', (buffer: ArrayBuffer): audio.AudioDataCallbackResult => {
      this.queue.read(new Uint8Array(buffer));
      return audio.AudioDataCallbackResult.VALID;
    });

    await this.renderer.start();
  }

  private handleInterrupt(event: audio.InterruptEvent): void {
    if (event.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
      console.info(`${TAG} audio forcibly interrupted: ${event.hintType}`);
      this.onInterrupted();
    } else {
      console.info(`${TAG} interrupt hint received: ${event.hintType}`);
    }
  }

  pushRemote(frame: ArrayBuffer): void {
    if (this.running) {
      this.queue.push(frame);
    }
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
  }

  async stop(): Promise<void> {
    this.running = false;
    this.queue.clear();

    try {
      if (this.capturer !== undefined) {
        this.capturer.off('readData');
        this.capturer.off('audioInterrupt');
        this.capturer.off('inputDeviceChange');
        await this.capturer.stop();
        await this.capturer.release();
        this.capturer = undefined;
      }
    } catch (e) {
      console.error(`${TAG} failed to close capturer`);
    }

    try {
      if (this.renderer !== undefined) {
        this.renderer.off('writeData');
        this.renderer.off('audioInterrupt');
        this.renderer.off('outputDeviceChangeWithInfo');
        await this.renderer.stop();
        await this.renderer.release();
        this.renderer = undefined;
      }
    } catch (e) {
      console.error(`${TAG} failed to close renderer`);
    }
  }
}