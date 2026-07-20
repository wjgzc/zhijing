import { AppStateManager, StudyData } from '../model/StudyModel';
import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';

@Component
export struct Index {
  @State studyData: StudyData = AppStateManager.getStudyData();
  @State currentPathIndex: number = 0;
  @State masteryRate: number = 68;
  @State streakDays: number = 12;

  aboutToAppear(): void {
    this.studyData = AppStateManager.getStudyData();
  }

  onPageShow(): void {
    this.studyData = AppStateManager.getStudyData();
  }

  build() {
    Scroll() {
      Column() {
          // 顶部问候语
          this.HeaderSection()

          // Agent入口按钮
          this.AgentButton()

          // 今日学习路径
          this.TodayPathSection()

          // 学习概览统计
          this.StatsSection()

          // 底部留白
          Blank().height(100)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

  }

  // 顶部问候语
  @Builder
  HeaderSection() {
    Column() {
      Text('早上好，同学')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .width('90%')
        .textAlign(TextAlign.Start)

      Text('今天有3个知识点待探索，继续加油！')
        .fontSize(14)
        .fontColor('#8E92A4')
        .width('90%')
        .textAlign(TextAlign.Start)
        .margin({ top: 6 })
    }
    .width('100%')
    .margin({ top: 16, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  // Agent入口按钮
  @Builder
  AgentButton() {
    Button() {
      Row() {
        Text('问知径Agent')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ left: 10 })
      }
      .padding({ left: 16, right: 24 })
    }
    .width(220)
    .height(64)
    .linearGradient({
      angle: 135,
      colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
    })
    .borderRadius(32)
    .shadow({
      radius: 16,
      color: '#354A90D9',
      offsetX: 0,
      offsetY: 8
    })
    .onClick(() => {
      switchTab(2);
    })
    .margin({ top: 24, bottom: 24 })
  }

  // 今日学习路径
  @Builder
  TodayPathSection() {
    Column() {
      // 标题栏
      Row() {
        Text('今日学习路径')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')

        Text('查看全部 →')
          .fontSize(13)
          .fontColor('#4A90D9')
          .onClick(() => switchTab(3))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      // 路径节点
      Scroll() {
        Row() {
          this.PathNode('数组', true, false)
          this.PathArrow()
          this.PathNode('链表', false, true)
          this.PathArrow()
          this.PathNode('栈', false, false)
          this.PathArrow()
          this.PathNode('队列', false, false)
        }
        .padding({ left: 4, right: 4 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('90%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
    .margin({ bottom: 16 })
  }

  // 路径节点
  @Builder
  PathNode(name: string, isDone: boolean, isActive: boolean) {
    Column() {
      Text(name + (isDone ? ' ✅' : isActive ? ' 🔄' : ' ⏳'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(isDone || isActive ? Color.White : '#8E92A4')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    }
    .backgroundColor(
      isDone ? '#7ED321' :
        isActive ? '#F5A623' :
          Color.White
    )
    .borderRadius(14)
    .border({
      width: isDone || isActive ? 0 : 2,
      color: '#E8E8E8'
    })
    .shadow({
      radius: isActive ? 12 : 4,
      color: isActive ? '#35F5A623' : '#10000000',
      offsetX: 0,
      offsetY: isActive ? 4 : 2
    })
    .animation({
      duration: 2000,
      iterations: isActive ? -1 : 1,
      playMode: PlayMode.Alternate
    })
  }

  // 路径箭头
  @Builder
  PathArrow() {
    Text('→')
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#4A90D9')
      .margin({ left: 8, right: 8 })
  }

  // 学习概览统计
  @Builder
  StatsSection() {
    Column() {
      Row() {
        Text('学习概览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        // 掌握度
        this.StatCard('掌握度', this.masteryRate + '%', this.masteryRate)

        // 连续学习天数
        this.StatCard('连续学习天数', this.streakDays.toString(), 88)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('90%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 统计卡片
  @Builder
  StatCard(label: string, value: string, progress: number) {
    Column() {
      // 环形进度条（简化版）
      Stack() {
        Circle()
          .width(80)
          .height(80)
          .fill('none')
          .stroke('#E8E8E8')
          .strokeWidth(6)

        Circle()
          .width(80)
          .height(80)
          .fill('none')
          .stroke('#4A90D9')
          .strokeWidth(6)
          .strokeDashArray([progress * 2.51, 251]) // 周长约251
          .strokeLineCap(LineCapStyle.Round)
          .rotate({ angle: -90 })
      }
      .margin({ bottom: 8 })

      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A90D9')

      Text(label)
        .fontSize(12)
        .fontColor('#8E92A4')
        .margin({ top: 4 })
    }
    .width('48%')
    .padding(16)
    .backgroundColor('#F7F9FC')
    .borderRadius(16)
  }
}