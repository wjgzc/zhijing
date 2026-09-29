import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { switchTab } from '../utils/TabSwitch';

// ============================================================================
// 全局配置：所有灵敏度 / 尺寸 / 布局参数都在这里，改数字即可调节。
// ============================================================================
interface GraphConfig {
  minScale: number;
  maxScale: number;
  zoomSensitivity: number;
  buttonZoomStep: number;
  panSensitivity: number;
  labelFullScale: number;
  labelNameScale: number;
  edgeTextScale: number;
  baseNodeRadius: number;
  weightRadiusDelta: number;
  nodeSpacing: number;
  baseRadius: number;
  edgeCurvature: number;
  arrowSize: number;
  boundaryMargin: number;
  dimAlpha: number;
}

const GRAPH_CONFIG: GraphConfig = {
  // —— 缩放 ——
  minScale: 0.3,            // 最小缩放（缩到最远）
  maxScale: 3.0,            // 最大缩放（放到最近）
  zoomSensitivity: 0.02,    // 双指缩放灵敏度（每单位捏合距离的缩放增量）
  buttonZoomStep: 1.25,     // 加减按钮每次的缩放倍数

  // —— 平移 ——
  panSensitivity: 1.0,      // 平移灵敏度（手指位移 × 该系数）

  // —— 标签 / 文字显示阈值（scale 达到该值才显示）——
  labelFullScale: 1.6,      // ≥ 此值：节点圆内额外显示难度角标
  labelNameScale: 1.2,      // ≥ 此值：节点圆内显示名称（放大到一定程度才显示）
  edgeTextScale: 1.0,       // （已不用：边文字改为仅选中时显示）

  // —— 节点尺寸 ——
  baseNodeRadius: 16,       // 节点基础半径（weight=1 时）
  weightRadiusDelta: 0.5,     // weight 每 +1，半径增量

  // —— 扇区布局 ——
  nodeSpacing: 1.0,         // 相邻节点最小间距（节点直径的倍数，1 = 刚好不重叠）
  baseRadius: 120,          // 基础节点所在圈的半径（越大基础节点分越开）

  // —— 边 ——
  edgeCurvature: 28,        // 平行重复边的弯曲幅度（vp）
  arrowSize: 7,             // 箭头大小

  // —— 平移边界 ——
  boundaryMargin: 60,       // 内容允许拖离边缘的最大余量（vp）

  // —— 选中高亮 ——
  dimAlpha: 0.12,           // 未选中时非邻居节点/边的淡化透明度
};

// ============================================================================
// 类别 → 颜色（按节点类别着色）
// ============================================================================
const CATEGORY_COLORS: Record<string, string> = {
  'Tree': '#4A90D9',        // 树：蓝
  'Graph': '#7B61FF',       // 图：紫
  'Sort': '#F5A623',        // 排序：橙
  'Search': '#2ECC71',      // 查找：绿
  'Stack': '#E74C3C',       // 栈：红
  'Queue': '#1ABC9C',       // 队列：青
  'String': '#E67E22',      // 串：橙红
  'SeqList': '#5D6D7E',     // 顺序表：灰蓝
  'LinkedList': '#34495E',  // 链表：深灰蓝
  'Resource': '#9B59B6',    // 资源：紫红
  'Knowledge': '#8E92A4',   // 兜底：灰
};

// ============================================================================
// 边类型 → 中文标注
// ============================================================================
const EDGE_TYPE_LABELS: Record<string, string> = {
  'PREREQUISITE_OF': '前置',
  'SAME_CHAPTER': '同章节',
  'RELATED_TO': '相关',
  'HAS_RESOURCE': '资源',
};

// ============================================================================
// 数据接口
// ============================================================================
interface RawNode {
  id: number;
  labels: string[];
  properties: Record<string, Object>;
}

interface RawEdge {
  source: number;
  target: number;
  type: string;
  properties: Record<string, Object>;
}

interface GraphNode {
  id: number;
  x: number;          // 布局坐标
  y: number;
  name: string;
  chapter: string;
  difficulty: string;
  weight: number;
  intro: string;
  category: string;
  color: string;
  radius: number;
  neighbors: number[]; // 相邻节点 id
}

