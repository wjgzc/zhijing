import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';
import { AppState, WeakKc } from '../model/AppState';
import { BackendService, ChatMsg } from '../services/BackendService';
import { cancelCurrentPlan } from '../utils/PlanActions';
import { displayText } from '../utils/TextFormat';

// ============================================================================
// 消息分段：把 DeepSeek 输出里的 [名称](kc://id) 解析成可点击链接
// ============================================================================
interface ChatSegment {
  type: string;   // 'text' | 'link'
  text: string;
  kc: number;
}

interface UIMessage {
  id: number;
  role: 'agent' | 'user';
  content: string;
  lines: ChatSegment[][];
  isSuggestion: boolean;
  suggestionState: string;
  plan: WeakKc[];
  planId: number;
}

function parseSegments(content: string): ChatSegment[] {
  if (content.length === 0) {
    return [{ type: 'text', text: '', kc: -1 }];
  }
  const segs: ChatSegment[] = [];
  let i = 0;
  const n = content.length;
  while (i < n) {
    const lb = content.indexOf('[', i);
    if (lb < 0) {
      segs.push({ type: 'text', text: content.substring(i), kc: -1 });
      break;
    }
    const rb = content.indexOf('](', lb);
    if (rb < 0) {
      segs.push({ type: 'text', text: content.substring(i), kc: -1 });
      break;
    }
    const close = content.indexOf(')', rb + 2);
    if (close < 0) {
      segs.push({ type: 'text', text: content.substring(i), kc: -1 });
      break;
    }
    const inner = content.substring(rb + 2, close);
    if (inner.startsWith('kc://')) {
      const kc = parseInt(inner.substring(5));
      if (!isNaN(kc)) {
        if (lb > i) {
          segs.push({ type: 'text', text: content.substring(i, lb), kc: -1 });
        }
        segs.push({ type: 'link', text: content.substring(lb + 1, rb), kc: kc });
        i = close + 1;
        continue;
      }
    }
    segs.push({ type: 'text', text: content.substring(i, rb + 1), kc: -1 });
    i = rb + 1;
  }
  return segs;
}

function toAgentMessage(content: string, isSuggestion: boolean, id: number = 0,
  plan: WeakKc[] = []): UIMessage {
  content = displayText(content);
  const rawLines = content.split('\n');
  const lineSegs: ChatSegment[][] = [];
  for (let i = 0; i < rawLines.length; i++) {
    lineSegs.push(parseSegments(rawLines[i]));
  }
  return {
    id: id,
    role: 'agent',
    content: content,
    lines: lineSegs,
    isSuggestion: isSuggestion,
    suggestionState: isSuggestion ? 'pending' : 'none',
    plan: plan.map((item: WeakKc): WeakKc => {
      return { kc: item.kc, name: item.name, mastery: item.mastery };
    }),
    planId: 0
  };
}

function withSuggestionState(msg: UIMessage, state: string, planId: number): UIMessage {
  return {
    id: msg.id,
    role: msg.role,
    content: msg.content,
    lines: msg.lines,
    isSuggestion: msg.isSuggestion,
    suggestionState: state,
    plan: msg.plan,
    planId: planId
  };
}

const GRADES: string[] = ['三年级', '四年级', '五年级'];
const GOALS: string[] = ['计数问题', '几何图形', '应用题', '其他'];
const TIMES: string[] = ['15分钟', '30分钟', '1小时'];

@Component
export struct AgentChat {
  @State messages: UIMessage[] = [
    toAgentMessage('你好！我是知径学习助手 🤖\n先花几秒钟了解一下你的情况，请选择下面三个问题，然后点「开始分析」，我会结合你的做题情况给出学习建议。', false)
  ];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State intakeDone: boolean = false;
  @State intakeGrade: string = '';
  @State intakeGoal: string = '';
  @State intakeTime: string = '';
  @State hasActivePlan: boolean = false;
  @StorageProp('appStateVersion') @Watch('refreshSuggestionStates') stateVersion: number = 0;
  @StorageProp('replanSeq') @Watch('onReplanRequest') replanSeq: number = 0;
  private courseId: string = AppState.getCourse();
  private courseEpoch: number = AppState.getCourseEpoch();
  private lastReplanSeq: number = 0;
  private nextMessageId: number = 1;
  private scrollController: Scroller = new Scroller();

