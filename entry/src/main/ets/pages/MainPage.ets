import { setTabsController } from '../utils/TabSwitch';
import { Index } from '../components/Index';
import { KnowledgeGraph } from '../components/KnowledgeGraph';
import { AgentChat } from '../components/AgentChat';
import { LearningPath } from '../components/LearningPath';
import { ServiceWidget } from '../components/ServiceWidget';

@Entry
@Component
struct MainPage {
  private tabsController: TabsController = new TabsController();
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    setTabsController(this.tabsController);
  }

  build() {
    Column() {
      Tabs({ index: this.currentIndex, controller: this.tabsController }) {
        TabContent() {
          Index()
        }

        TabContent() {
          KnowledgeGraph()
        }

        TabContent() {
          AgentChat()
        }

        TabContent() {
          LearningPath()
        }

        TabContent() {
          ServiceWidget()
        }
      }
      .barHeight(0)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentIndex = index;
      })

      // 底部导航
      Row() {
        this.NavItem('🏠', '首页', 0)
        this.NavItem('🗺️', '图谱', 1)
        this.NavItem('🤖', 'Agent', 2)
        this.NavItem('📍', '路径', 3)
        this.NavItem('👤', '我的', 4)
      }
      .width('100%')
      .height(68)
      .padding({ bottom: 8 })
      .backgroundColor(Color.White)
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
      .shadow({
        radius: 8,
        color: '#10000000',
        offsetX: 0,
        offsetY: -2
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  NavItem(icon: string, label: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(22)
        .margin({ bottom: 2 })

      Text(label)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? '#4A90D9' : '#8E92A4')
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width(60)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
      this.tabsController.changeIndex(index);
    })
  }
}