interface GraphEdge {
  source: number;
  target: number;
  type: string;
  index: number;      // 该节点对中的第几条（用于平行边弯曲）
  count: number;      // 该节点对共几条
}

// ============================================================================
// 工具函数
// ============================================================================
function clamp(v: number, min: number, max: number): number {
  return v < min ? min : (v > max ? max : v);
}

function getStr(p: Record<string, Object>, key: string): string {
  const v = p[key];
  return v === undefined ? '' : (v as string);
}

function getNum(p: Record<string, Object>, key: string): number {
  const v = p[key];
  return v === undefined ? 0 : (v as number);
}

// 从 labels 里取类别（去掉 "Knowledge" 这个通用标签）
function extractCategory(labels: string[]): string {
  for (const l of labels) {
    if (l !== 'Knowledge') {
      return l;
    }
  }
  return 'Knowledge';
}

function weightToRadius(weight: number): number {
  const w = weight < 1 ? 1 : weight;
  return GRAPH_CONFIG.baseNodeRadius + (w - 1) * GRAPH_CONFIG.weightRadiusDelta;
}

// 判断字符是否为 ASCII（英文/数字/符号）
function isAscii(ch: string): boolean {
  return ch.charCodeAt(0) < 128;
}

// 把节点名称拆成最多两行：优先在连字符/空格/括号拆（英文按边界），
// 其次中英文边界，最后中点。英文连续段不会被拆开（不拆单词内部）。
function wrapName(name: string): string[] {
  const len = name.length;
  if (len <= 4) {
    return [name];
  }
  const lo = Math.floor(len * 0.35);
  const hi = Math.ceil(len * 0.65);

  // 1. 连字符 / 空格 / 括号 / 间隔点
  let split = -1;
  for (let i = hi; i >= lo; i--) {
    const ch = name.charAt(i);
    if (ch === '-' || ch === ' ' || ch === '（' || ch === '(' || ch === '·') {
      split = i;
      break;
    }
  }
  // 2. 中英文边界
  if (split < 0) {
    for (let i = hi; i >= lo; i--) {
      if (i > 0 && isAscii(name.charAt(i - 1)) !== isAscii(name.charAt(i))) {
        split = i;
        break;
      }
    }
  }
  // 3. 中点兜底
  if (split < 0) {
    split = Math.floor(len / 2);
  }
  return [name.substring(0, split), name.substring(split)];
}

