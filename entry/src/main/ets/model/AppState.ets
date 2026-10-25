/**
 * 全局学习状态 —— 纯单例，无 UI 依赖。
 */

export interface Interaction {
  kc: number;
  correct: number;
  qid?: number;
}

interface CourseSnapshot {
  supportedKcs?: number[];
  interactions: Interaction[];
  answeredQuestions: number[];
  mastery: number[];
  weak: WeakKc[];
  plan: WeakKc[];
  doneKcIds: number[];
  taskQuestions: TaskQuestion[];
  completedPlans: CompletedPlan[];
  nextPlanId: number;
  activePlanId: number;
  intake: Record<string, string>;
  intakeDone: boolean;
}

export interface WeakKc {
  kc: number;
  name: string;
  mastery: number;
}

export interface CompletedPlan {
  id: number;
  title: string;
  items: WeakKc[];
  diagnosed: boolean;
  questions: TaskQuestion[];
}

export interface TaskQuestion {
  kc: number;
  qid: number;
  answered: boolean;
}

export interface AnswerProgress {
  taskCompleted: boolean;
  planCompleted: boolean;
}

export interface StudyOverview {
  hasMastery: boolean;
  overallMastery: number;
  questionCount: number;
  taskCount: number;
  doneTaskCount: number;
}

export class AppState {
  private static supportedKcs: number[] = [];
  private static course: string = 'math';
  private static courseEpoch: number = 0;
  private static persistent: boolean = false;
  private static studyChangeListener: (() => void) | null = null;

  static setStudyChangeListener(listener: () => void): void {
    AppState.studyChangeListener = listener;
  }

  static getCourse(): string { return AppState.course; }
  static getCourseEpoch(): number { return AppState.courseEpoch; }
  static isDsa(): boolean { return AppState.course === 'dsa'; }
  static courseName(): string { return AppState.isDsa() ? 'Java 数据结构' : '小学数学'; }

  static initializeStorage(): void {
    PersistentStorage.persistProp('study_math', '');
    PersistentStorage.persistProp('study_dsa', '');
    PersistentStorage.persistProp('chat_math', '');
    PersistentStorage.persistProp('chat_dsa', '');
    PersistentStorage.persistProp('lastStudyCourse', 'math');
    AppState.course = AppStorage.get<string>('lastStudyCourse') === 'dsa' ? 'dsa' : 'math';
    AppState.persistent = true;
    AppState.restoreCourse();
  }

  private static saveCourse(): void {
    const snapshot: CourseSnapshot = {
      supportedKcs: AppState.supportedKcs,
      interactions: AppState.interactions, answeredQuestions: Array.from(AppState.answeredQuestions),
      mastery: AppState.mastery, weak: AppState.weak, plan: AppState.plan,
      doneKcIds: AppState.doneKcIds, taskQuestions: AppState.taskQuestions,
      completedPlans: AppState.completedPlans, nextPlanId: AppState.nextPlanId,
      activePlanId: AppState.activePlanId, intake: AppState.intake, intakeDone: AppState.intakeDone
    };
    AppStorage.setOrCreate('study_' + AppState.course, JSON.stringify(snapshot));
  }

  private static restoreCourse(): void {
    const raw = AppStorage.get<string>('study_' + AppState.course) ?? '';
    let state: CourseSnapshot = {
      interactions: [], answeredQuestions: [], mastery: [], weak: [], plan: [], doneKcIds: [],
      taskQuestions: [], completedPlans: [], nextPlanId: 1, activePlanId: 0, intake: {}, intakeDone: false
    };
    if (raw.length > 0) {
      try { state = JSON.parse(raw) as CourseSnapshot; } catch (e) { console.error('学习记录读取失败'); }
    }
    AppState.interactions = state.interactions;
    AppState.supportedKcs = state.supportedKcs ?? [];
    AppState.answeredQuestions = new Set<number>(state.answeredQuestions);
    AppState.mastery = state.mastery;
    AppState.weak = state.weak;
    AppState.plan = state.plan;
    AppState.doneKcIds = state.doneKcIds;
    AppState.taskQuestions = state.taskQuestions;
    AppState.completedPlans = state.completedPlans;
    AppState.nextPlanId = state.nextPlanId;
    AppState.activePlanId = state.activePlanId;
    AppState.intake = state.intake;
    AppState.intakeDone = state.intakeDone;
  }