  aboutToAppear(): void {
    const saved = AppStorage.get<string>("chat_" + this.courseId) ?? "";
    if (saved.length > 0) {
      try {
        const restored = JSON.parse(saved) as UIMessage[];
        this.messages = restored.map((msg: UIMessage): UIMessage => {
          const fresh = toAgentMessage(msg.content, msg.isSuggestion, msg.id, msg.plan);
          return { id: msg.id, role: msg.role, content: fresh.content, lines: fresh.lines,
            isSuggestion: msg.isSuggestion, suggestionState: msg.suggestionState, plan: msg.plan, planId: msg.planId };
        });
      } catch (e) { console.error("聊天记录读取失败"); }
      this.nextMessageId = this.messages.reduce((id: number, msg: UIMessage) => Math.max(id, msg.id + 1), 1);
    }
    this.intakeDone = AppState.isIntakeDone();
    if (this.intakeDone) {
      const it = AppState.getIntake();
      this.intakeGrade = it[AppState.isDsa() ? '学习基础' : '年级'] ?? '';
      this.intakeGoal = it['想提升'] ?? '';
      this.intakeTime = it['每天时间'] ?? '';
    }
    this.refreshSuggestionStates();
    this.onReplanRequest();
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate("chat_" + this.courseId, JSON.stringify(this.messages));
  }

  private refreshSuggestionStates(): void {
    if (this.courseEpoch !== AppState.getCourseEpoch()) { return; }
    this.hasActivePlan = AppState.hasPlan();
    const activeId = AppState.getActivePlanId();
    const completed = AppState.getCompletedPlans();
    this.messages = this.messages.map((msg: UIMessage): UIMessage => {
      if (msg.suggestionState !== 'accepted' || msg.planId === activeId) {
        return msg;
      }
      const state = completed.some((plan) => plan.id === msg.planId) ? 'completed' : 'cancelled';
      return withSuggestionState(msg, state, msg.planId);
    });
  }

  private onReplanRequest(): void {
    if (this.replanSeq <= this.lastReplanSeq || this.isLoading) {
      return;
    }
    this.lastReplanSeq = this.replanSeq;
    if (AppState.hasPlan()) {
      promptAction.showToast({ message: '请先取消当前路径，再重新规划', duration: 2000 });
      return;
    }
    this.intakeDone = AppState.isIntakeDone();
    if (!this.intakeDone) {
      promptAction.showToast({ message: '请先完成摸底信息，再生成新的学习路径', duration: 2500 });
      return;
    }
    const previousPath = AppStorage.get<string>('replanPreviousPath') ?? '';
    const message = previousPath.length > 0 ?
      '我已取消上一条学习路径：' + previousPath + '。请根据我最新的做题情况和摸底信息，重新生成一条学习路径，调整安排并说明原因。' :
      '请根据我最新的做题情况和摸底信息，生成一条新的学习路径。';
    this.runChat(message, true);
  }

  private scrollToBottom(): void {
    this.scrollController.scrollEdge(Edge.Bottom);
  }

  private focusGraph(kc: number): void {
    AppStorage.setOrCreate('focusKcId', kc);
    const seq = (AppStorage.get<number>('focusSeq') ?? 0) + 1;
    AppStorage.setOrCreate('focusSeq', seq);
    switchTab(1);
  }

  private buildHistory(): ChatMsg[] {
    const history: ChatMsg[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      const msg = this.messages[i];
      history.push({
        role: msg.role === 'agent' ? 'assistant' : 'user',
        content: msg.content
      });
    }
    return history;
  }

