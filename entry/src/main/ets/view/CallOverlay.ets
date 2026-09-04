import { CallStatus, StoreKey } from '../model/CallTypes';
import { initialsOf, formatDuration } from '../model/MockData';
import { CallManager } from '../common/CallManager';

@Component
struct RoundButton {
  symbol: Resource = $r('sys.symbol.phone_down_fill');
  bg: ResourceColor = '#FFFFFF29';
  fg: ResourceColor = Color.White;
  size_: number = 52;
  onTap: () => void = () => {};

  build() {
    Stack() {
      Circle().width(this.size_).height(this.size_).fill(this.bg)
      SymbolGlyph(this.symbol)
        .fontSize(this.size_ * 0.42)
        .fontColor([this.fg])
    }
    .width(this.size_)
    .height(this.size_)
    .onClick(() => this.onTap())
  }
}

@Component
export struct CallOverlay {
  @StorageLink(StoreKey.STATUS) status: number = CallStatus.IDLE;
  @StorageLink(StoreKey.PEER_NAME) peerName: string = '';
  @StorageLink(StoreKey.PEER_HANDLE) peerHandle: string = '';
  @StorageLink(StoreKey.PEER_COLOR) peerColor: string = '#7360F2';
  @StorageLink(StoreKey.DURATION) duration: number = 0;
  @StorageLink(StoreKey.MUTED) muted: boolean = false;
  @StorageLink(StoreKey.SPEAKER) speaker: boolean = false;

  private manager: CallManager = CallManager.get();

  private statusText(): string {
    if (this.status === CallStatus.OUTGOING) {
      return 'Calling…';
    }
    if (this.status === CallStatus.CONNECTING) {
      return 'Connecting…';
    }
    if (this.status === CallStatus.ACTIVE) {
      return formatDuration(this.duration);
    }
    if(this.status === CallStatus.INCOMING) {
      return 'Incoming call';
    }
    return 'Call ended';
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Stack() {
          Circle()
            .width(80).height(80)
            .fill(this.peerColor)
            .shadow({ radius: 24, color: '#00000055', offsetY: 6 })
          Text(initialsOf(this.peerName))
            .fontSize(34)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .backgroundColor(Color.Transparent)
        .width(96).height(96)

        Text(this.peerName)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.statusText())
          .fontSize(12)
          .fontColor('#FFFFFFB3')
      }
      .margin({ top: 4 })

      Blank()

      if (this.status === CallStatus.ACTIVE || this.status === CallStatus.CONNECTING) {
        Row({ space: 20 }) {
          RoundButton({
            symbol: this.muted ? $r('sys.symbol.mic_slash_fill') : $r('sys.symbol.mic_fill'),
            bg: this.muted ? '#FFFFFFE6' : '#FFFFFF29',
            fg: this.muted ? '#1C1B2E' : Color.White,
            size_: 40,
            onTap: () => this.manager.toggleMute()
          })
          RoundButton({
            symbol: $r('sys.symbol.phone_down_fill'),
            bg: '#E5484D',
            size_: 40,
            onTap: () => this.manager.hangup()
          })
          RoundButton({
            symbol: $r('sys.symbol.speaker_wave_2_fill'),
            bg: this.speaker ? '#FFFFFFE6' : '#FFFFFF29',
            fg: this.speaker ? '#1C1B2E' : Color.White,
            size_: 40,
            onTap: () => this.manager.toggleSpeaker()
          })
        }
      } else if(this.status === CallStatus.INCOMING) {
        Row({space: 20}) {
          RoundButton({
            symbol: $r('sys.symbol.phone_down_fill'),
            bg: '#E5484D',
            size_: 60,
            onTap: () => this.manager.hangup()
          })
          RoundButton({
            symbol: $r('sys.symbol.phone_fill'),
            bg: '#2FAE8F',
            size_: 60,
            onTap: () => this.manager.accept()
          })
        }
      } else if (this.status !== CallStatus.ENDED) {
        RoundButton({
          symbol: $r('sys.symbol.phone_down_fill'),
          bg: '#E5484D',
          size_: 40,
          onTap: () => this.manager.hangup()
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 40, right: 40, bottom: 36 })
    .alignItems(HorizontalAlign.Center)
    .linearGradient({
      angle: 160,
      colors: [['#2B2350', 0.0], ['#4B3AA8', 0.55], ['#7360F2', 1.0]]
    })
  }
}