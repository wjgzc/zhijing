import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppState, Interaction } from '../model/AppState';
import { BackendService, QuestionItem, QuestionExample, BACKEND_BASE_URL } from '../services/BackendService';
import { PracticeService } from '../services/PracticeService';

// ============================================================================
// 配置
// ============================================================================
interface GraphConfig {
  minScale: number;
  maxScale: number;
  baseNodeRadius: number;
  layoutRadius: number;
  boundaryMargin: number;
  dimAlpha: number;
}

const GRAPH_CONFIG: GraphConfig = {
  minScale: 0.4,
  maxScale: 3.0,
  baseNodeRadius: 50,
  layoutRadius: 200,
  boundaryMargin: 40,
  dimAlpha: 0.12,
};

const MODULE_PALETTE: string[] = [
  '#4A90D9', '#F5A623', '#2ECC71', '#E74C3C',
  '#9B59B6', '#1ABC9C', '#E67E22', '#5D6D7E'
];

// ============================================================================
// 数据接口
// ============================================================================
interface RawNode {
  id: number;
  name: string;
  depth: number;
  is_leaf: boolean;
  parent: number;
  module: string;
  n_questions: number;
}

interface RawEdge {
  source: number;
  target: number;
  type: string;
}

interface KcNode {
  id: number;
  name: string;
  depth: number;
  isLeaf: boolean;
  parent: number;
  module: string;
  nQuestions: number;
  color: string;
  x: number;
  y: number;
  radius: number;
  children: number[];
}

interface GraphEdge {
  source: number;
  target: number;
  type: string;
}

interface OptionItem {
  key: string;
  text: string;
  images: string[];
}

// ============================================================================
// 工具
// ============================================================================
function clamp(v: number, min: number, max: number): number {
  return v < min ? min : (v > max ? max : v);
}

function isAscii(ch: string): boolean {
  return ch.charCodeAt(0) < 128;
}

function wrapName(name: string): string[] {
  const len = name.length;
  if (len <= 5) {
    return [name];
  }
  const lo = Math.floor(len * 0.35);
  const hi = Math.ceil(len * 0.65);
  let split = -1;
  for (let i = hi; i >= lo; i--) {
    const ch = name.charAt(i);
    if (ch === '-' || ch === ' ' || ch === '（' || ch === '(' || ch === '·') {
      split = i;
      break;
    }
  }
  if (split < 0) {
    for (let i = hi; i >= lo; i--) {
      if (i > 0 && isAscii(name.charAt(i - 1)) !== isAscii(name.charAt(i))) {
        split = i;
        break;
      }
    }
  }
  if (split < 0) {
    split = Math.floor(len / 2);
  }
  return [name.substring(0, split), name.substring(split)];
}

// ============================================================================
// 组件：钻取导航
// ============================================================================
@Component
export struct KnowledgeGraph {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private zoom: number = 1;
  private tx: number = 0;
  private ty: number = 0;
  private viewInitialized: boolean = false;
  private canvasW: number = 0;
  private canvasH: number = 0;

  // 全量数据
  private allNodes: KcNode[] = [];
  private nodeMap: Map<number, KcNode> = new Map();
  private rootIds: number[] = [];

  // 当前钻取焦点：-1 表示顶层（8 个模块）
  @State focusId: number = -1;
  private nodes: KcNode[] = [];
  private edges: GraphEdge[] = [];
  private sourceEdges: RawEdge[] = [];
  private courseEpoch: number = AppState.getCourseEpoch();

  private dataReady: boolean = false;
  private canvasReady: boolean = false;

  // 选中（叶子详情）
  @State selectedId: number = -1;
  @State selectedName: string = '';
  @State selectedModule: string = '';
  @State selectedPrereq: string = '';
  @State selectedNQuestions: number = 0;
  private highlightSet: Set<number> = new Set();

  // 做题弹窗
  @State practiceOpen: boolean = false;
  @State practiceKcName: string = '';
  @State practiceQuestions: QuestionItem[] = [];
  @State practiceIndex: number = 0;
  @State practiceRevealed: boolean = false;
  @State practiceJudged: boolean = false;
  @State practiceCorrect: boolean = false;
  @State practiceLoading: boolean = false;
  @State curContent: string = '';
  @State curAnswer: string = '';
  @State curAnalysis: string = '';
  @State curOptions: OptionItem[] = [];
  @State curCorrectKey: string = '';
  @State curIsChoice: boolean = false;
  @State curKc: number = -1;
  @State curQid: number = -1;
  @State selectedOptionKey: string = '';
  @State curIsJava: boolean = false;
  @State curOriginal: string = '';
  @State curImages: string[] = [];
  @State failedImages: string[] = [];
  @State curExamples: QuestionExample[] = [];
  @State analysisImages: string[] = [];
  @State mathInputs: string[] = [];
  @State mathFeedback: string[] = [];
  @State showOriginal: boolean = false;
  @State javaCode: string = '';
  @State javaMainClass: string = 'Solution';
  @State judgePending: boolean = false;
  @State judgeMessage: string = '';
  private practiceRequestId: number = 0;
  private predictionPending: boolean = false;
  private syncedInteractionCount: number = 0;

