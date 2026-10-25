import { AppState } from '../model/AppState';
import { switchTab } from '../utils/TabSwitch';

interface PlanItem {
  kc: number;
  name: string;
  done: boolean;
  mastery: number;
}

interface StatCardParams {
  label: string;
  value: string;
  progress: number;
}

@Component
export struct Index {
  @Prop @Watch('onActiveChange') isActive: boolean = true;
  @State questionCount: number = 0;
  @State overallMastery: number = 0;
  @State hasMastery: boolean = false;
  @State planItems: PlanItem[] = [];
  @State planDoneCount: number = 0;
  @StorageProp('appStateVersion') @Watch('refresh') stateVersion: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  private onActiveChange(): void {
    if (this.isActive) {
      this.refresh();
    }
  }

  private refresh(): void {
    const overview = AppState.getOverview();
    this.questionCount = overview.questionCount;
    this.overallMastery = overview.overallMastery;
    this.hasMastery = overview.hasMastery;
    this.planDoneCount = overview.doneTaskCount;
    const plan = AppState.getPlan();
    const items: PlanItem[] = [];
    for (let i = 0; i < plan.length; i++) {
      items.push({
        kc: plan[i].kc,
        name: plan[i].name,
        done: AppState.isDone(plan[i].kc),
        mastery: plan[i].mastery
      });
    }
    this.planItems = items;
  }

  build() {
    Scroll() {
      Column() {
        this.HeaderSection()
        this.AgentButton()
        this.TodayPathSection()
        this.StatsSection()
        Blank().height(24)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  HeaderSection() {
    Column() {
      Text('你好，同学')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('90%')
        .textAlign(TextAlign.Start)

      Text(this.questionCount > 0 ?
        `已完成 ${this.questionCount} 道题，继续练习巩固知识` :
        '去知识图谱做几道题，让学习助手 帮你规划学习吧')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('90%')
        .textAlign(TextAlign.Start)
        .margin({ top: 6 })
    }
    .width('100%')
    .margin({ top: 16, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  AgentButton() {
    Button() {
      Row() {
        Text('问学习助手')
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
      colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
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

  @Builder
  TodayPathSection() {
    Column() {
      Row() {
        Text('当前学习计划')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        if (this.planItems.length > 0) {
          Text('查看全部 →')
            .fontSize(13)
            .fontColor($r('app.color.brand'))
            .onClick(() => switchTab(3))
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      if (this.planItems.length === 0) {
        Text('暂无学习计划，去学习助手 生成一个吧')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ top: 8, bottom: 8 })
      } else {
        Text(`已完成 ${this.planDoneCount} / ${this.planItems.length}`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 10 })

        Scroll() {
          Row() {
            ForEach(this.planItems.slice(0, 8), (item: PlanItem, idx: number) => {
              if (idx > 0) {
                this.PathArrow()
              }
              Column() {
                Text(item.name + (item.done ? ' ✅' : ' ⏳'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }
              .backgroundColor(item.done ? $r('app.color.success') : $r('app.color.warning'))
              .borderRadius(14)
            }, (item: PlanItem, idx: number) => item.kc.toString() + '_' + (item.done ? '1' : '0'))
          }
          .padding({ left: 4, right: 4 })
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
    .margin({ bottom: 16 })
  }

  @Builder
  PathArrow() {
    Text('→')
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.brand'))
      .margin({ left: 8, right: 8 })
  }

  @Builder
  StatsSection() {
    Column() {
      Row() {
        Text('学习概览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        this.StatCard({
          label: AppState.isDsa() ? '预测答对率' : '综合掌握度',
          value: this.hasMastery ? this.overallMastery + '%' : '待诊断',
          progress: this.hasMastery ? this.overallMastery : 0
        })
        this.StatCard({
          label: '已做题目',
          value: this.questionCount + ' 道',
          progress: Math.min(this.questionCount, 100)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('90%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  StatCard(params: StatCardParams) {
    Column() {
      Progress({ value: params.progress, total: 100, type: ProgressType.Ring })
        .width(72).height(72)
        .color($r('app.color.brand')).backgroundColor($r('app.color.divider'))
        .style({ strokeWidth: 6, enableSmoothEffect: true })
        .accessibilityLevel('no')
        .margin({ bottom: 12 })

      Text(params.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand'))

      Text(params.label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('48%')
    .padding(16)
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(16)
    .accessibilityGroup(true)
    .accessibilityText(params.label + '，' + params.value)
  }
}