  private async runChat(userText: string, isSuggestion: boolean): Promise<void> {
    this.messages.push({
      id: this.nextMessageId++,
      role: 'user',
      content: userText,
      lines: [[{ type: 'text', text: userText, kc: -1 }]],
      isSuggestion: false,
      suggestionState: 'none',
      plan: [],
      planId: 0
    });
    this.inputText = '';
    this.isLoading = true;
    this.scrollToBottom();

    try {
      const history = this.buildHistory();
      const res = await BackendService.chat(AppState.getInteractions(), AppState.getIntake(), history);
      if (this.courseEpoch !== AppState.getCourseEpoch()) { return; }
      AppState.setWeak(res.weak);
      const mv = (AppStorage.get<number>('masteryVersion') ?? 0) + 1;
      AppStorage.setOrCreate('masteryVersion', mv);
      this.messages.push(toAgentMessage(res.content, isSuggestion, this.nextMessageId++, res.weak));
      this.scrollToBottom();
    } catch (e) {
      const msg = (e as Error).message || '请求失败';
      this.messages.push(toAgentMessage('⚠️ ' + msg + '\n\n请确认后端服务已启动、网络连通。', false,
        this.nextMessageId++));
    } finally {
      this.isLoading = false;
      AppStorage.setOrCreate("chat_" + this.courseId, JSON.stringify(this.messages));
      if (this.courseEpoch === AppState.getCourseEpoch()) { this.onReplanRequest(); }
    }
  }

  private acceptSuggestion(messageId: number): void {
    const message = this.messages.find((msg: UIMessage) => msg.id === messageId);
    if (message === undefined || message.suggestionState !== 'pending') {
      return;
    }
    if (AppState.hasPlan()) {
      promptAction.showToast({ message: '请先完成或取消当前路径，再接受新的计划', duration: 2500 });
      return;
    }
    const weak = message.plan;
    if (weak.length === 0) {
      promptAction.showToast({ message: '该建议没有可用知识点，请重新生成建议', duration: 2500 });
      return;
    }
    if (!AppState.setPlan(weak)) {
      return;
    }
    const planId = AppState.getActivePlanId();
    this.messages = this.messages.map((msg: UIMessage): UIMessage => {
      return msg.id === messageId ? withSuggestionState(msg, 'accepted', planId) : msg;
    });
    const v = (AppStorage.get<number>('planVersion') ?? 0) + 1;
    AppStorage.setOrCreate('planVersion', v);
    AppStorage.setOrCreate('chat_' + this.courseId, JSON.stringify(this.messages));
    promptAction.showToast({ message: '已生成学习计划，可在「路径」查看', duration: 2000 });
  }

  private rejectSuggestion(messageId: number): void {
    this.messages = this.messages.map((msg: UIMessage): UIMessage => {
      return msg.id === messageId && msg.suggestionState === 'pending' ?
        withSuggestionState(msg, 'rejected', msg.planId) : msg;
    });
    AppStorage.setOrCreate('chat_' + this.courseId, JSON.stringify(this.messages));
    promptAction.showToast({ message: '已忽略该建议', duration: 2000 });
  }

  private startAnalysis(): void {
    AppState.setIntake(AppState.isDsa() ? '学习基础' : '年级', this.intakeGrade);
    AppState.setIntake('想提升', this.intakeGoal);
    AppState.setIntake('每天时间', this.intakeTime);
    AppState.setIntakeDone(true);
    this.intakeDone = true;
    this.runChat('请根据我的摸底信息和做题数据，帮我生成一份学习建议。', true);
  }

  private resetIntake(): void {
    AppState.setIntakeDone(false);
    this.intakeDone = false;
    this.intakeGrade = '';
    this.intakeGoal = '';
    this.intakeTime = '';
  }

