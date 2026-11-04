import { AdaptiveLayout } from '../utils/AdaptiveLayout';
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
  @State windowWidth: number = 0;
  private navLabels: string[] = ['首页', '图谱', '助手', '路径', '我的'];
  private navIcons: Resource[] = [$r('app.media.ic_home'), $r('app.media.ic_graph'),
    $r('app.media.ic_message'), $r('app.media.ic_path'), $r('app.media.ic_profile')];
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
    Row() {
    if (!this.courseChosen) {
      this.CourseChoice()
    } else {
    if (this.windowWidth >= 600) {
      this.SideNavigation()
    }
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
      }.width('90%').constraintSize({ maxWidth: 1440 }).padding({ top: 4, bottom: 4 })
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
      .barHeight(this.windowWidth >= 600 ? 0 : 64, true)
      .scrollable(this.windowWidth < 600)
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
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
      }
    }
    .width('100%').height('100%')
    .alignItems(VerticalAlign.Top)
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      if (width > 0 && width !== this.windowWidth) {
        this.windowWidth = width;
        AppStorage.setOrCreate('contentWidth', AdaptiveLayout.contentWidth(width));
      }
    })
  }

  @Builder
  SideNavigation() {
    Scroll() {
      Column({ space: 8 }) {
        Image($r('app.media.zhijing_start')).width(40).height(40).borderRadius(12)
          .margin({ top: 20, bottom: 16 }).accessibilityLevel('no')
        ForEach(this.navLabels, (label: string, index: number) => {
          Button({ type: ButtonType.Normal }) {
            Flex({ direction: this.windowWidth >= 1200 ? FlexDirection.Row : FlexDirection.Column,
              alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
              Image(this.navIcons[index]).width(24).height(24)
                .fillColor(this.currentIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
                .accessibilityLevel('no')
              Text(label).fontSize(this.windowWidth >= 1200 ? 15 : 11)
                .fontColor(this.currentIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
                .margin({ left: this.windowWidth >= 1200 ? 16 : 0, top: this.windowWidth >= 1200 ? 0 : 4 })
            }.width('100%')
          }
          .width('90%').height(64).borderRadius(16)
          .backgroundColor(this.currentIndex === index ? $r('app.color.brand_tint') : Color.Transparent)
          .hoverEffect(HoverEffect.Auto).accessibilityText(label)
          .keyboardShortcut((index + 1).toString(), [ModifierKey.ALT])
          .onClick(() => {
            this.currentIndex = index;
            this.tabsController.changeIndex(index);
          })
        }, (label: string) => label)
      }.width('100%').padding({ bottom: 20 })
    }.width(AdaptiveLayout.navigationWidth(this.windowWidth)).height('100%')
      .backgroundColor($r('app.color.surface')).scrollBar(BarState.Auto)
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
        Flex({ direction: this.windowWidth >= 600 ? FlexDirection.Row : FlexDirection.Column,
          justifyContent: FlexAlign.SpaceBetween }) {
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
        }.width(this.windowWidth >= 600 ? '48%' : '100%')
          .constraintSize({ minHeight: this.windowWidth >= 600 ? 140 : 96 }).borderRadius(24)
          .margin({ bottom: 16 })
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
        }.width(this.windowWidth >= 600 ? '48%' : '100%')
          .constraintSize({ minHeight: this.windowWidth >= 600 ? 140 : 96 }).borderRadius(24)
          .margin({ bottom: 16 })
          .backgroundColor($r('app.color.purple_solid'))
          .accessibilityText('Java 数据结构，选择课程')
          .onClick(() => { this.chooseCourse('dsa'); })
        }.width('100%')
        Text('两门课程的学习记录分别保存').fontSize(13).fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center).margin({ top: 12 })
      }.width('88%').constraintSize({ maxWidth: this.windowWidth >= 600 ? 960 : 480, minHeight: '100%' })
        .padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .scrollBar(BarState.Auto)
  }

}
