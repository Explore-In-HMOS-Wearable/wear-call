import { Contact } from '../model/CallTypes';
import { CONTACTS, initialsOf } from '../model/MockData';
import { CallManager } from '../common/CallManager';

@Component
export struct ContactsView {

  @Builder
  row(c: Contact) {
    Row({ space: 14 }) {
      // Avatar: Initials
      Stack() {
        Circle().width(48).height(48).fill(c.color)
        Text(initialsOf(c.name))
          .fontSize(17)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
        if (c.online) {
          Circle()
            .width(13).height(13)
            .fill('#2FAE8F')
            .stroke('#FFFFFF')
            .strokeWidth(2)
            .position({ x: 36, y: 36 })
        }
      }
      .width(48).height(48)

      Column({ space: 3 }) {
        Text(c.name)
          .fontSize(16)
          .fontColor('#1C1B2E')
          .fontWeight(FontWeight.Medium)
        Text(c.online ? 'Online' : c.handle)
          .fontSize(13)
          .fontColor(c.online ? '#2FAE8F' : '#8A8798')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('📞')
        .fontSize(20)
        .padding(10)
        .backgroundColor('#F1EFFC')
        .borderRadius(20)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .onClick(() => {
      console.info(`[ContactsView] Clicked: ${c.id}`);
      this.manager.startOutgoing(c);
    })
  }

  private manager: CallManager = CallManager.get();

  build() {

    List() {
      ForEach(CONTACTS, (c: Contact) => {
        ListItem() {
          this.row(c)
        }
      }, (c: Contact) => c.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .scrollBar(BarState.Off)
  }
}