  build() {
    Column() {
      Column() {
        this.PageHeader()
        if (!this.intakeDone) {
          this.IntakePanel()
        } else {
          this.IntakeSummary()
        }
        this.ChatArea()
        this.InputArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PageHeader() {
    Row() {
      Column() {
        Text('学习助手')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.isLoading ? '思考中...' : '结合练习情况，为你规划学习路径')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (this.intakeDone) {
        Text(this.hasActivePlan ? '重新规划' : '生成建议')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            if (AppState.hasPlan()) {
              cancelCurrentPlan(true);
              return;
            }
            this.runChat('请根据我的做题情况，再生成一份学习建议。', true);
          })
          .margin({ right: 12 })
      }
    }
    .width('90%')
    .height(60)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  IntakePanel() {
    Column() {
      Text(AppState.isDsa() ? '学习基础' : '年级')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 6 })
      Row({ space: 8 }) {
        ForEach(AppState.isDsa() ? ['刚接触 Java', '掌握 Java 基础', '学过数据结构'] : GRADES, (g: string) => {
          Text(g)
            .fontSize(13)
            .fontColor(this.intakeGrade === g ? Color.White : $r('app.color.brand'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(this.intakeGrade === g ? $r('app.color.brand_solid') : $r('app.color.brand_tint'))
            .borderRadius(16)
            .onClick(() => {
              this.intakeGrade = g;
            })
        }, (g: string) => g)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('想重点提升')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 6 })
      Row({ space: 8 }) {
        ForEach(AppState.isDsa() ? ['线性结构', '树与图', '查找排序', '综合练习'] : GOALS, (g: string) => {
          Text(g)
            .fontSize(13)
            .fontColor(this.intakeGoal === g ? Color.White : $r('app.color.brand'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(this.intakeGoal === g ? $r('app.color.brand_solid') : $r('app.color.brand_tint'))
            .borderRadius(16)
            .onClick(() => {
              this.intakeGoal = g;
            })
        }, (g: string) => g)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('每天可投入')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 6 })
      Row({ space: 8 }) {
        ForEach(TIMES, (g: string) => {
          Text(g)
            .fontSize(13)
            .fontColor(this.intakeTime === g ? Color.White : $r('app.color.brand'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(this.intakeTime === g ? $r('app.color.brand_solid') : $r('app.color.brand_tint'))
            .borderRadius(16)
            .onClick(() => {
              this.intakeTime = g;
            })
        }, (g: string) => g)
      }
      .width('100%')
      .margin({ bottom: 14 })

      Button('开始分析')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width('100%')
        .height(46)
        .borderRadius(14)
        .linearGradient({
          angle: 135,
          colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
        })
        .enabled(this.intakeGrade !== '' && this.intakeGoal !== '' && this.intakeTime !== '')
        .opacity(this.intakeGrade !== '' && this.intakeGoal !== '' && this.intakeTime !== '' ? 1 : 0.5)
        .onClick(() => {
          this.startAnalysis();
        })
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
    .margin({ bottom: 12 })
  }

  @Builder
  IntakeSummary() {
    Row() {
      Text(`摸底：${this.intakeGrade} · ${this.intakeGoal} · ${this.intakeTime}`)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text('重新摸底')
        .fontSize(12)
        .fontColor($r('app.color.brand'))
        .onClick(() => {
          this.resetIntake();
        })
    }
    .width('90%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  ChatArea() {
    Column() {
      Scroll(this.scrollController) {
        Column() {
          ForEach(this.messages, (msg: UIMessage, index: number) => {
            if (msg.role === 'agent') {
              this.AgentMessage(msg)
            } else {
              this.UserMessage(msg)
            }
          }, (msg: UIMessage) => msg.id.toString() + '_' + msg.suggestionState)

          if (this.isLoading) {
            this.LoadingIndicator()
          }
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  LoadingIndicator() {
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill($r('app.color.surface'))
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.brand'))
      }
      .width(36)
      .height(36)
      .flexShrink(0)
      .margin({ right: 10 })

      Row() {
        Text('思考中')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(18)
      .borderRadius({ topLeft: 4 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  MessageLine(segs: ChatSegment[]) {
    Text() {
      ForEach(segs, (seg: ChatSegment) => {
        if (seg.type === 'link') {
          Span(seg.text).fontColor($r('app.color.brand')).fontWeight(FontWeight.Medium)
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.brand') })
            .onClick(() => { this.focusGraph(seg.kc); })
        } else {
          Span(seg.text.length === 0 ? ' ' : seg.text)
        }
      }, (seg: ChatSegment, idx: number) => idx.toString())
    }
    .fontSize(14).fontColor($r('app.color.text_primary')).lineHeight(21)
    .width('100%').wordBreak(WordBreak.BREAK_ALL)
  }

  @Builder
  AgentMessage(msg: UIMessage) {
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill($r('app.color.surface'))
        Text('🤖')
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .flexShrink(0)
      .margin({ right: 10 })

      Column() {
        ForEach(msg.lines, (segs: ChatSegment[], li: number) => {
          this.MessageLine(segs)
        }, (segs: ChatSegment[], li: number) => li.toString())
        if (msg.isSuggestion && msg.suggestionState === 'pending') {
          Row({ space: 10 }) {
            Button('✓ 接受')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .height(38)
              .layoutWeight(1)
              .borderRadius(12)
              .backgroundColor($r('app.color.success_solid'))
              .onClick(() => {
                this.acceptSuggestion(msg.id);
              })
            Button('✕ 不接受')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .height(38)
              .layoutWeight(1)
              .borderRadius(12)
              .backgroundColor($r('app.color.surface_subtle'))
              .onClick(() => {
                this.rejectSuggestion(msg.id);
              })
          }
          .width('100%')
          .margin({ top: 10 })
        } else if (msg.isSuggestion) {
          Text(msg.suggestionState === 'accepted' ? '✓ 已接受，路径正在进行' :
            msg.suggestionState === 'completed' ? '✓ 该路径已完成' :
              msg.suggestionState === 'cancelled' ? '该路径已取消' : '已忽略该建议')
            .fontSize(12)
            .fontColor(msg.suggestionState === 'accepted' || msg.suggestionState === 'completed' ?
              $r('app.color.success') : $r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
      }
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(18)
      .borderRadius({ topLeft: 4 })
      .shadow({
        radius: 4,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
      .constraintSize({ maxWidth: 280 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  UserMessage(msg: UIMessage) {
    Row() {
      Column() {
        Text(msg.content)
          .width('100%').wordBreak(WordBreak.BREAK_ALL)
          .fontSize(14)
          .fontColor(Color.White)
          .lineHeight(20)
      }
      .padding(12)
      .linearGradient({
        angle: 135,
        colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
      })
      .borderRadius(18)
      .borderRadius({ topRight: 4 })
      .constraintSize({ maxWidth: 260 })
      .layoutWeight(1)

      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill($r('app.color.divider'))
        Text('🙋')
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .flexShrink(0)
      .margin({ left: 10 })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ bottom: 12 })
  }

  @Builder
  InputArea() {
    Column() {
      Row() {
        TextArea({ placeholder: '继续和学习助手 聊聊学习...', text: this.inputText })
          .placeholderColor($r('app.color.text_placeholder'))
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .enabled(!this.isLoading)
          .maxLines(5)
          .padding({ top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.inputText = value;
          })

        Button(this.isLoading ? '⏳' : '➤')
          .fontSize(14)
          .fontColor(Color.White)
          .padding(0)
          .linearGradient({
            angle: 135,
            colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
          })
          .width(36)
          .height(36)
          .borderRadius(18)
          .enabled(!this.isLoading)
          .opacity(this.isLoading ? 0.5 : 1)
          .alignSelf(ItemAlign.End)
          .margin({ bottom: 10 })
          .onClick(() => {
            if (this.inputText.trim() !== '') {
              this.runChat(this.inputText.trim(), false);
            }
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 56, maxHeight: 150 })
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(28)
      .clip(true)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('90%')
    .padding({ top: 12, bottom: 24 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 1 }, color: $r('app.color.surface_subtle') })
  }
}