// ============================================================================
// 力导向布局（Fruchterman-Reingold 风格，纯力导向）
// ============================================================================
function sectorLayout(nodes: GraphNode[], edges: GraphEdge[]): void {
  const n = nodes.length;
  if (n === 0) {
    return;
  }
  const nodeMap = new Map<number, GraphNode>();
  for (const nd of nodes) {
    nodeMap.set(nd.id, nd);
  }

  // 1. 计算每个节点的"深度" = 最长前置链长度
  //    source 是 target 的前置 → depth(target) = depth(source) + 1
  const depth = new Map<number, number>();
  for (const nd of nodes) {
    depth.set(nd.id, 0);
  }
  let changed = true;
  let guard = 0;
  while (changed && guard < n) {
    changed = false;
    for (const e of edges) {
      if (e.type === 'PREREQUISITE_OF' || e.type === 'HAS_RESOURCE') {
        const sd = depth.get(e.source);
        const td = depth.get(e.target);
        if (sd !== undefined && td !== undefined && sd + 1 > td) {
          depth.set(e.target, sd + 1);
          changed = true;
        }
      }
    }
    guard++;
  }

  // 2. 按类别分组（记录类别出现顺序），Resource 节点单独收集（后面贴到关联节点旁）
  const categories: string[] = [];
  const categoryNodes = new Map<string, GraphNode[]>();
  const resourceNodes: GraphNode[] = [];
  for (const nd of nodes) {
    if (nd.category === 'Resource') {
      resourceNodes.push(nd);
      continue;
    }
    let arr = categoryNodes.get(nd.category);
    if (arr === undefined) {
      arr = [];
      categoryNodes.set(nd.category, arr);
      categories.push(nd.category);
    }
    arr.push(nd);
  }

  // 3. 每个类别占一个角度扇区，扇区内按深度从中心向外排
  const nCat = categories.length;
  const sectorAngle = (2 * Math.PI) / nCat;      // 每个扇区的总角度
  const sectorWidth = sectorAngle * 0.75;        // 扇区内可用角度（留 25% 间隙给相邻扇区）

  const diameter = GRAPH_CONFIG.baseNodeRadius * 2;
  const minSpacing = diameter * GRAPH_CONFIG.nodeSpacing;
  const baseRadius = GRAPH_CONFIG.baseRadius;

  for (let ci = 0; ci < nCat; ci++) {
    const catNodes = categoryNodes.get(categories[ci]);
    if (catNodes === undefined || catNodes.length === 0) {
      continue;
    }
    const sectorCenter = -Math.PI / 2 + ci * sectorAngle;

    // 类别内按深度分组
    const depthGroups = new Map<number, GraphNode[]>();
    let maxD = 0;
    for (const nd of catNodes) {
      const d = depth.get(nd.id) ?? 0;
      let arr = depthGroups.get(d);
      if (arr === undefined) {
        arr = [];
        depthGroups.set(d, arr);
      }
      arr.push(nd);
      if (d > maxD) {
        maxD = d;
      }
    }

    // 计算每层半径：保证同层弧向间距 ≥ minSpacing，且随深度单调递增（径向间距 ≥ minSpacing）
    const layerRadius = new Map<number, number>();
    let prevRadius = baseRadius - minSpacing;
    for (let d = 0; d <= maxD; d++) {
      const layer = depthGroups.get(d);
      if (layer === undefined || layer.length === 0) {
        continue;
      }
      const count = layer.length;
      const required = count > 1 ? ((count - 1) * minSpacing) / sectorWidth : 0;
      const ideal = baseRadius + d * minSpacing;
      const r = Math.max(ideal, required, prevRadius + minSpacing);
      layerRadius.set(d, r);
      prevRadius = r;
    }

    // 放置节点
    for (let d = 0; d <= maxD; d++) {
      const layer = depthGroups.get(d);
      if (layer === undefined || layer.length === 0) {
        continue;
      }
      const radius = layerRadius.get(d) ?? baseRadius;
      const count = layer.length;
      for (let i = 0; i < count; i++) {
        const nd = layer[i];
        let angle = sectorCenter;
        if (count > 1) {
          const t = i / (count - 1) - 0.5;   // -0.5 ~ 0.5，对称分布在扇区中心两侧
          angle = sectorCenter + t * sectorWidth;
        }
        nd.x = Math.cos(angle) * radius;
        nd.y = Math.sin(angle) * radius;
      }
    }
  }

  // 4. Resource 节点在关联知识节点附近找空位放置（不与其他节点重叠）
  const gap = diameter * 0.4;
  for (const rn of resourceNodes) {
    let sourceId = -1;
    for (const e of edges) {
      if (e.type === 'HAS_RESOURCE' && e.target === rn.id) {
        sourceId = e.source;
        break;
      }
    }
    if (sourceId < 0) {
      continue;
    }
    const sn = nodeMap.get(sourceId);
    if (sn === undefined) {
      continue;
    }

    const baseDist = sn.radius + rn.radius + gap;
    const baseAngle = Math.atan2(sn.y, sn.x);
    let placed = false;

    // 从近到远、8 个方向找空位
    for (let dstep = 0; dstep < 3 && !placed; dstep++) {
      const dist = baseDist + dstep * gap;
      for (let k = 0; k < 8 && !placed; k++) {
        const angle = baseAngle + k * Math.PI / 4;
        const cx = sn.x + Math.cos(angle) * dist;
        const cy = sn.y + Math.sin(angle) * dist;
        let free = true;
        for (const other of nodes) {
          if (other.id === rn.id || other.category === 'Resource') {
            continue;
          }
          const ox = other.x - cx;
          const oy = other.y - cy;
          const od = Math.sqrt(ox * ox + oy * oy);
          if (od < other.radius + rn.radius + gap) {
            free = false;
            break;
          }
        }
        if (free) {
          rn.x = cx;
          rn.y = cy;
          placed = true;
        }
      }
    }

    // 兜底：找不到空位就放知识节点外侧
    if (!placed) {
      const dx = sn.x;
      const dy = sn.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 0.01) {
        rn.x = sn.x;
        rn.y = sn.y + baseDist;
      } else {
        rn.x = sn.x + (dx / dist) * baseDist;
        rn.y = sn.y + (dy / dist) * baseDist;
      }
    }
  }
}

