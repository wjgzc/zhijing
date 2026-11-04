import { AdaptiveLayout } from '../utils/AdaptiveLayout';
import { AppState, CompletedPlan, WeakKc, TaskQuestion } from '../model/AppState';
import { switchTab, openPractice, requestReplan } from '../utils/TabSwitch';
import { PracticeService } from '../services/PracticeService';
import { cancelCurrentPlan } from '../utils/PlanActions';

interface PathStage {
  dayRange: string;
  title: string;
  status: 'done' | 'active' | 'pending';
  mastery: number;
  diagnosed: boolean;
  description: string;
  kc: number;
  questions: TaskQuestion[];
  answeredCount: number;
  loadingFailed: boolean;
}

@Component
export struct LearningPath {
  @StorageProp('contentWidth') contentWidth: number = 0;
  private courseEpoch: number = AppState.getCourseEpoch();
  @State stages: PathStage[] = [];
  @State doneCount: number = 0;
  @State planTitle: string = '';
  @State completedPlans: CompletedPlan[] = [];
  @State completedExpanded: boolean = false;
  @State expandedPlanIds: number[] = [];
  @StorageProp('appStateVersion') @Watch('refresh') stateVersion: number = 0;
  private requestedQuestions: Set<string> = new Set<string>();
  private failedQuestions: Set<string> = new Set<string>();

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.courseEpoch !== AppState.getCourseEpoch()) { return; }
    this.doneCount = AppState.doneCount();
    this.planTitle = AppState.getPlanTitle();
    this.completedPlans = AppState.getCompletedPlans();
    const plan = AppState.getPlan();
    const planId = AppState.getActivePlanId();
    const arr: PathStage[] = [];
    let firstActive = -1;
    for (let i = 0; i < plan.length; i++) {
      if (!AppState.isDone(plan[i].kc)) {
        firstActive = i;
        break;
      }
    }
    for (let i = 0; i < plan.length; i++) {
      const w = plan[i];
      const done = AppState.isDone(w.kc);
      const diagnosed = AppState.hasMastery();
      const mastery = diagnosed ? Math.round(AppState.getMastery(w.kc) * 100) : 0;
      const questions = AppState.getTaskQuestions(w.kc);
      let status: 'done' | 'active' | 'pending' = 'pending';
      if (done) {
        status = 'done';
      } else if (i === firstActive) {
        status = 'active';
      }
      arr.push({
        dayRange: '第 ' + (i + 1) + ' 步',
        title: w.name,
        status: status,
        mastery: mastery,
        diagnosed: diagnosed,
        description: diagnosed ? (AppState.isDsa() ? '预测答对率 ' : '掌握度 ') + mastery + '%' : '待诊断',
        kc: w.kc,
        questions: questions,
        answeredCount: questions.filter((question: TaskQuestion) => question.answered).length,
        loadingFailed: this.failedQuestions.has(planId.toString() + ':' + w.kc.toString())
      });
    }
    this.stages = arr;
    for (const item of plan) {
      const key = planId.toString() + ':' + item.kc.toString();
      if (AppState.getTaskQuestions(item.kc).length === 0 && !this.requestedQuestions.has(key)) {
        this.requestedQuestions.add(key);
        PracticeService.getQuestions(item.kc, planId).catch((error: Error) => {
          console.error('[LearningPath] 加载任务题目失败:', error.message);
          this.failedQuestions.add(key);
          this.refresh();
        });
      }
    }
  }

  private focusGraph(kc: number): void {
    AppStorage.setOrCreate('focusKcId', kc);
    const seq = (AppStorage.get<number>('focusSeq') ?? 0) + 1;
    AppStorage.setOrCreate('focusSeq', seq);
    switchTab(1);
  }

  build() {
    Column() {
      this.PageHeader()
      this.Timeline()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  PageHeader() {
    Row() {
      Column() {
        Text('我的学习路径')
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.stages.length > 0 ?
          `已完成 ${this.doneCount} / ${this.stages.length} 个知识点` :
          '暂无进行中的路径，可去学习助手 接受新的学习建议')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
    }
    .width('90%')
    .height(72)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  Timeline() {
    Scroll() {
      Column() {
        Flex({ direction: AdaptiveLayout.split(this.contentWidth) ? FlexDirection.Row : FlexDirection.Column,
          justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
        Column() {
        Text('正在进行')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 12 })
        if (this.stages.length === 0) {
          Text('暂无正在进行的路径\n去学习助手 接受学习建议，开始新的学习路径。')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(22)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
            .margin({ bottom: 20 })
            .onClick(() => switchTab(2))
          Button('让学习助手 生成新路径')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.brand_solid'))
            .height(40)
            .width('100%')
            .margin({ bottom: 20 })
            .onClick(() => requestReplan())
        } else {
          Text(this.planTitle)
            .fontSize(14)
            .fontColor($r('app.color.brand'))
            .margin({ bottom: 12 })
          Row({ space: 10 }) {
            Button('取消当前路径')
              .fontSize(13)
              .fontColor($r('app.color.danger'))
              .backgroundColor($r('app.color.danger_tint'))
              .layoutWeight(1)
              .height(36)
              .onClick(() => cancelCurrentPlan())
            Button('重新规划')
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand_solid'))
              .layoutWeight(1)
              .height(36)
              .onClick(() => cancelCurrentPlan(true))
          }
          .width('100%')
          .margin({ bottom: 16 })
          ForEach(this.stages, (stage: PathStage, index: number) => {
            this.TimelineItem(stage, index)
          }, (stage: PathStage) => stage.kc.toString() + '_' + stage.status + '_' +
            stage.mastery.toString() + '_' + stage.diagnosed.toString() + '_' +
            stage.questions.length.toString() + '_' + stage.answeredCount.toString() + '_' +
            stage.loadingFailed.toString())
        }
        }.width(AdaptiveLayout.split(this.contentWidth) ? '60%' : '100%')
          .alignItems(HorizontalAlign.Start)
        Column() {
          this.CompletedSection()
        }.width(AdaptiveLayout.split(this.contentWidth) ? '36%' : '100%')
        }.width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 1440 })
      .padding({ left: 24, right: 24, top: 8, bottom: this.contentWidth >= 600 ? 32 : 100 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
  }

  private toggleCompletedPlan(id: number): void {
    if (this.expandedPlanIds.includes(id)) {
      this.expandedPlanIds = this.expandedPlanIds.filter((value: number) => value !== id);
    } else {
      this.expandedPlanIds = this.expandedPlanIds.concat([id]);
    }
  }

  @Builder
  CompletedSection() {
    Column() {
      Row() {
        Text(`已完成（${this.completedPlans.length} 条路径）`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.completedExpanded ? '收起 ↑' : '展开 ↓')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .onClick(() => { this.completedExpanded = !this.completedExpanded; })

      if (this.completedExpanded) {
        if (this.completedPlans.length === 0) {
          Text('暂无已完成路径')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .padding({ bottom: 16 })
        } else {
          ForEach(this.completedPlans, (plan: CompletedPlan) => {
            this.CompletedPlanCard(plan)
          }, (plan: CompletedPlan) => plan.id.toString())
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CompletedPlanCard(plan: CompletedPlan) {
    Column() {
      Row() {
        Column() {
          Text(plan.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(`已完成 ${plan.items.length} 个知识点的练习`)
            .fontSize(12)
            .fontColor($r('app.color.success'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.expandedPlanIds.includes(plan.id) ? '收起 ↑' : '展开 ↓')
          .fontSize(12)
          .fontColor($r('app.color.brand'))
      }
      .width('100%')
      .onClick(() => this.toggleCompletedPlan(plan.id))

      if (this.expandedPlanIds.includes(plan.id)) {
        ForEach(plan.items, (item: WeakKc) => {
          Row() {
            Text('✓')
              .fontColor($r('app.color.success'))
              .margin({ right: 10 })
            Text(item.name)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Text(plan.diagnosed ? Math.round(item.mastery * 100) + '%' : '待诊断')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 12, bottom: 8 })
          .onClick(() => this.focusGraph(item.kc))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(plan.questions.filter((question: TaskQuestion) => question.kc === item.kc),
              (question: TaskQuestion) => {
                Text('题号 ' + question.qid + ' ✓')
                  .fontSize(12)
                  .fontColor($r('app.color.brand'))
                  .padding(8)
                  .onClick(() => openPractice(item.kc, question.qid))
              }, (question: TaskQuestion) => question.qid.toString())
          }
          .width('100%')
        }, (item: WeakKc) => item.kc.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .margin({ bottom: 12 })
  }

  @Builder
  TimelineItem(stage: PathStage, index: number) {
    Row() {
      Column() {
        Stack() {
          Circle()
            .width(20)
            .height(20)
            .fill(
              stage.status === 'done' ? $r('app.color.success') :
                stage.status === 'active' ? $r('app.color.warning') :
                  Color.White
            )
            .stroke(
              stage.status === 'pending' ? $r('app.color.divider') :
                stage.status === 'active' ? $r('app.color.warning') :
                  $r('app.color.success')
            )
            .strokeWidth(3)

          if (stage.status === 'active') {
            Circle()
              .width(20)
              .height(20)
              .fill('none')
              .stroke($r('app.color.warning'))
              .strokeWidth(1)
              .scale({ x: 1.5, y: 1.5 })
              .opacity(0.3)
              .animation({
                duration: 2000,
                iterations: -1,
                playMode: PlayMode.Alternate
              })
          }
        }
        .width(20)
        .height(20)

        if (index < this.stages.length - 1) {
          Column()
            .width(3)
            .height(60)
            .linearGradient({
              angle: 180,
              colors: [
                [stage.status === 'done' ? $r('app.color.success') : $r('app.color.divider'), 0],
                [this.stages[index + 1].status !== 'pending' ? $r('app.color.success') : $r('app.color.divider'), 1]
              ]
            })
            .margin({ top: 4 })
        }
      }
      .width(30)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Row() {
          Text(stage.dayRange)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.brand_tint'))
            .borderRadius(10)

          Text(
            stage.status === 'done' ? '已完成任务' :
              stage.status === 'active' ? '建议优先' :
                '待提升'
          )
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(
              stage.status === 'done' ? $r('app.color.success') :
                stage.status === 'active' ? $r('app.color.warning') :
                  $r('app.color.text_secondary')
            )
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 12 })

        Row() {
          Column() {
            Text(stage.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text(stage.description)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .onClick(() => this.focusGraph(stage.kc))

        if (stage.diagnosed) {
          Column() {
            Row() {
              Text(stage.mastery + '%')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Blank()
            }
            .width('100%')
            .margin({ bottom: 4 })

            Progress({ value: stage.mastery, total: 100, type: ProgressType.Linear })
              .width('100%').color($r('app.color.brand'))
              .backgroundColor($r('app.color.divider'))
              .style({ strokeWidth: 6, enableSmoothEffect: true })
              .accessibilityText(stage.description)
          }
          .width('100%')
          .margin({ top: 12 })
        }

        if (stage.status !== 'done') {
          Button('去做题 →')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
            .height(40)
            .borderRadius(14)
            .backgroundColor($r('app.color.brand_solid'))
            .margin({ top: 12 })
            .onClick(() => {
              openPractice(stage.kc);
            })
        }

        if (stage.questions.length > 0) {
          Text(`练习进度 ${stage.answeredCount} / ${stage.questions.length} 题`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 12 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(stage.questions, (question: TaskQuestion) => {
              Text('题号 ' + question.qid + (question.answered ? ' ✓' : ' →'))
                .fontSize(12)
                .fontColor(question.answered ? $r('app.color.success') : $r('app.color.brand'))
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor($r('app.color.brand_tint'))
                .borderRadius(10)
                .margin({ right: 8, top: 8 })
                .onClick(() => openPractice(stage.kc, question.qid))
            }, (question: TaskQuestion) => question.qid.toString())
          }
          .width('100%')
        } else {
          Text(stage.loadingFailed ? '题目加载失败，点击「去做题」重试' : '正在加载任务题目…')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 12 })
        }
      }
      .layoutWeight(1)
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(20)
      .shadow({
        radius: 8,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
      .margin({ left: 12, bottom: 16 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
