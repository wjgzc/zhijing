// Executes real ArkTS compiler output with framework stubs. No visual rendering is simulated.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = path.join(__dirname, '..');
const generated = 'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/';
const storage = new Map();
const callbacks = [];
const calls = [];
const enums = new Proxy({}, { get: (_, key) => key });
const AppStorage = { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) };
class Property {
  constructor(value) { this.value = value; }
  get() { return this.value; }
  set(value) { this.value = value; }
}
class ViewPU {
  static create() {}
  finalizeConstruction() {}
  observeComponentCreation2(callback) { callback(0, true); }
  ifElseBranchUpdateFunction(_id, callback) { callback(); }
  forEachUpdateFunction(_id, items, callback) { items.forEach(callback); }
  createStorageProp(key, value) { return new Property(storage.get(key) ?? value); }
  declareWatch() {}
}
const ui = { ViewPU, AppStorage, ObservedPropertySimplePU: Property,
  ObservedPropertyObjectPU: Property, SynchedPropertySimpleOneWayPU: Property,
  TabsController: class { changeIndex() {} }, Scroller: class {},
  RenderingContextSettings: class {}, CanvasRenderingContext2D: class {},
  PUV2ViewBase: { contextStack: [] } };
for (const name of ['Row','Column','Stack','Scroll','Flex','Canvas','Text','Image','Blank','Button',
  'Tabs','TabContent','If','ForEach','TextArea','LoadingProgress','Divider',
  'Gesture','GestureGroup','PinchGesture','PanGesture','TapGesture']) {
  ui[name] = new Proxy({}, { get: (_, method) => (...args) => {
    calls.push({ name, method, args });
    if (method === 'onAreaChange') callbacks.push({ name, callback: args[0] });
    if (name === 'TabContent' && method === 'create') args[0]();
  }});
}
for (const name of ['FlexDirection','FlexAlign','ItemAlign','VerticalAlign','HorizontalAlign',
  'FontWeight','BarPosition','BarMode','BlurStyle','Color','ButtonType','ButtonStyleMode',
  'HoverEffect','ModifierKey','BarState','GestureMode','GesturePriority','WordBreak']) ui[name] = enums;
ui.BottomTabBarStyle = { of: () => ({ iconStyle() { return this; }, labelStyle() { return this; } }) };
function load(file, extra = {}) {
  let source = fs.readFileSync(path.join(root, file), 'utf8');
  if (file.endsWith('MainPage.ts')) {
    source = source.replace(/(?:registerNamedRoute|ViewStackProcessor\.StartGetAccessRecordingFor)[\s\S]*$/, 'exports.MainPage = MainPage;');
  }
  const context = { exports: {}, ...ui, ...extra };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText, context);
  return context.exports;
}
const adaptive = load('entry/src/main/ets/utils/AdaptiveLayout.ets');
function dependency(name) {
  if (name.includes('/utils/AdaptiveLayout')) return adaptive;
  if (name.includes('/utils/TextFormat')) return load('entry/src/main/ets/utils/TextFormat.ets');
  if (name.includes('/model/AppState')) return { AppState: {
    getCourse: () => 'dsa', getCourseEpoch: () => 1, courseName: () => 'Java 数据结构'
  }};
  if (name.includes('/components/')) {
    const label = name.match(/components\/([^&]+)/)[1];
    return { [label]: class {} };
  }
  return new Proxy({}, { get: () => ({}) });
}
const { MainPage } = load(generated + 'pages/MainPage.ts', { require: dependency });
const page = new MainPage(undefined, {});
page.courseChosen = true;
page.currentIndex = 2;
page.CourseChoice = () => {};
page.SideNavigation = () => {};
page.initialRender();
const resize = callbacks.find(item => item.name === 'Row').callback;
for (const [width, expectedNav, expectedBar] of [[390,0,64],[600,80,0],[800,80,0],[1199,80,0],[1200,200,0],[1600,200,0],[500,0,64]]) {
  resize({}, { width, height: 800 });
  assert.equal(storage.get('contentWidth'), width - expectedNav);
  assert.equal(page.currentIndex, 2, 'resize must retain the selected tab');
  calls.length = 0;
  page.initialRender();
  assert.equal(calls.find(item => item.name === 'Tabs' && item.method === 'barHeight').args[0], expectedBar);
}
console.log('PASS: live window resize selects phone/rail/sidebar layouts and retains the active tab.');

const { KnowledgeGraph } = load(generated + 'components/KnowledgeGraph.ts', { require: dependency });
const graph = new KnowledgeGraph(undefined, {});
graph.contentWidth = 1120;
graph.canvasW = 800; graph.canvasH = 600;
graph.tx = 100; graph.ty = 70; graph.zoom = 1.5;
graph.practiceOpen = true; graph.curQid = 42; graph.javaCode = 'public class Main {}';
graph.applyBounds = () => {};
graph.tryDraw = () => {};
callbacks.length = 0;
graph.GraphArea();
const resizeGraph = callbacks.find(item => item.name === 'Stack').callback;
resizeGraph({}, { width: 400, height: 350 });
assert.equal(graph.tx, -100);
assert.equal(graph.ty, -55);
assert.equal(graph.zoom, 1.5);
assert.equal(graph.practiceOpen, true);
assert.equal(graph.curQid, 42);
assert.equal(graph.javaCode, 'public class Main {}');
resizeGraph({}, { width: 800, height: 600 });
assert.equal(graph.tx, 100); assert.equal(graph.ty, 70);
const axis = calls.find(item => item.name === 'Canvas' && item.method === 'onAxisEvent').args[0];
let zoomArgs;
graph.zoomAt = (...args) => { zoomArgs = args; };
axis({ x: 120, y: 100, getVerticalAxisValue: () => -1 });
assert.deepEqual(zoomArgs, [120, 100, 1.1]);
console.log('PASS: graph resize retains viewport centre, zoom, open question and Java draft; mouse wheel zoom uses pointer location.');

// Check real emitted layouts at either side of the content breakpoint.
for (const [component, builder] of [['KnowledgeGraph','QuestionBody'],['AgentChat','initialRender']]) {
  const module = load(generated + 'components/' + component + '.ts', { require: dependency });
  const instance = new module[component](undefined, {});
  if (component === 'KnowledgeGraph') {
    instance.curIsJava = false; instance.curImages = []; instance.curOptions = [];
    instance.mathInputs = []; instance.practiceJudged = false;
  } else {
    for (const method of ['PageHeader','IntakePanel','IntakeSummary','ChatArea','InputArea']) instance[method] = () => {};
  }
  for (const [width, direction] of [[839,'Column'],[840,'Row'],[520,'Column']]) {
    instance.contentWidth = width;
    calls.length = 0;
    instance[builder]();
    assert.equal(calls.find(item => item.name === 'Flex' && item.method === 'create').args[0].direction, direction);
  }
}
console.log('PASS: actual compiled chat and question workspace switch columns when content space changes.');
