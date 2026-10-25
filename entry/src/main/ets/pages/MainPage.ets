import { AppState } from '../model/AppState';
import { setTabsController, openPractice } from '../utils/TabSwitch';
import { Index } from '../components/Index';
import { KnowledgeGraph } from '../components/KnowledgeGraph';
import { AgentChat } from '../components/AgentChat';
import { LearningPath } from '../components/LearningPath';
import { ServiceWidget } from '../components/ServiceWidget';
import { StudyWidgetSync } from '../widget/StudyWidgetSync';
import { WidgetLaunchRequest } from '../widget/WidgetLaunch';

@Entry
@Component
struct MainPage {
  private tabsController: TabsController = new TabsController();
  @State currentIndex: number = 0;
  @State courseChosen: boolean = false;
  @State activeCourse: string = "math";
  @StorageProp('widgetLaunchSeq') @Watch('consumeWidgetLaunch') widgetLaunchSeq: number = 0;
  private pendingWidgetKc: number = -1;

  aboutToAppear(): void {
    AppState.initializeStorage();
    setTabsController(this.tabsController);
    const context = this.getUIContext().getHostContext();
    if (context) { StudyWidgetSync.start(context.filesDir); }
    this.consumeWidgetLaunch();
  }

  build() {
    if (!this.courseChosen) {
      this.CourseChoice()
    } else {
    Column() {
      Row() {
        Image($r('app.media.zhijing_start')).width(28).height(28).borderRadius(7)
          .accessibilityLevel('no')
        Text(AppState.courseName()).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary')).margin({ left: 10 }).layoutWeight(1)
        Blank()
        Button('切换课程', { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
          .fontSize(13).constraintSize({ minHeight: 44 })
          .fontColor($r('app.color.brand')).onClick(() => { this.courseChosen = false; })
          .accessibilityDescription('返回课程选择，两门课程的学习记录分别保存')
      }.width('90%').constraintSize({ maxWidth: 840 }).padding({ top: 4, bottom: 4 })
      ForEach([this.activeCourse], (course: string) => {
      Tabs({ index: this.currentIndex, controller: this.tabsController, barPosition: BarPosition.End }) {
        TabContent() {
          Index({ isActive: this.currentIndex === 0 })
        }
        .tabBar(BottomTabBarStyle.of($r('app.media.ic_home'), '首页')
          .iconStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary'), font: { size: 11 } }))

        TabContent() {
          KnowledgeGraph()
        }
        .tabBar(BottomTabBarStyle.of($r('app.media.ic_graph'), '图谱')
          .iconStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary'), font: { size: 11 } }))

        TabContent() {
          AgentChat()
        }
        .tabBar(BottomTabBarStyle.of($r('app.media.ic_message'), '助手')
          .iconStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary'), font: { size: 11 } }))

        TabContent() {
          LearningPath()
        }
        .tabBar(BottomTabBarStyle.of($r('app.media.ic_path'), '路径')
          .iconStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary'), font: { size: 11 } }))

        TabContent() {
          ServiceWidget()
        }
        .tabBar(BottomTabBarStyle.of($r('app.media.ic_profile'), '我的')
          .iconStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary') })
          .labelStyle({ selectedColor: $r('app.color.brand'), unselectedColor: $r('app.color.text_secondary'), font: { size: 11 } }))
      }
      .barMode(BarMode.Fixed)
      .barHeight(64)
      .barBackgroundColor($r('app.color.surface'))
      .barBackgroundBlurStyle(BlurStyle.Thin)
      .animationDuration(200)
      .layoutWeight(1)
      .onAppear(() => {
        this.tabsController.changeIndex(this.currentIndex);
        this.applyPendingWidgetPractice();
      })
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      }, (course: string) => course)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
      }
  }

  private chooseCourse(course: string): void {
    AppState.switchCourse(course);
    this.activeCourse = course;
    this.currentIndex = 0;
    this.courseChosen = true;
  }

  private consumeWidgetLaunch(): void {
    const raw = AppStorage.get<string>('widgetLaunchPending') ?? '';
    if (raw.length === 0) { return; }
    AppStorage.setOrCreate('widgetLaunchPending', '');
    const request = JSON.parse(raw) as WidgetLaunchRequest;
    const samePage = this.courseChosen && AppState.getCourse() === request.course;
    if (!samePage) { this.chooseCourse(request.course); }
    const activeTask = request.planId === AppState.getActivePlanId() &&
      AppState.getPlan().some((item) => item.kc === request.kc) && !AppState.isDone(request.kc);
    this.pendingWidgetKc = activeTask ? request.kc : -1;
    this.currentIndex = activeTask ? 1 : (AppState.hasPlan() ? 3 : 2);
    if (samePage) {
      this.tabsController.changeIndex(this.currentIndex);
      this.applyPendingWidgetPractice();
    }
  }

  private applyPendingWidgetPractice(): void {
    if (this.pendingWidgetKc < 0) { return; }
    const kc = this.pendingWidgetKc;
    this.pendingWidgetKc = -1;
    openPractice(kc);
  }

  @Builder
  CourseChoice() {
    Scroll() {
      Column({ space: 16 }) {
        Image($r('app.media.zhijing_start'))
          .width(88).height(88).borderRadius(24).margin({ bottom: 8 })
          .accessibilityLevel('no')
        Text('知径').fontSize(36).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text('让学习有方向').fontSize(15).fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 28 })
        Text('选择想学习的课程').fontSize(22).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary')).width('100%')
        Button({ type: ButtonType.Normal }) {
          Row({ space: 14 }) {
            Image($r('app.media.ic_math')).width(32).height(32).fillColor(Color.White)
              .accessibilityLevel('no')
            Column({ space: 6 }) {
              Text('小学数学').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
              Text('梳理知识关系，巩固解题基础').fontSize(13).fontColor('#F0F5FF')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(26).fontColor(Color.White).accessibilityLevel('no')
          }.width('100%').padding(20)
        }.width('100%').constraintSize({ minHeight: 96 }).borderRadius(24)
          .backgroundColor($r('app.color.brand_solid'))
          .accessibilityText('小学数学，选择课程')
          .onClick(() => { this.chooseCourse('math'); })
        Button({ type: ButtonType.Normal }) {
          Row({ space: 14 }) {
            Image($r('app.media.ic_code')).width(32).height(32).fillColor(Color.White)
              .accessibilityLevel('no')
            Column({ space: 6 }) {
              Text('Java 数据结构').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
              Text('连接知识脉络，练习编程解题').fontSize(13).fontColor('#F3F0FF')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(26).fontColor(Color.White).accessibilityLevel('no')
          }.width('100%').padding(20)
        }.width('100%').constraintSize({ minHeight: 96 }).borderRadius(24)
          .backgroundColor($r('app.color.purple_solid'))
          .accessibilityText('Java 数据结构，选择课程')
          .onClick(() => { this.chooseCourse('dsa'); })
        Text('两门课程的学习记录分别保存').fontSize(13).fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center).margin({ top: 12 })
      }.width('88%').constraintSize({ maxWidth: 480, minHeight: '100%' })
        .padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .scrollBar(BarState.Auto)
  }

}