  // Agent 聚焦信号
  @StorageProp('focusSeq') @Watch('onFocusRequest') focusSeq: number = 0;
  private pendingFocusId: number = -1;
  private lastHandledSeq: number = 0;
  @StorageProp('practiceSeq') @Watch('onPracticeRequest') practiceSeq: number = 0;
  private lastPracticeSeq: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  // -------------------------------------------------------------------------
  // 数据加载
  // -------------------------------------------------------------------------
  async loadData(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const raw = await context.resourceManager.getRawFileContent(AppState.isDsa() ? 'graph_dsa.json' : 'graph.json');
      if (this.courseEpoch !== AppState.getCourseEpoch()) { return; }
      const text = util.TextDecoder.create('utf-8').decodeToString(raw);
      const data = JSON.parse(text) as Record<string, Object>;
      const rawNodes = data['nodes'] as RawNode[];
      this.sourceEdges = data['edges'] as RawEdge[];

      const moduleColors = new Map<string, string>();
      let colorIdx = 0;

      this.allNodes = [];
      this.nodeMap = new Map<number, KcNode>();
      for (const rn of rawNodes) {
        let color = moduleColors.get(rn.module);
        if (color === undefined) {
          color = MODULE_PALETTE[colorIdx % MODULE_PALETTE.length];
          moduleColors.set(rn.module, color);
          colorIdx++;
        }
        const node: KcNode = {
          id: rn.id,
          name: rn.name,
          depth: rn.depth,
          isLeaf: rn.is_leaf,
          parent: rn.parent,
          module: rn.module,
          nQuestions: rn.n_questions,
          color: color,
          x: 0,
          y: 0,
          radius: GRAPH_CONFIG.baseNodeRadius,
          children: []
        };
        this.allNodes.push(node);
        this.nodeMap.set(node.id, node);
      }

      // 建 children / roots
      this.rootIds = [];
      for (const nd of this.allNodes) {
        if (nd.parent >= 0) {
          const p = this.nodeMap.get(nd.parent);
          if (p !== undefined) {
            p.children.push(nd.id);
          }
        } else {
          this.rootIds.push(nd.id);
        }
      }

      this.refreshVisible();
      this.layout();
      this.dataReady = true;
      this.tryDraw();
    } catch (e) {
      console.error('[KnowledgeGraph] 数据加载失败:', (e as Error).message);
    }
  }

  // 当前可见节点：顶层 -> 8 根；钻取 -> 焦点 + 直接子节点
  private visibleNodes(): KcNode[] {
    if (this.focusId < 0) {
      const roots: KcNode[] = [];
      for (const r of this.rootIds) {
        const nd = this.nodeMap.get(r);
        if (nd !== undefined) {
          roots.push(nd);
        }
      }
      return roots;
    }
    const focus = this.nodeMap.get(this.focusId);
    if (focus === undefined) {
      return [];
    }
    const arr: KcNode[] = [focus];
    for (const c of focus.children) {
      const nd = this.nodeMap.get(c);
      if (nd !== undefined) {
        arr.push(nd);
      }
    }
    return arr;
  }

  private visibleEdges(): GraphEdge[] {
    if (this.focusId < 0) {
      return [];
    }
    const focus = this.nodeMap.get(this.focusId);
    if (focus === undefined) {
      return [];
    }
    const edges: GraphEdge[] = [];
    for (const c of focus.children) {
      edges.push({ source: this.focusId, target: c, type: 'IS_A' });
    }
    if (AppState.isDsa()) {
      const visible = new Set<number>(this.visibleNodes().map((node: KcNode) => node.id));
      for (const edge of this.sourceEdges) {
        if (edge.type !== 'IS_A' && visible.has(edge.source) && visible.has(edge.target)) {
          edges.push({ source: edge.source, target: edge.target, type: edge.type });
        }
      }
    }
    return edges;
  }

  private refreshVisible(): void {
    this.nodes = this.visibleNodes();
    this.edges = this.visibleEdges();
  }

  // 径向布局：顶层根一圈；钻取时焦点在中心、子节点一圈
  private layout(): void {
    if (this.focusId < 0) {
      const n = this.nodes.length;
      const R = GRAPH_CONFIG.layoutRadius;
      for (let i = 0; i < n; i++) {
        const ang = -Math.PI / 2 + i * 2 * Math.PI / n;
        this.nodes[i].x = Math.cos(ang) * R;
        this.nodes[i].y = Math.sin(ang) * R;
      }
      return;
    }
    const focus = this.nodeMap.get(this.focusId);
    if (focus !== undefined) {
      focus.x = 0;
      focus.y = 0;
    }
    const children: KcNode[] = [];
    for (const nd of this.nodes) {
      if (nd.id !== this.focusId) {
        children.push(nd);
      }
    }
    const n = children.length;
    const R = GRAPH_CONFIG.layoutRadius;
    for (let i = 0; i < n; i++) {
      const ang = -Math.PI / 2 + i * 2 * Math.PI / n;
      children[i].x = Math.cos(ang) * R;
      children[i].y = Math.sin(ang) * R;
    }
  }

  // -------------------------------------------------------------------------
  // 导航
  // -------------------------------------------------------------------------
  private drillInto(id: number): void {
    this.focusId = id;
    this.clearSelection();
    this.refreshVisible();
    this.layout();
    this.viewInitialized = false;
    this.tryDraw();
  }

  private goBack(): void {
    if (this.focusId < 0) {
      return;
    }
    const nd = this.nodeMap.get(this.focusId);
    this.focusId = nd !== undefined ? nd.parent : -1;
    this.clearSelection();
    this.refreshVisible();
    this.layout();
    this.viewInitialized = false;
    this.tryDraw();
  }

  private currentFocusName(): string {
    if (this.focusId < 0) {
      return AppState.courseName() + ' · 全部模块';
    }
    const nd = this.nodeMap.get(this.focusId);
    return nd !== undefined ? nd.name : '';
  }

  private centerOn(x: number, y: number): void {
    this.zoom = 1.6;
    this.tx = this.canvasW / 2 - x * this.zoom;
    this.ty = this.canvasH / 2 - y * this.zoom;
  }

  private tryDraw(): void {
    this.tryApplyPractice();
    if (this.dataReady && this.canvasReady && this.canvasW > 0 && this.canvasH > 0) {
      if (!this.viewInitialized) {
        this.fitToView();
        this.viewInitialized = true;
      }
      this.draw();
      this.tryApplyFocus();
    }
  }

  private fitToView(): void {
    if (this.nodes.length === 0) {
      return;
    }
    let minX = Infinity;
    let maxX = -Infinity;
    let minY = Infinity;
    let maxY = -Infinity;
    for (const nd of this.nodes) {
      minX = Math.min(minX, nd.x - nd.radius);
      maxX = Math.max(maxX, nd.x + nd.radius);
      minY = Math.min(minY, nd.y - nd.radius);
      maxY = Math.max(maxY, nd.y + nd.radius);
    }
    const cw = maxX - minX;
    const ch = maxY - minY;
    if (cw <= 0 || ch <= 0) {
      return;
    }
    const s = Math.min(this.canvasW / cw, this.canvasH / ch) * 0.85;
    this.zoom = clamp(s, GRAPH_CONFIG.minScale, GRAPH_CONFIG.maxScale);
    this.tx = (this.canvasW - (minX + maxX) * this.zoom) / 2;
    this.ty = (this.canvasH - (minY + maxY) * this.zoom) / 2;
  }

  private applyBounds(): void {
    if (this.nodes.length === 0) {
      return;
    }
    let minX = Infinity;
    let maxX = -Infinity;
    let minY = Infinity;
    let maxY = -Infinity;
    for (const nd of this.nodes) {
      minX = Math.min(minX, nd.x - nd.radius);
      maxX = Math.max(maxX, nd.x + nd.radius);
      minY = Math.min(minY, nd.y - nd.radius);
      maxY = Math.max(maxY, nd.y + nd.radius);
    }
    const margin = GRAPH_CONFIG.boundaryMargin;
    const contentW = (maxX - minX) * this.zoom;
    const contentH = (maxY - minY) * this.zoom;
    if (contentW <= this.canvasW) {
      this.tx = (this.canvasW - contentW) / 2 - minX * this.zoom;
    } else {
      const left = minX * this.zoom + this.tx;
      const right = maxX * this.zoom + this.tx;
      if (left > margin) {
        this.tx -= (left - margin);
      }
      if (right < this.canvasW - margin) {
        this.tx += (this.canvasW - margin - right);
      }
    }
    if (contentH <= this.canvasH) {
      this.ty = (this.canvasH - contentH) / 2 - minY * this.zoom;
    } else {
      const top = minY * this.zoom + this.ty;
      const bottom = maxY * this.zoom + this.ty;
      if (top > margin) {
        this.ty -= (top - margin);
      }
      if (bottom < this.canvasH - margin) {
        this.ty += (this.canvasH - margin - bottom);
      }
    }
  }

  private zoomAt(cx: number, cy: number, factor: number): void {
    const newScale = clamp(this.zoom * factor, GRAPH_CONFIG.minScale, GRAPH_CONFIG.maxScale);
    const f = newScale / this.zoom;
    this.tx = cx - (cx - this.tx) * f;
    this.ty = cy - (cy - this.ty) * f;
    this.zoom = newScale;
    this.applyBounds();
    this.draw();
  }

  private hitTest(sx: number, sy: number): number {
    const gx = (sx - this.tx) / this.zoom;
    const gy = (sy - this.ty) / this.zoom;
    let best = -1;
    let bestDist = Infinity;
    for (const nd of this.nodes) {
      const dx = nd.x - gx;
      const dy = nd.y - gy;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d <= nd.radius + 6 && d < bestDist) {
        best = nd.id;
        bestDist = d;
      }
    }
    return best;
  }

  // -------------------------------------------------------------------------
  // 选中
  // -------------------------------------------------------------------------
  private findAncestors(id: number): Set<number> {
    const result = new Set<number>();
    let cur = this.nodeMap.get(id);
    while (cur !== undefined && cur.parent >= 0) {
      result.add(cur.parent);
      cur = this.nodeMap.get(cur.parent);
    }
    return result;
  }

  private selectNode(id: number): void {
    this.selectedId = id;
    const nd = this.nodeMap.get(id);
    if (nd !== undefined) {
      this.selectedName = nd.name;
      this.selectedModule = nd.module;
      this.selectedNQuestions = nd.nQuestions;
      this.selectedPrereq = this.prereqChain(id);
    }
    this.highlightSet = this.findAncestors(id);
    this.highlightSet.add(id);
    this.draw();
  }

  private clearSelection(): void {
    this.selectedId = -1;
    this.selectedName = '';
    this.selectedModule = '';
    this.selectedPrereq = '';
    this.selectedNQuestions = 0;
    this.highlightSet = new Set<number>();
  }

  private prereqChain(id: number): string {
    if (AppState.isDsa()) {
      const parents: string[] = [];
      for (const edge of this.sourceEdges) {
        if (edge.type === 'PREREQUISITE_OF' && edge.target === id) {
          const node = this.nodeMap.get(edge.source);
          if (node !== undefined) { parents.push(node.name); }
        }
      }
      return parents.join('、');
    }
    const names: string[] = [];
    let cur = this.nodeMap.get(id);
    while (cur !== undefined && cur.parent >= 0) {
      const p = this.nodeMap.get(cur.parent);
      if (p !== undefined) {
        names.push(p.name);
      }
      cur = p;
    }
    if (names.length === 0) {
      return '';
    }
    const reversed: string[] = [];
    for (let i = names.length - 1; i >= 0; i--) {
      reversed.push(names[i]);
    }
    return reversed.join(' → ');
  }

  // Agent 聚焦：钻到该节点的父级并高亮居中
  private onFocusRequest(): void {
    this.tryApplyFocus();
  }

  private tryApplyFocus(): void {
    if (!this.dataReady || !this.canvasReady || this.canvasW <= 0) {
      return;
    }
    // 只要 focusSeq 比已处理的序号大，就说明有新的聚焦请求
    if (this.focusSeq > this.lastHandledSeq) {
      const id = AppStorage.get<number>('focusKcId') ?? -1;
      if (id >= 0) {
        this.pendingFocusId = id;
      }
      this.lastHandledSeq = this.focusSeq;
    }
    if (this.pendingFocusId < 0) {
      return;
    }
    const id = this.pendingFocusId;
    this.pendingFocusId = -1;
    const nd = this.nodeMap.get(id);
    if (nd === undefined) {
      return;
    }
    this.focusId = nd.parent >= 0 ? nd.parent : -1;
    this.refreshVisible();
    this.layout();
    this.selectNode(id);
    const target = this.nodeMap.get(id);
    if (target !== undefined) {
      this.centerOn(target.x, target.y);
    }
    this.viewInitialized = true;
    this.draw();
  }

  // -------------------------------------------------------------------------
  // 做题
  // -------------------------------------------------------------------------
  private onPracticeRequest(): void {
    this.tryApplyPractice();
  }

  private tryApplyPractice(): void {
    if (!this.dataReady || this.practiceSeq <= this.lastPracticeSeq) {
      return;
    }
    this.lastPracticeSeq = this.practiceSeq;
    const kc = AppStorage.get<number>('practiceKcId') ?? -1;
    const qid = AppStorage.get<number>('practiceQid') ?? -1;
    if (kc < 0) {
      return;
    }
    AppStorage.setOrCreate('focusKcId', kc);
    AppStorage.setOrCreate('focusSeq', (AppStorage.get<number>('focusSeq') ?? 0) + 1);
    this.openPractice(kc, qid);
  }

  private openPractice(id: number, qid: number = -1): void {
    const nd = this.nodeMap.get(id);
    if (nd === undefined || nd.nQuestions <= 0) {
      promptAction.showToast({ message: '该知识点暂无题目', duration: 2000 });
      return;
    }
    this.practiceLoading = true;
    this.practiceOpen = true;
    this.practiceQuestions = [];
    this.practiceKcName = nd.name;
    this.practiceIndex = 0;
    this.practiceRevealed = false;
    this.practiceJudged = false;
    const requestId = ++this.practiceRequestId;
    PracticeService.getQuestions(id).then((qs: QuestionItem[]) => {
      if (requestId !== this.practiceRequestId || !this.practiceOpen) {
        return;
      }
      let first = 0;
      if (qid >= 0) {
        first = qs.findIndex((question: QuestionItem) => question.qid === qid);
        if (first < 0) {
          throw new Error('未找到题号 ' + qid);
        }
      } else {
        const tasks = AppState.getTaskQuestions(id);
        const pending = tasks.find((question) => !question.answered);
        if (pending !== undefined) {
          first = qs.findIndex((question: QuestionItem) => question.qid === pending.qid);
        }
      }
      this.practiceQuestions = qs.slice(first).concat(qs.slice(0, first));
      this.syncCurrentQuestion();
      this.practiceLoading = false;
    }).catch((e: Error) => {
      if (requestId !== this.practiceRequestId) {
        return;
      }
      this.practiceLoading = false;
      this.practiceOpen = false;
      promptAction.showToast({ message: '加载题目失败: ' + e.message, duration: 2500 });
    });
  }

  private syncCurrentQuestion(): void {
    this.selectedOptionKey = '';
    this.judgeMessage = '';
    this.judgePending = false;
    this.showOriginal = false;
    if (this.practiceIndex < 0 || this.practiceIndex >= this.practiceQuestions.length) {
      this.curContent = '';
      this.curAnswer = '';
      this.curAnalysis = '';
      this.curOptions = [];
      this.curCorrectKey = '';
      this.curIsChoice = false;
      this.curKc = -1;
      this.curQid = -1;
      return;
    }
    const q = this.practiceQuestions[this.practiceIndex];
    this.curIsJava = q.type === 'java';
    this.curOriginal = q.original_plain ?? q.original ?? '';
    this.curImages = q.images ?? [];
    this.failedImages = [];
    this.curExamples = q.examples ?? [];
    this.analysisImages = [];
    this.mathFeedback = [];
    this.mathInputs = new Array<string>(q.answer_count ?? q.answer.length).fill('');
    if (this.curIsJava) {
      PersistentStorage.persistProp('javaDraft_' + q.qid.toString(), '');
      PersistentStorage.persistProp('javaMainClass_' + q.qid.toString(), 'Solution');
      this.javaCode = AppStorage.get<string>('javaDraft_' + q.qid.toString()) || q.starter_code || '';
      const savedMainClass = AppStorage.get<string>('javaMainClass_' + q.qid.toString());
      this.javaMainClass = savedMainClass === 'Main' ? 'Main' : 'Solution';
    }
    this.curContent = q.stem ?? q.content;
    if (this.curIsJava) { this.curContent = this.curContent.replace(/!\[[^\]]*\]\([^)]+\)/g, ''); }
    this.curAnswer = q.answer.join('、');
    this.curAnalysis = q.analysis;
    this.curCorrectKey = q.answer.length > 0 ? q.answer[0] : '';
    this.curKc = q.kc;
    this.curQid = q.qid;
    const keys = Object.keys(q.options);
    keys.sort();
    const arr: OptionItem[] = [];
    for (let i = 0; i < keys.length; i++) {
      const optionImages = q.option_images ?? {};
      arr.push({ key: keys[i], text: q.options[keys[i]], images: optionImages[keys[i]] ?? [] });
    }
    this.curOptions = arr;
    this.curIsChoice = arr.length > 0;
  }

  private selectJavaMainClass(mainClass: string): void {
    if (!this.curIsJava || this.curQid < 0 || this.judgePending ||
      (mainClass !== 'Solution' && mainClass !== 'Main')) {
      return;
    }
    this.javaMainClass = mainClass;
    AppStorage.setOrCreate('javaMainClass_' + this.curQid.toString(), mainClass);
  }

  private recordAnswer(correct: boolean): void {
    if (this.practiceJudged) {
      return;
    }
    if (this.curKc >= 0 && this.practiceIndex < this.practiceQuestions.length) {
      const question = this.practiceQuestions[this.practiceIndex];
      const progress = AppState.addInteraction(this.curKc, correct ? 1 : 0, question.qid);
      if (progress.planCompleted) {
        promptAction.showToast({ message: '完成任务！整条路径已移入「已完成」', duration: 2500 });
      } else if (progress.taskCompleted) {
        promptAction.showToast({ message: '已完成该任务的全部题目，任务已完成', duration: 2500 });
      }
    }
    this.practiceJudged = true;
    this.practiceCorrect = correct;
    this.refreshMastery();
  }

  private answerOption(optionKey: string): void {
    this.selectedOptionKey = optionKey;
    this.submitMath([optionKey]);
  }

  private imageUrl(url: string): string {
    return url.startsWith('/') ? BACKEND_BASE_URL + url : url;
  }

  private async submitMath(answers: string[]): Promise<void> {
    if (this.judgePending) { return; }
    const epoch = AppState.getCourseEpoch();
    const requestId = this.practiceRequestId;
    const qid = this.curQid;
    this.judgePending = true;
    this.judgeMessage = '正在核对答案…';
    try {
      const result = await BackendService.submitMath(qid, this.curKc, answers);
      if (epoch !== AppState.getCourseEpoch() || requestId !== this.practiceRequestId || qid !== this.curQid) { return; }
      this.judgeMessage = result.detail;
      if (result.graded) {
        this.curAnswer = result.expected.join('；');
        this.curCorrectKey = result.expected[0] ?? '';
        this.curAnalysis = result.analysis;
        this.analysisImages = result.analysis_images;
        this.mathFeedback = result.per_blank.map((correct: boolean, index: number): string =>
          '第 ' + (index + 1) + ' 空：' + (correct ? '正确' : '错误') + '；参考答案：' + result.expected[index]);
        this.recordAnswer(result.correct === 1);
      }
    } catch (e) {
      if (epoch === AppState.getCourseEpoch() && requestId === this.practiceRequestId) {
        this.judgeMessage = (e as Error).message + '\n本次未记录作答。';
      }
    } finally {
      if (epoch === AppState.getCourseEpoch() && requestId === this.practiceRequestId) { this.judgePending = false; }
    }
  }

  private async submitJava(): Promise<void> {
    if (this.judgePending || this.javaCode.trim().length === 0) { return; }
    const epoch = AppState.getCourseEpoch();
    const requestId = this.practiceRequestId;
    const qid = this.curQid;
    this.judgePending = true;
    this.judgeMessage = '正在编译并运行测试…';
    this.practiceJudged = false;
    try {
      const result = await BackendService.submitJava(qid, this.javaCode, this.javaMainClass);
      if (epoch !== AppState.getCourseEpoch() || requestId !== this.practiceRequestId || qid !== this.curQid) { return; }
      const labels: Record<string, string> = {
        'accepted': '全部测试通过', 'wrong_answer': '输出不匹配', 'compile_error': '编译错误',
        'runtime_error': '运行错误', 'time_limit': '运行超时', 'output_limit': '输出过多'
      };
      this.judgeMessage = (labels[result.status] ?? result.status) + '\n通过 ' + result.passed + ' / ' + result.total +
        ' 个测试\n' + result.detail +
        (result.actual.length > 0 ? '\n实际输出：\n' + result.actual : '') +
        (result.expected.length > 0 ? '\n预期输出：\n' + result.expected : '');
      if (result.graded) { this.recordAnswer(result.correct === 1); }
    } catch (e) {
      if (epoch === AppState.getCourseEpoch() && requestId === this.practiceRequestId) {
        this.judgeMessage = (e as Error).message + '\n本次未记录作答，可重新提交。';
      }
    } finally {
      if (epoch === AppState.getCourseEpoch() && requestId === this.practiceRequestId) { this.judgePending = false; }
    }
  }

  private nextQuestion(): void {
    if (!this.practiceJudged) {
      return;
    }
    if (this.practiceIndex + 1 >= this.practiceQuestions.length) {
      this.closePractice();
      return;
    }
    this.practiceIndex++;
    this.practiceRevealed = false;
    this.practiceJudged = false;
    this.syncCurrentQuestion();
  }

  private closePractice(): void {
    this.practiceRequestId++;
    this.practiceOpen = false;
    this.practiceLoading = false;
    this.practiceQuestions = [];
    this.practiceIndex = 0;
    this.practiceRevealed = false;
    this.practiceJudged = false;
    this.refreshMastery();
  }

  private refreshMastery(): void {
    const its: Interaction[] = AppState.getInteractions();
    if (its.length > 0 && !this.predictionPending && its.length !== this.syncedInteractionCount) {
      this.predictionPending = true;
      BackendService.predict(its).then((res) => {
        // 后续已有新作答时，避免旧请求覆盖最新诊断。
        if (this.courseEpoch !== AppState.getCourseEpoch() || its.length !== AppState.interactionCount()) {
          return;
        }
        AppState.setMastery(res.mastery, res.supported_kcs);
        AppState.setWeak(res.weak);
        this.syncedInteractionCount = its.length;
        const mv = (AppStorage.get<number>('masteryVersion') ?? 0) + 1;
        AppStorage.setOrCreate('masteryVersion', mv);
        this.draw();
      }).catch((e: Error) => {
        console.error('[KnowledgeGraph] predict 失败:', e.message);
        promptAction.showToast({ message: '掌握度诊断失败，请检查后端连接后重试', duration: 2500 });
      }).finally(() => {
        this.predictionPending = false;
        if (this.courseEpoch === AppState.getCourseEpoch() && its.length < AppState.interactionCount()) {
          this.refreshMastery();
        }
      });
    }
  }

  private isCorrectOption(key: string): boolean {
    return key === this.curCorrectKey;
  }

  private isSelectedWrong(key: string): boolean {
    if (!this.practiceJudged) {
      return false;
    }
    return !this.isCorrectOption(key);
  }

  // -------------------------------------------------------------------------
  // 绘制
  // -------------------------------------------------------------------------
  private draw(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx = this.ctx;
    const w = this.canvasW;
    const h = this.canvasH;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);
    const scale = this.zoom;
    const sx = (x: number): number => x * scale + this.tx;
    const sy = (y: number): number => y * scale + this.ty;

    let activeNodes: Set<number> | null = null;
    let activeEdges: Set<number> | null = null;
    if (this.selectedId >= 0) {
      const hl = new Set<number>();
      this.highlightSet.forEach((v: number) => {
        hl.add(v);
      });
      activeNodes = hl;
      const hlEdges = new Set<number>();
      for (let i = 0; i < this.edges.length; i++) {
        const e = this.edges[i];
        if (hl.has(e.source) && hl.has(e.target)) {
          hlEdges.add(i);
        }
      }
      activeEdges = hlEdges;
    }

    for (let i = 0; i < this.edges.length; i++) {
      const e = this.edges[i];
      const sn = this.nodeMap.get(e.source);
      const tn = this.nodeMap.get(e.target);
      if (sn === undefined || tn === undefined) {
        continue;
      }
      const dimmed = activeEdges !== null && !activeEdges.has(i);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawEdge(ctx, sn, tn, sx, sy);
    }
    ctx.globalAlpha = 1.0;

    for (const nd of this.nodes) {
      const dimmed = activeNodes !== null && !activeNodes.has(nd.id);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawNode(ctx, nd, sx, sy);
    }
    ctx.globalAlpha = 1.0;

    for (const nd of this.nodes) {
      const dimmed = activeNodes !== null && !activeNodes.has(nd.id);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawNodeLabel(ctx, nd, sx, sy);
    }
    ctx.globalAlpha = 1.0;
  }

  private drawEdge(ctx: CanvasRenderingContext2D, sn: KcNode, tn: KcNode,
    sx: (x: number) => number, sy: (y: number) => number): void {
    const x1 = sx(sn.x);
    const y1 = sy(sn.y);
    const x2 = sx(tn.x);
    const y2 = sy(tn.y);
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len < 0.01) {
      return;
    }
    const ux = dx / len;
    const uy = dy / len;
    const r1 = sn.radius * this.zoom;
    const r2 = tn.radius * this.zoom;
    const bx1 = x1 + ux * r1;
    const by1 = y1 + uy * r1;
    const bx2 = x2 - ux * r2;
    const by2 = y2 - uy * r2;

    ctx.strokeStyle = '#9AA7BD';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.moveTo(bx1, by1);
    ctx.lineTo(bx2, by2);
    ctx.stroke();
    this.drawArrow(ctx, bx2, by2, ux, uy);
  }

  private drawArrow(ctx: CanvasRenderingContext2D, x: number, y: number, dirX: number, dirY: number): void {
    const size = 6;
    const a = Math.atan2(dirY, dirX);
    const spread = Math.PI / 6;
    ctx.strokeStyle = '#9AA7BD';
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - Math.cos(a - spread) * size, y - Math.sin(a - spread) * size);
    ctx.moveTo(x, y);
    ctx.lineTo(x - Math.cos(a + spread) * size, y - Math.sin(a + spread) * size);
    ctx.stroke();
  }

  private drawNode(ctx: CanvasRenderingContext2D, nd: KcNode,
    sx: (x: number) => number, sy: (y: number) => number): void {
    const x = sx(nd.x);
    const y = sy(nd.y);
    const r = nd.radius * this.zoom;

    if (nd.id === this.selectedId) {
      ctx.beginPath();
      ctx.arc(x, y, r + 5, 0, 2 * Math.PI);
      ctx.fillStyle = '#4A90D9';
      ctx.globalAlpha = 0.25;
      ctx.fill();
      ctx.globalAlpha = 1.0;
    }

    const m = AppState.getMastery(nd.id);
    if (AppState.hasMastery() && m > 0) {
      ctx.beginPath();
      ctx.arc(x, y, r + 3, 0, 2 * Math.PI);
      ctx.strokeStyle = '#E8E8E8';
      ctx.lineWidth = 2.5;
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x, y, r + 3, -Math.PI / 2, -Math.PI / 2 + m * 2 * Math.PI);
      ctx.strokeStyle = m >= 0.6 ? '#7ED321' : (m >= 0.4 ? '#F5A623' : '#E74C3C');
      ctx.lineWidth = 2.5;
      ctx.stroke();
    }

    ctx.beginPath();
    ctx.arc(x, y, r, 0, 2 * Math.PI);
    ctx.fillStyle = nd.color;
    ctx.fill();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = '#FFFFFF';
    ctx.stroke();
  }

  private drawNodeLabel(ctx: CanvasRenderingContext2D, nd: KcNode,
    sx: (x: number) => number, sy: (y: number) => number): void {
    if (this.zoom < 0.5) {
      return;
    }
    const x = sx(nd.x);
    const y = sy(nd.y);
    const r = nd.radius * this.zoom;
    const lines = wrapName(nd.name);
    const maxLineLen = lines.length > 1 ? Math.max(lines[0].length, lines[1].length) : lines[0].length;
    const fontSize = Math.min((1.6 * r) / maxLineLen, 20);
    if (fontSize < 5) {
      return;
    }
    ctx.fillStyle = '#FFFFFF';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${fontSize}vp sans-serif`;
    if (lines.length === 1) {
      ctx.fillText(lines[0], x, y);
    } else {
      const gap = fontSize * 0.3;
      ctx.fillText(lines[0], x, y - fontSize * 0.5 - gap * 0.5);
      ctx.fillText(lines[1], x, y + fontSize * 0.5 + gap * 0.5);
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  build() {
    Stack() {
      Column() {
        this.PageHeader()
        this.GraphArea()
        this.DetailPanel()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      if (this.practiceOpen) {
        this.PracticeModal()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PageHeader() {
    Row() {
      if (this.focusId >= 0) {
        Button('←')
          .width(34)
          .height(34)
          .fontSize(18)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.surface'))
          .borderRadius(17)
          .shadow({ radius: 4, color: '#15000000', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.goBack();
          })
          .margin({ right: 10 })
      }
      Column() {
        Text('知识图谱')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.currentFocusName())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
    }
    .width('90%')
    .height(60)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  GraphArea() {
    Stack() {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.canvasReady = true;
          this.tryDraw();
        })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.pinchStartScale = this.zoom;
                this.pinchStartTx = this.tx;
                this.pinchStartTy = this.ty;
              })
              .onActionUpdate((event: GestureEvent) => {
                const target = clamp(this.pinchStartScale * event.scale, GRAPH_CONFIG.minScale, GRAPH_CONFIG.maxScale);
                const f = target / this.pinchStartScale;
                const cx = event.pinchCenterX;
                const cy = event.pinchCenterY;
                this.zoom = target;
                this.tx = cx - (cx - this.pinchStartTx) * f;
                this.ty = cy - (cy - this.pinchStartTy) * f;
                this.applyBounds();
                this.draw();
              }),
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                this.panStartTx = this.tx;
                this.panStartTy = this.ty;
                this.isPanning = false;
              })
              .onActionUpdate((event: GestureEvent) => {
                if (Math.abs(event.offsetX) > 3 || Math.abs(event.offsetY) > 3) {
                  this.isPanning = true;
                }
                this.tx = this.panStartTx + event.offsetX;
                this.ty = this.panStartTy + event.offsetY;
                this.applyBounds();
                this.draw();
              })
              .onActionEnd(() => {
                this.isPanning = false;
              }),
            TapGesture({ count: 1 })
              .onAction((event: GestureEvent) => {
                if (this.isPanning) {
                  return;
                }
                const finger = event.fingerList[0];
                if (finger !== undefined) {
                  const id = this.hitTest(finger.localX, finger.localY);
                  if (id >= 0) {
                    this.onTapNode(id);
                  } else {
                    this.clearSelection();
                    this.draw();
                  }
                }
              })
          )
        )
    }
    .width('100%')
    .layoutWeight(1)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.canvasW = newValue.width as number;
      this.canvasH = newValue.height as number;
      this.tryDraw();
    })
  }

  private onTapNode(id: number): void {
    if (id === this.focusId) {
      return;
    }
    const nd = this.nodeMap.get(id);
    if (nd === undefined) {
      return;
    }
    if (nd.children.length > 0) {
      this.drillInto(id);
    } else {
      this.selectNode(id);
    }
  }

  @Builder
  DetailPanel() {
    Column() {
      if (this.selectedId < 0) {
        Text('👆 点模块钻取子级 · 点知识点做题')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      } else {
        Row() {
          Text('📖 ' + this.selectedName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text(this.selectedModule)
            .fontSize(11)
            .fontColor($r('app.color.brand'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.brand_tint'))
            .borderRadius(8)
        }
        .width('100%')
        .margin({ bottom: 6 })

        if (this.selectedNQuestions > 0) {
          Text(this.selectedNQuestions + ' 道题')
            .fontSize(12)
            .fontColor($r('app.color.warning'))
            .width('100%')
            .margin({ bottom: 6 })
        }

        if (this.selectedPrereq !== '') {
          Text('前置：' + this.selectedPrereq)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(18)
            .width('100%')
            .margin({ bottom: 10 })
        }

        if (this.selectedNQuestions > 0) {
          Button('开始练习')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .height(44)
            .borderRadius(14)
            .linearGradient({
              angle: 135,
              colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
            })
            .fontColor(Color.White)
            .onClick(() => {
              this.openPractice(this.selectedId);
            })
        }
      }
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: '#15000000',
      offsetX: 0,
      offsetY: -4
    })
    .margin({ bottom: 16 })
  }

  @Builder
  PracticeModal() {
    Column() {
      Row() {
        Text('📝 ' + this.practiceKcName)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('✕')
          .width(32)
          .height(32)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.closePractice();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.practiceLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.brand'))
          .margin({ top: 60 })
      } else if (this.practiceQuestions.length === 0) {
        Text('暂无题目')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 60 })
      } else {
        this.QuestionBody()
      }
    }
    .width('92%')
    .padding(20)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
    .height('84%')
    .shadow({
      radius: 20,
      color: '#30000000',
      offsetX: 0,
      offsetY: 6
    })
  }

  @Builder
  QuestionBody() {
    Scroll() {
      Column() {
        Text(`题号 ${this.curQid} · 第 ${this.practiceIndex + 1} / ${this.practiceQuestions.length} 题`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 10 })

        Text(this.curContent)
          .wordBreak(WordBreak.BREAK_ALL)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .width('100%')
          .margin({ bottom: 16 })

        ForEach(this.curImages, (url: string) => {
            if (!this.failedImages.includes(url)) {
              Image(this.imageUrl(url)).width('100%').height(210).objectFit(ImageFit.Contain)
                .onError(() => { this.failedImages = this.failedImages.concat([url]); })
            } else {
              Text('原题配图暂不可用，请参照输入说明与示例。').fontSize(12).fontColor($r('app.color.text_secondary'))
                .width('100%').margin({ bottom: 12 })
            }
          }, (url: string) => url)
        if (this.curIsJava) {
          Button(this.showOriginal ? '收起英文原文' : '查看英文原文')
            .fontSize(13).height(36).onClick(() => { this.showOriginal = !this.showOriginal; })
          if (this.showOriginal) {
            Text(this.curOriginal).fontSize(13).lineHeight(21).width('100%').wordBreak(WordBreak.BREAK_ALL).margin({ top: 8, bottom: 12 })
          }
          ForEach(this.curExamples, (example: QuestionExample, index: number) => {
            Column({ space: 6 }) {
              Text('示例 ' + (index + 1)).fontSize(14).fontWeight(FontWeight.Medium)
              Text('输入').fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(example.input).fontFamily('monospace').fontSize(13).lineHeight(20)
                .width('100%').wordBreak(WordBreak.BREAK_ALL)
              Text('输出').fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(example.output).fontFamily('monospace').fontSize(13).lineHeight(20)
                .width('100%').wordBreak(WordBreak.BREAK_ALL)
            }.width('100%').padding(12).backgroundColor($r('app.color.surface_subtle'))
              .alignItems(HorizontalAlign.Start).margin({ top: 8, bottom: 8 })
          }, (example: QuestionExample, index: number) => index.toString())
          Text('Java 17 · 从标准输入读取，向标准输出打印结果').fontSize(12).fontColor($r('app.color.text_secondary'))
            .width('100%').margin({ top: 12, bottom: 8 })
          Row({ space: 8 }) {
            Text('入口类').fontSize(13)
            Button('Solution').fontSize(12).height(32)
              .backgroundColor(this.javaMainClass === 'Solution' ? $r('app.color.brand') : $r('app.color.text_secondary'))
              .enabled(!this.judgePending).onClick(() => { this.selectJavaMainClass('Solution'); })
            Button('Main').fontSize(12).height(32)
              .backgroundColor(this.javaMainClass === 'Main' ? $r('app.color.brand') : $r('app.color.text_secondary'))
              .enabled(!this.judgePending).onClick(() => { this.selectJavaMainClass('Main'); })
          }.width('100%').margin({ bottom: 8 })
          TextArea({ text: this.javaCode, placeholder: '在这里编写或粘贴 Java 代码' })
            .width('100%').height(260).fontSize(13).fontFamily('monospace').maxLength(60000)
            .backgroundColor($r('app.color.surface_subtle')).enabled(!this.judgePending)
            .onChange((value: string) => {
              this.javaCode = value;
              AppStorage.setOrCreate('javaDraft_' + this.curQid.toString(), value);
            })
          Button(this.judgePending ? '判题中…' : (this.practiceJudged ? '修改后重新提交' : '提交代码'))
            .width('100%').height(44).margin({ top: 12 })
            .enabled(!this.judgePending && this.javaCode.trim().length > 0)
            .onClick(() => { this.submitJava(); })
          if (this.judgeMessage.length > 0) {
            Text(this.judgeMessage).fontSize(13).lineHeight(21).width('100%').wordBreak(WordBreak.BREAK_ALL).margin({ top: 12 })
          }
          Text('题目来源：UFCG · CC BY 4.0 · DOI 10.5281/zenodo.18136250')
            .fontSize(10).fontColor($r('app.color.text_secondary')).width('100%').margin({ top: 12 })
        } else if (this.curIsChoice) {
          ForEach(this.curOptions, (opt: OptionItem) => {
            Button() {
              Column({ space: 6 }) {
                Text(opt.key + '. ' + opt.text).width('100%').fontSize(14).fontColor($r('app.color.text_primary'))
                  .lineHeight(22).wordBreak(WordBreak.BREAK_ALL)
                ForEach(opt.images, (url: string) => {
                  Image(this.imageUrl(url)).width('100%').objectFit(ImageFit.Contain)
                }, (url: string) => url)
              }.width('100%').alignItems(HorizontalAlign.Start)
            }
              .width('100%').constraintSize({ minHeight: 48 }).padding(12)
              .margin({ bottom: 8 })
              .borderRadius(12)
              .backgroundColor(
                !this.practiceJudged ? $r('app.color.surface_subtle') :
                  this.isCorrectOption(opt.key) ? $r('app.color.success_tint') :
                    (opt.key === this.selectedOptionKey ? $r('app.color.danger_tint') : $r('app.color.surface_subtle')))
              .opacity(
                !this.practiceJudged || this.isCorrectOption(opt.key) || opt.key === this.selectedOptionKey ? 1 : 0.4)
              .enabled(!this.practiceJudged && !this.judgePending)
              .onClick(() => {
                this.answerOption(opt.key);
              })
          }, (opt: OptionItem) => opt.key)
        } else {
          Text('按题目顺序填写，共 ' + this.mathInputs.length + ' 空')
            .width('100%').fontSize(13).fontColor($r('app.color.text_secondary')).wordBreak(WordBreak.BREAK_ALL)
            .margin({ bottom: 8 })
          ForEach(this.mathInputs, (value: string, index: number) => {
            TextInput({ text: value, placeholder: '第 ' + (index + 1) + ' 空' })
              .width('100%').height(46).margin({ bottom: 10 }).maxLength(500)
              .enabled(!this.judgePending && !this.practiceJudged)
              .onChange((text: string) => {
                const values = this.mathInputs.slice();
                values[index] = text;
                this.mathInputs = values;
              })
          }, (value: string, index: number) => index.toString())
          if (!this.practiceJudged) {
            Button(this.judgePending ? '核对中…' : '提交答案')
              .width('100%').height(44).enabled(!this.judgePending && this.mathInputs.every((value: string) => value.trim().length > 0))
              .onClick(() => { this.submitMath(this.mathInputs.slice()); })
          }
        }

        if (!this.curIsJava && this.judgeMessage.length > 0) {
          Text(this.judgeMessage).width('100%').fontSize(13).lineHeight(21)
            .wordBreak(WordBreak.BREAK_ALL).margin({ top: 8 })
        }

        if (this.practiceJudged) {
          Text(this.practiceCorrect ? '✅ 回答正确' : '❌ 回答错误')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.practiceCorrect ? $r('app.color.success') : $r('app.color.danger'))
            .width('100%')
            .margin({ top: 8, bottom: 4 })

          if (!this.curIsJava) {
            ForEach(this.mathFeedback, (feedback: string) => {
              Text(feedback).width('100%').fontSize(13).lineHeight(21).wordBreak(WordBreak.BREAK_ALL)
            }, (feedback: string, index: number) => index.toString())
          }
          Text(this.curIsJava ? '判题结果已记录，学习建议将结合本次作答更新。' : '解析：' + this.curAnalysis)
            .wordBreak(WordBreak.BREAK_ALL)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .width('100%')
            .margin({ bottom: 12 })

          ForEach(this.analysisImages, (url: string) => {
            Image(this.imageUrl(url)).width('100%').objectFit(ImageFit.Contain)
          }, (url: string) => url)
          Button(this.practiceIndex + 1 >= this.practiceQuestions.length ? '完成' : '下一题')
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
            .onClick(() => {
              this.nextQuestion();
            })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // 手势临时状态
  private pinchStartScale: number = 1;
  private pinchStartTx: number = 0;
  private pinchStartTy: number = 0;
  private panStartTx: number = 0;
  private panStartTy: number = 0;
  private isPanning: boolean = false;
}