// 计算每个节点的邻居列表
function buildNeighbors(nodes: GraphNode[], edges: GraphEdge[]): void {
  const map = new Map<number, Set<number>>();
  for (const nd of nodes) {
    map.set(nd.id, new Set<number>());
  }
  for (const e of edges) {
    const s = map.get(e.source);
    const t = map.get(e.target);
    if (s !== undefined) {
      s.add(e.target);
    }
    if (t !== undefined) {
      t.add(e.source);
    }
  }
  for (const nd of nodes) {
    const set = map.get(nd.id);
    nd.neighbors = [];
    if (set !== undefined) {
      set.forEach((v: number) => {
        nd.neighbors.push(v);
      });
    }
  }
}

// 给平行边（同 source-target 对）赋序号，用于弯曲绘制
function assignEdgeCurves(edges: GraphEdge[]): void {
  const pairCount = new Map<string, number>();
  const pairKey = (a: number, b: number): string => a < b ? `${a}_${b}` : `${b}_${a}`;
  for (const e of edges) {
    const key = pairKey(e.source, e.target);
    const c = pairCount.get(key);
    pairCount.set(key, c === undefined ? 1 : c + 1);
  }
  const pairIndex = new Map<string, number>();
  for (const e of edges) {
    const key = pairKey(e.source, e.target);
    const idx = pairIndex.get(key);
    const cur = idx === undefined ? 0 : idx;
    e.index = cur;
    e.count = pairCount.get(key) ?? 1;
    pairIndex.set(key, cur + 1);
  }
}

// ============================================================================
// 组件
// ============================================================================
@Component
export struct KnowledgeGraph {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 视图变换
  private zoom: number = 1;
  private tx: number = 0;
  private ty: number = 0;
  private viewInitialized: boolean = false;

  // 画布尺寸
  private canvasW: number = 0;
  private canvasH: number = 0;

  // 数据
  private nodes: GraphNode[] = [];
  private edges: GraphEdge[] = [];
  private nodeMap: Map<number, GraphNode> = new Map();
  private dataReady: boolean = false;
  private canvasReady: boolean = false;

  // 手势临时状态
  private pinchStartScale: number = 1;
  private pinchStartTx: number = 0;
  private pinchStartTy: number = 0;
  private panStartTx: number = 0;
  private panStartTy: number = 0;
  private isPanning: boolean = false;

  // 选中状态（响应式，驱动详情面板）
  @State selectedId: number = -1;
  @State selectedName: string = '';
  @State selectedDifficulty: string = '';
  @State selectedChapter: string = '';
  @State selectedIntro: string = '';
  @State selectedCategory: string = '';
  private highlightSet: Set<number> = new Set();

  aboutToAppear(): void {
    this.loadData();
  }