  static switchCourse(course: string): void {
    if (course !== 'math' && course !== 'dsa') { return; }
    AppState.saveCourse();
    AppState.course = course;
    AppStorage.setOrCreate('lastStudyCourse', course);
    AppState.courseEpoch++;
    AppState.restoreCourse();
    AppStorage.setOrCreate('focusKcId', -1);
    AppStorage.setOrCreate('practiceKcId', -1);
    AppStorage.setOrCreate('practiceQid', -1);
    AppStorage.setOrCreate('replanPreviousPath', '');
    AppStorage.setOrCreate('replanSeq', 0);
    AppStorage.setOrCreate('focusSeq', 0);
    AppStorage.setOrCreate('practiceSeq', 0);
    AppState.notifyChanged();
  }
  private static interactions: Interaction[] = [];
  private static answeredQuestions: Set<number> = new Set<number>();
  private static mastery: number[] = [];
  private static weak: WeakKc[] = [];
  private static plan: WeakKc[] = [];
  private static doneKcIds: number[] = [];
  private static taskQuestions: TaskQuestion[] = [];
  private static completedPlans: CompletedPlan[] = [];
  private static nextPlanId: number = 1;
  private static activePlanId: number = 0;
  private static intake: Record<string, string> = {};
  private static intakeDone: boolean = false;
  private static version: number = 0;

  // 任意学习状态变化时自增版本号，供 @StorageProp + @Watch 响应式刷新
  private static notifyChanged(): void {
    if (AppState.persistent) { AppState.saveCourse(); }
    AppState.version++;
    AppStorage.setOrCreate('appStateVersion', AppState.version);
    AppState.studyChangeListener?.();
  }

  // 模型保留完整作答序列；展示题数按题库的唯一题号去重。
  static addInteraction(kc: number, correct: number, qid: number): AnswerProgress {
    AppState.interactions.push({ kc: kc, correct: correct, qid: qid });
    AppState.answeredQuestions.add(qid);
    let taskCompleted = false;
    let planCompleted = false;
    const questions = AppState.taskQuestions.filter((question: TaskQuestion) => question.kc === kc);
    for (const question of questions) {
      if (question.qid === qid) {
        question.answered = true;
      }
    }
    if (questions.length > 0 && questions.every((question: TaskQuestion) => question.answered) &&
      !AppState.isDone(kc)) {
      taskCompleted = true;
      planCompleted = AppState.completeTask(kc);
    }
    AppState.notifyChanged();
    return { taskCompleted: taskCompleted, planCompleted: planCompleted };
  }

  static getInteractions(): Interaction[] {
    return AppState.interactions.slice();
  }

  static interactionCount(): number {
    return AppState.interactions.length;
  }

  static questionCount(): number {
    return AppState.answeredQuestions.size;
  }

  static getOverview(): StudyOverview {
    return {
      hasMastery: AppState.hasMastery(),
      overallMastery: AppState.overallMastery(),
      questionCount: AppState.questionCount(),
      taskCount: AppState.plan.length,
      doneTaskCount: AppState.doneCount()
    };
  }

  // ---- 掌握度 ----
  static setMastery(m: number[], supportedKcs: number[] = []): void {
    AppState.mastery = m.slice();
    AppState.supportedKcs = supportedKcs.slice();
    AppState.notifyChanged();
  }

  static getMastery(kc: number): number {
    if (!AppState.supportsPrediction(kc)) { return 0; }
    if (kc >= 0 && kc < AppState.mastery.length) {
      return AppState.mastery[kc];
    }
    return 0;
  }

  static hasMastery(): boolean {
    return AppState.mastery.length > 0;
  }

  static supportsPrediction(kc: number): boolean {
    return !AppState.isDsa() || AppState.supportedKcs.includes(kc);
  }

  // 综合掌握度：全部掌握度取平均值，转百分比
  static overallMastery(): number {
    if (AppState.mastery.length === 0) {
      return 0;
    }
    let s = 0;
    let count = 0;
    for (let i = 0; i < AppState.mastery.length; i++) {
      if (AppState.supportsPrediction(i)) {
        s += AppState.mastery[i];
        count++;
      }
    }
    return count > 0 ? Math.round((s / count) * 100) : 0;
  }

  // ---- 薄弱知识点 ----
  static setWeak(w: WeakKc[]): void {
    AppState.weak = w;
    AppState.notifyChanged();
  }

  static getWeak(): WeakKc[] {
    return AppState.weak;
  }

