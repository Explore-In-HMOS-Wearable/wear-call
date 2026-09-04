import { CallManager } from '../common/CallManager';
import { ContactsView } from '../view/ContactsView';
import { RecentsView } from '../view/RecentsView';
import { CallOverlay } from '../view/CallOverlay';
import { CallStatus, StoreKey } from '../model/CallTypes';
import { common } from '@kit.AbilityKit';
import { requestCallPermissions } from '../common/Permissions';

@Entry
@Component
struct Index {
  @StorageLink(StoreKey.STATUS) callStatus: number = CallStatus.IDLE;
  @StorageLink(StoreKey.LINKED) linked: boolean = false;
  @State pageIndex: number = 0;

  aboutToAppear(): void {
    CallManager.get().init();
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    requestCallPermissions(ctx);
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 6 }) {
          Circle()
            .width(7)
            .height(7)
            .fill(this.linked ? '#2FAE8F' : '#E5484D')

          Text(this.pageIndex === 0 ? 'Contacts' : 'Calls')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C1B2E')
        }
        .padding({ top: 14, bottom: 8 })

        Swiper() {
          ContactsView()
          RecentsView()
        }
        .layoutWeight(1)
        .loop(false)
        .indicator(true)
        .onChange((index: number) => {
          this.pageIndex = index;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

      if (this.callStatus !== CallStatus.IDLE) {
        CallOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}