  // -------------------------------------------------------------------------
  // 数据加载：读 rawfile → 解析 → 布局 → 邻居 → 准备绘制
  // -------------------------------------------------------------------------
  async loadData(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const raw = await context.resourceManager.getRawFileContent('graph.json');
      const text = util.TextDecoder.create('utf-8').decodeToString(raw);
      const data = JSON.parse(text) as Record<string, Object>;
      const rawNodes = data['nodes'] as RawNode[];
      const rawEdges = data['edges'] as RawEdge[];

      this.nodes = [];
      this.nodeMap = new Map<number, GraphNode>();
      for (const rn of rawNodes) {
        const p = rn.properties;
        const category = extractCategory(rn.labels);
        const weight = getNum(p, 'weight');
        const node: GraphNode = {
          id: rn.id,
          x: 0,
          y: 0,
          name: getStr(p, 'name'),
          chapter: getStr(p, 'chapter'),
          difficulty: getStr(p, 'difficulty'),
          weight: weight,
          intro: getStr(p, 'introduction'),
          category: category,
          color: CATEGORY_COLORS[category] ?? '#8E92A4',
          radius: weightToRadius(weight),
          neighbors: []
        };
        this.nodes.push(node);
        this.nodeMap.set(node.id, node);
      }

      this.edges = [];
      for (const re of rawEdges) {
        const edge: GraphEdge = {
          source: re.source,
          target: re.target,
          type: re.type,
          index: 0,
          count: 1
        };
        this.edges.push(edge);
      }

      // 布局 + 邻居 + 平行边处理
      sectorLayout(this.nodes, this.edges);
      buildNeighbors(this.nodes, this.edges);
      assignEdgeCurves(this.edges);

      this.dataReady = true;
      this.tryDraw();
    } catch (e) {
      console.error('[KnowledgeGraph] 数据加载失败:', (e as Error).message);
    }
  }

  // 数据与画布都就绪时，初始化视图并绘制
  private tryDraw(): void {
    if (this.dataReady && this.canvasReady && this.canvasW > 0 && this.canvasH > 0) {
      if (!this.viewInitialized) {
        this.fitToView();
        this.viewInitialized = true;
      }
      this.draw();
    }
  }

  // 初始视图：让整个图适应画布并居中
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
    const s = Math.min(this.canvasW / cw, this.canvasH / ch) * 0.9;
    this.zoom = clamp(s, GRAPH_CONFIG.minScale, GRAPH_CONFIG.maxScale);
    this.tx = (this.canvasW - (minX + maxX) * this.zoom) / 2;
    this.ty = (this.canvasH - (minY + maxY) * this.zoom) / 2;
  }

  // -------------------------------------------------------------------------
  // 平移边界：内容不大时可拖出，但不允许拖得看不见
  // -------------------------------------------------------------------------
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

  // -------------------------------------------------------------------------
  // 缩放（围绕指定屏幕坐标点）
  // -------------------------------------------------------------------------
  private zoomAt(cx: number, cy: number, factor: number): void {
    const newScale = clamp(this.zoom * factor, GRAPH_CONFIG.minScale, GRAPH_CONFIG.maxScale);
    const f = newScale / this.zoom;
    this.tx = cx - (cx - this.tx) * f;
    this.ty = cy - (cy - this.ty) * f;
    this.zoom = newScale;
    this.applyBounds();
    this.draw();
  }

  // -------------------------------------------------------------------------
  // 命中检测：屏幕坐标反变换到图坐标，找最近节点
  // -------------------------------------------------------------------------
  private hitTest(sx: number, sy: number): number {
    const gx = (sx - this.tx) / this.zoom;
    const gy = (sy - this.ty) / this.zoom;
    let best = -1;
    let bestDist = Infinity;
    for (const nd of this.nodes) {
      const dx = nd.x - gx;
      const dy = nd.y - gy;
      const d = Math.sqrt(dx * dx + dy * dy);
      // 命中半径取节点半径 + 一点余量
      if (d <= nd.radius + 6 && d < bestDist) {
        best = nd.id;
        bestDist = d;
      }
    }
    return best;
  }

  // -------------------------------------------------------------------------
  // 选中节点
  // -------------------------------------------------------------------------
  private selectNode(id: number): void {
    this.selectedId = id;
    const nd = this.nodeMap.get(id);
    if (nd !== undefined) {
      this.selectedName = nd.name;
      this.selectedDifficulty = nd.difficulty;
      this.selectedChapter = nd.chapter;
      this.selectedIntro = nd.intro;
      this.selectedCategory = nd.category;
    }
    // 高亮集合 = 点击节点 + 其全部前置（递归追溯）
    this.highlightSet = this.findPrerequisites(id);
    this.highlightSet.add(id);
    this.draw();
  }

  // 清除选中，恢复原始展示
  private clearSelection(): void {
    this.selectedId = -1;
    this.selectedName = '';
    this.selectedDifficulty = '';
    this.selectedChapter = '';
    this.selectedIntro = '';
    this.selectedCategory = '';
    this.highlightSet = new Set<number>();
    this.draw();
  }

  // 递归找出所有前置节点（沿 PREREQUISITE_OF 边反向 target→source）
  private findPrerequisites(id: number): Set<number> {
    const result = new Set<number>();
    const stack: number[] = [];
    stack.push(id);
    while (stack.length > 0) {
      const cur = stack.pop();
      if (cur === undefined) {
        continue;
      }
      for (const e of this.edges) {
        if (e.type === 'PREREQUISITE_OF' && e.target === cur) {
          if (!result.has(e.source)) {
            result.add(e.source);
            stack.push(e.source);
          }
        }
      }
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // 跳转到 Agent 页（Tab index 2），纯跳转
  // -------------------------------------------------------------------------
  private goToAgent(): void {
    switchTab(2);
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

    // 选中集合（用前置链高亮集合）
    let activeNodes: Set<number> | null = null;
    let activeEdges: Set<number> | null = null;
    if (this.selectedId >= 0) {
      const hl = new Set<number>();
      for (const v of this.highlightSet) {
        hl.add(v);
      }
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

    // 1. 画边
    for (let i = 0; i < this.edges.length; i++) {
      const e = this.edges[i];
      const sn = this.nodeMap.get(e.source);
      const tn = this.nodeMap.get(e.target);
      if (sn === undefined || tn === undefined) {
        continue;
      }
      const dimmed = activeEdges !== null && !activeEdges.has(i);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawEdge(ctx, sn, tn, e, sx, sy);
    }
    ctx.globalAlpha = 1.0;

    // 2. 画节点
    for (const nd of this.nodes) {
      const dimmed = activeNodes !== null && !activeNodes.has(nd.id);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawNode(ctx, nd, sx, sy);
    }
    ctx.globalAlpha = 1.0;

    // 3. 画节点标签（按缩放分级）
    for (const nd of this.nodes) {
      const dimmed = activeNodes !== null && !activeNodes.has(nd.id);
      ctx.globalAlpha = dimmed ? GRAPH_CONFIG.dimAlpha : 1.0;
      this.drawNodeLabel(ctx, nd, sx, sy);
    }
    ctx.globalAlpha = 1.0;

    // 4. 画边文字（仅选中时显示高亮边的标注）
    if (this.selectedId >= 0 && activeEdges !== null) {
      for (let i = 0; i < this.edges.length; i++) {
        if (!activeEdges.has(i)) {
          continue;
        }
        const e = this.edges[i];
        const sn = this.nodeMap.get(e.source);
        const tn = this.nodeMap.get(e.target);
        if (sn === undefined || tn === undefined) {
          continue;
        }
        this.drawEdgeLabel(ctx, sn, tn, e, sx, sy);
      }
    }
  }

  // 画单条边（含箭头 / 线型 / 平行边弯曲）
  private drawEdge(ctx: CanvasRenderingContext2D, sn: GraphNode, tn: GraphNode, e: GraphEdge,
    sx: (x: number) => number, sy: (y: number) => number): void {
    const x1 = sx(sn.x);
    const y1 = sy(sn.y);
    const x2 = sx(tn.x);
    const y2 = sy(tn.y);

    // 根据边类型定颜色 / 线型
    let color = '#C7CDD9';
    let dashed = false;
    let arrow = false;
    if (e.type === 'PREREQUISITE_OF') {
      color = '#9AA7BD';
      arrow = true;
    } else if (e.type === 'SAME_CHAPTER') {
      color = '#C7CDD9';
      dashed = true;
    } else if (e.type === 'RELATED_TO') {
      color = '#D8DDE6';
    } else if (e.type === 'HAS_RESOURCE') {
      color = '#C39BD3';
      arrow = true;
    }

    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.setLineDash(dashed ? [6, 5] : []);

    // 计算起点/终点（缩到节点边界）
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

    // 平行边弯曲
    let tx1 = bx1;
    let ty1 = by1;
    let tx2 = bx2;
    let ty2 = by2;
    let ctrlX = 0;
    let ctrlY = 0;
    if (e.count > 1) {
      const off = (e.index - (e.count - 1) / 2) * GRAPH_CONFIG.edgeCurvature;
      const nx = -uy;
      const ny = ux;
      const mx = (bx1 + bx2) / 2;
      const my = (by1 + by2) / 2;
      ctrlX = mx + nx * off;
      ctrlY = my + ny * off;
      ctx.beginPath();
      ctx.moveTo(bx1, by1);
      ctx.quadraticCurveTo(ctrlX, ctrlY, bx2, by2);
      ctx.stroke();
      // 箭头方向取曲线末端切线
      tx2 = bx2 - ctrlX;
      ty2 = by2 - ctrlY;
      const tl = Math.sqrt(tx2 * tx2 + ty2 * ty2);
      if (tl < 0.01) {
        tx2 = ux;
        ty2 = uy;
      } else {
        tx2 = tx2 / tl;
        ty2 = ty2 / tl;
      }
    } else {
      ctx.beginPath();
      ctx.moveTo(bx1, by1);
      ctx.lineTo(bx2, by2);
      ctx.stroke();
      tx2 = ux;
      ty2 = uy;
    }

    ctx.setLineDash([]);

    // 箭头
    if (arrow) {
      this.drawArrow(ctx, bx2, by2, tx2, ty2);
    }
  }

  // 画箭头
  private drawArrow(ctx: CanvasRenderingContext2D, x: number, y: number, dirX: number, dirY: number): void {
    const size = GRAPH_CONFIG.arrowSize;
    const a = Math.atan2(dirY, dirX);
    const spread = Math.PI / 6;
    const ax = x - Math.cos(a - spread) * size;
    const ay = y - Math.sin(a - spread) * size;
    const bx = x - Math.cos(a + spread) * size;
    const by = y - Math.sin(a + spread) * size;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(ax, ay);
    ctx.moveTo(x, y);
    ctx.lineTo(bx, by);
    ctx.stroke();
  }

  // 画节点（圆形）
  private drawNode(ctx: CanvasRenderingContext2D, nd: GraphNode,
    sx: (x: number) => number, sy: (y: number) => number): void {
    const x = sx(nd.x);
    const y = sy(nd.y);
    const r = nd.radius * this.zoom;

    // 选中节点加一个高亮外环
    if (nd.id === this.selectedId) {
      ctx.beginPath();
      ctx.arc(x, y, r + 5, 0, 2 * Math.PI);
      ctx.fillStyle = '#4A90D9';
      ctx.globalAlpha = 0.25;
      ctx.fill();
      ctx.globalAlpha = 1.0;
    }

    ctx.beginPath();
    ctx.arc(x, y, r, 0, 2 * Math.PI);
    ctx.fillStyle = nd.color;
    ctx.fill();

    // 描边
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = '#FFFFFF';
    ctx.stroke();
  }

  // 画节点标签（放节点圆内，缩小时不显示，放大显示，字号按字数自动缩小）
  private drawNodeLabel(ctx: CanvasRenderingContext2D, nd: GraphNode,
    sx: (x: number) => number, sy: (y: number) => number): void {
    if (this.zoom < GRAPH_CONFIG.labelNameScale) {
      return;
    }
    const x = sx(nd.x);
    const y = sy(nd.y);
    const r = nd.radius * this.zoom;

    // 名称太长时拆成两行，按最长行字数算字号
    const lines = wrapName(nd.name);
    const maxLineLen = lines.length > 1 ? Math.max(lines[0].length, lines[1].length) : lines[0].length;
    const fontSize = Math.min((1.7 * r) / maxLineLen, 14);
    if (fontSize < 5) {
      return;  // 缩放不够、字太小就不显示
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

    // 难度角标：放大到足够时显示在圆内下方（两行时省略，避免挤）
    if (lines.length === 1 && this.zoom >= GRAPH_CONFIG.labelFullScale && nd.difficulty !== '' && r >= 22) {
      ctx.font = `${Math.max(6, fontSize * 0.55)}vp sans-serif`;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.fillText(nd.difficulty, x, y + fontSize * 0.68);
    }
  }

  // 画边文字
  private drawEdgeLabel(ctx: CanvasRenderingContext2D, sn: GraphNode, tn: GraphNode, e: GraphEdge,
    sx: (x: number) => number, sy: (y: number) => number): void {
    const label = EDGE_TYPE_LABELS[e.type];
    if (label === undefined) {
      return;
    }
    const x1 = sx(sn.x);
    const y1 = sy(sn.y);
    const x2 = sx(tn.x);
    const y2 = sy(tn.y);

    // 中点（弯曲时取曲线中点）
    let mx = (x1 + x2) / 2;
    let my = (y1 + y2) / 2;
    if (e.count > 1) {
      const dx = x2 - x1;
      const dy = y2 - y1;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len > 0.01) {
        const ux = dx / len;
        const uy = dy / len;
        const nx = -uy;
        const ny = ux;
        const off = (e.index - (e.count - 1) / 2) * GRAPH_CONFIG.edgeCurvature;
        mx += nx * off * 0.6;
        my += ny * off * 0.6;
      }
    }

    ctx.fillStyle = '#8E92A4';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${Math.max(7, 8 * this.zoom)}vp sans-serif`;
    ctx.fillText(label, mx, my);
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  build() {
    Column() {
      this.PageHeader()
      this.GraphArea()
      this.DetailPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  PageHeader() {
    Row() {
      Column() {
        Text('知识图谱')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
        Text('数据结构 · 点击节点查看详情')
          .fontSize(13)
          .fontColor('#8E92A4')
      }
      .margin({ left: 12 })
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
                this.tx = this.panStartTx + event.offsetX * GRAPH_CONFIG.panSensitivity;
                this.ty = this.panStartTy + event.offsetY * GRAPH_CONFIG.panSensitivity;
                this.applyBounds();
                this.draw();
              })
              .onActionEnd(() => {
                this.isPanning = false;  // 平移结束后复位,恢复后续的点击选中
              }),
            TapGesture({ count: 1 })
              .onAction((event: GestureEvent) => {
                if (this.isPanning) {
                  return;  // 刚发生了平移，不当作点击，保持选中状态不变
                }
                const finger = event.fingerList[0];
                if (finger !== undefined) {
                  const id = this.hitTest(finger.localX, finger.localY);
                  if (id >= 0) {
                    this.selectNode(id);
                  } else {
                    this.clearSelection();
                  }
                }
              })
          )
        )

      // 缩放按钮（右下角）
      Column({ space: 10 }) {
        Button('+')
          .width(44)
          .height(44)
          .fontSize(22)
          .fontColor('#4A90D9')
          .backgroundColor(Color.White)
          .borderRadius(22)
          .shadow({ radius: 6, color: '#20000000', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.zoomAt(this.canvasW / 2, this.canvasH / 2, GRAPH_CONFIG.buttonZoomStep);
          })
        Button('−')
          .width(44)
          .height(44)
          .fontSize(22)
          .fontColor('#4A90D9')
          .backgroundColor(Color.White)
          .borderRadius(22)
          .shadow({ radius: 6, color: '#20000000', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.zoomAt(this.canvasW / 2, this.canvasH / 2, 1 / GRAPH_CONFIG.buttonZoomStep);
          })
      }
      .position({ x: '90%', y: '82%' })
    }
    .width('100%')
    .layoutWeight(1)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.canvasW = newValue.width as number;
      this.canvasH = newValue.height as number;
      this.tryDraw();
    })
  }

  @Builder
  DetailPanel() {
    Column() {
      if (this.selectedId < 0) {
        Text('👆 点击图谱中的节点查看详情')
          .fontSize(14)
          .fontColor('#8E92A4')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      } else {
        Row() {
          Text('📖 ' + this.selectedName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .layoutWeight(1)

          if (this.selectedCategory !== '') {
            Text(this.selectedCategory)
              .fontSize(11)
              .fontColor('#4A90D9')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#EAF2FB')
              .borderRadius(8)
          }
        }
        .width('100%')
        .margin({ bottom: 6 })

        Row({ space: 8 }) {
          if (this.selectedDifficulty !== '') {
            Text('难度 ' + this.selectedDifficulty)
              .fontSize(12)
              .fontColor('#F5A623')
          }
          if (this.selectedChapter !== '') {
            Text(this.selectedChapter)
              .fontSize(12)
              .fontColor('#8E92A4')
          }
        }
        .width('100%')
        .margin({ bottom: 10 })

        Text(this.selectedIntro !== '' ? this.selectedIntro : '暂无简介')
          .fontSize(13)
          .fontColor('#8E92A4')
          .lineHeight(20)
          .width('100%')
          .margin({ bottom: 16 })

        Button('开始学习')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .height(44)
          .borderRadius(14)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
          .fontColor(Color.White)
          .onClick(() => {
            this.goToAgent();
          })
      }
    }
    .width('90%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: '#15000000',
      offsetX: 0,
      offsetY: -4
    })
    .margin({ bottom: 80 })
  }
}