  // ---- 已接受的学习计划 ----
  static setPlan(p: WeakKc[]): boolean {
    if (AppState.hasPlan() || p.length === 0) {
      return false;
    }
    const items: WeakKc[] = [];
    const ids = new Set<number>();
    for (const item of p) {
      if (!ids.has(item.kc)) {
        items.push({ kc: item.kc, name: item.name, mastery: item.mastery });
        ids.add(item.kc);
      }
    }
    AppState.plan = items;
    AppState.activePlanId = AppState.nextPlanId++;
    AppState.doneKcIds = [];
    AppState.taskQuestions = [];
    AppState.notifyChanged();
    return true;
  }

  static getPlan(): WeakKc[] {
    return AppState.plan;
  }

  static hasPlan(): boolean {
    return AppState.plan.length > 0;
  }

  static getPlanTitle(): string {
    return '学习路径 ' + AppState.activePlanId;
  }

  static getActivePlanId(): number {
    return AppState.activePlanId;
  }

  // 题目只在当前路径内绑定一次，历史作答不算新任务的完成进度。
  static registerTaskQuestions(planId: number, kc: number, qids: number[]): void {
    if (planId === 0 || planId !== AppState.activePlanId || qids.length === 0 ||
      !AppState.plan.some((item: WeakKc) => item.kc === kc) ||
      AppState.taskQuestions.some((question: TaskQuestion) => question.kc === kc)) {
      return;
    }
    const ids = new Set<number>();
    for (const qid of qids) {
      if (!ids.has(qid)) {
        AppState.taskQuestions.push({ kc: kc, qid: qid, answered: false });
        ids.add(qid);
      }
    }
    AppState.notifyChanged();
  }

  static getTaskQuestions(kc: number): TaskQuestion[] {
    const questions: TaskQuestion[] = [];
    for (const question of AppState.taskQuestions) {
      if (question.kc === kc) {
        questions.push({ kc: question.kc, qid: question.qid, answered: question.answered });
      }
    }
    return questions;
  }

  static getCompletedPlans(): CompletedPlan[] {
    return AppState.completedPlans.slice();
  }

  // ---- 计划完成进度 ----
  // 最后一项完成时，将整条路径归档，一次通知所有页面刷新。
  private static completeTask(kc: number): boolean {
    if (!AppState.plan.some((item: WeakKc) => item.kc === kc) || AppState.isDone(kc)) {
      return false;
    }
    AppState.doneKcIds.push(kc);
    const completed = AppState.doneKcIds.length === AppState.plan.length;
    if (completed) {
      const items: WeakKc[] = [];
      for (const item of AppState.plan) {
        items.push({
          kc: item.kc,
          name: item.name,
          mastery: AppState.hasMastery() ? AppState.getMastery(item.kc) : item.mastery
        });
      }
      AppState.completedPlans.unshift({
        id: AppState.activePlanId,
        title: AppState.getPlanTitle(),
        items: items,
        diagnosed: AppState.hasMastery(),
        questions: AppState.taskQuestions.map((question: TaskQuestion): TaskQuestion => {
          return { kc: question.kc, qid: question.qid, answered: question.answered };
        })
      });
      AppState.plan = [];
      AppState.doneKcIds = [];
      AppState.taskQuestions = [];
      AppState.activePlanId = 0;
    }
    return completed;
  }

  static isDone(kc: number): boolean {
    for (let i = 0; i < AppState.doneKcIds.length; i++) {
      if (AppState.doneKcIds[i] === kc) {
        return true;
      }
    }
    return false;
  }

  static doneCount(): number {
    return AppState.doneKcIds.length;
  }

  static cancelPlan(expectedPlanId: number): boolean {
    if (expectedPlanId === 0 || expectedPlanId !== AppState.activePlanId) {
      return false;
    }
    AppState.clearPlan();
    return true;
  }

  static clearPlan(): void {
    AppState.plan = [];
    AppState.doneKcIds = [];
    AppState.taskQuestions = [];
    AppState.activePlanId = 0;
    AppState.notifyChanged();
  }

  // ---- 摸底信息 ----
  static setIntake(key: string, value: string): void {
    AppState.intake[key] = value;
  }

  static getIntake(): Record<string, string> {
    return AppState.intake;
  }

  static isIntakeDone(): boolean {
    return AppState.intakeDone;
  }

  static setIntakeDone(done: boolean): void {
    AppState.intakeDone = done;
    AppState.notifyChanged();
  }
}
