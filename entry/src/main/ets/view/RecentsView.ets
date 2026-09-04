import { CallRecord, CallDirection, StoreKey } from '../model/CallTypes';
import { initialsOf, formatDuration, formatClock } from '../model/MockData';
import { CallManager } from '../common/CallManager';

@Component
export struct RecentsView {
  @StorageLink(StoreKey.RECORDS) records: CallRecord[] = [];
  private manager: CallManager = CallManager.get();

  private subtitle(r: CallRecord): string {
    const arrow: string = r.direction === CallDirection.IN ? '↙' : '↗';
    if (r.missed) {
      return `${arrow} Missed Call · ${formatClock(r.timestamp)}`;
    }
    return `${arrow} ${formatDuration(r.durationSec)} · ${formatClock(r.timestamp)}`;
  }

  @Builder
  row(r: CallRecord) {
    Row({ space: 14 }) {
      Stack() {
        Circle().width(46).height(46).fill(r.color)
        Text(initialsOf(r.name)).fontSize(16).fontColor(Color.White)
      }
      .width(46).height(46)

      Column({ space: 3 }) {
        Text(r.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(r.missed ? '#E5484D' : '#1C1B2E')
        Text(this.subtitle(r))
          .fontSize(13)
          .fontColor('#8A8798')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .onClick(() => {
      CallManager.get().startOutgoing({
        id: r.id, name: r.name, handle: r.handle, color: r.color, online: true
      });
    })
  }

  build() {
    if (this.records.length === 0) {
      Column({ space: 10 }) {
        Text('☎').fontSize(44).fontColor('#D6D2EC')
        Text('No call yet')
          .fontSize(15)
          .fontColor('#8A8798')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
    } else {
      List() {
        ForEach(this.records, (r: CallRecord) => {
          ListItem() {
            this.row(r)
          }
        }, (r: CallRecord) => r.id)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
      .scrollBar(BarState.Off)
    }
  }
}