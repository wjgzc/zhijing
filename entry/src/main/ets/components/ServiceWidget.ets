import { switchTab } from '../utils/TabSwitch';

@Component
export struct ServiceWidget {
  @State task1Done: boolean = true;
  @State task2Done: boolean = false;
  @State task3Done: boolean = false;

  build() {
    Column() {
      // 页面头部
        this.PageHeader()

        // 卡片展示
        this.WidgetShowcase()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
      .padding(20)
  }

  @Builder
  PageHeader() {
    Column() {
      Text('🎴 服务卡片')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .width('100%')

      Text('添加到桌面，快速查看学习状态')
        .fontSize(14)
        .fontColor('#8E92A4')
        .width('100%')
        .margin({ top: 6, bottom: 24 })
    }
    .width('100%')
  }

  @Builder
  WidgetShowcase() {
    Scroll() {
      Column() {
        // 1×1 小卡片
        Text('1×1 快捷入口')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B7280')
          .width('100%')
          .margin({ bottom: 8 })

        this.WidgetSmall()

        // 2×2 中卡片
        Text('2×2 任务列表')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B7280')
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        this.WidgetMedium()

        // 4×2 大卡片
        Text('4×2 进度看板')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B7280')
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        this.WidgetLarge()

        Blank().height(100)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  // 1×1 小卡片
  @Builder
  WidgetSmall() {
    Column() {
      Stack() {
        Circle()
          .width(44)
          .height(44)
          .fill('rgba(255,255,255,0.2)')
        Text('🤖')
          .fontSize(22)
      }
      .width(44)
      .height(44)
      .margin({ bottom: 8 })

      Text('知径Agent')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)

      Text('点击快速对话')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.8)')
    }
    .width(160)
    .height(160)
    .padding(20)
    .linearGradient({
      angle: 135,
      colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
    })
    .borderRadius(24)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
    .shadow({
      radius: 12,
      color: '#254A90D9',
      offsetX: 0,
      offsetY: 6
    })
    .onClick(() => {
      switchTab(2)
    })
  }

  // 2×2 中卡片
  @Builder
  WidgetMedium() {
    Column() {
      Row() {
        Stack() {
          Circle()
            .width(36)
            .height(36)
            .linearGradient({
              angle: 135,
              colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
            })
          Text('📋')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .margin({ right: 10 })

        Text('今日学习任务')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column() {
        Column() {
          this.TaskItem('数组复习（已完成）', this.task1Done)
        }
        .width('100%')
        .onClick(() => { this.task1Done = !this.task1Done })

        Column() {
          this.TaskItem('链表插入操作练习', this.task2Done)
        }
        .width('100%')
        .onClick(() => { this.task2Done = !this.task2Done })

        Column() {
          this.TaskItem('链表删除操作练习', this.task3Done)
        }
        .width('100%')
        .onClick(() => { this.task3Done = !this.task3Done })
      }
      .width('100%')
    }
    .width(335)
    .height(160)
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  TaskItem(text: string, done: boolean) {
    Row() {
      Stack() {
        if (done) {
          Circle()
            .width(20)
            .height(20)
            .fill('#7ED321')
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White)
        } else {
          Circle()
            .width(20)
            .height(20)
            .fill(Color.White)
            .stroke('#E8E8E8')
            .strokeWidth(2)
        }
      }
      .width(20)
      .height(20)
      .margin({ right: 10 })

      Text(text)
        .fontSize(13)
        .fontColor(done ? '#8E92A4' : '#1A1A2E')
        .decoration({ type: done ? TextDecorationType.LineThrough : TextDecorationType.None })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  // 4×2 大卡片
  @Builder
  WidgetLarge() {
    Column() {
      Row() {
        Stack() {
          Circle()
            .width(36)
            .height(36)
            .linearGradient({
              angle: 135,
              colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
            })
          Text('📊')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .margin({ right: 10 })

        Text('学习进度看板')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.StatWidget('68%', '掌握度')
        this.StatWidget('12', '连续天')
        this.StatWidget('3', '今日任务')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      Row() {
        Button('🤖 问Agent')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
          .fontColor(Color.White)
          .onClick(() => {
            switchTab(2)
          })

        Button('📍 查看路径')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .backgroundColor('#F0F4F8')
          .fontColor('#4A90D9')
          .margin({ left: 10 })
          .onClick(() => {
            switchTab(3)
          })
      }
      .width('100%')
    }
    .width(335)
    .height(200)
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  StatWidget(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A90D9')

      Text(label)
        .fontSize(11)
        .fontColor('#8E92A4')
        .margin({ top: 4 })
    }
    .width('30%')
    .padding(12)
    .backgroundColor('#F7F9FC')
    .borderRadius(16)
  }
}