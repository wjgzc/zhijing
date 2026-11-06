// Run after an ArkTS build. Execute the real profile callbacks with a sheet host stub.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || path.join(__dirname, '..');
let nodes = [];
let current;
class Property {
  constructor(value) { this.value = value; }
  get() { return this.value; }
  set(value) { this.value = value; }
}
class ViewPU {
  finalizeConstruction() {}
  declareWatch() {}
  getUIContext() { return { getHostContext: () => ({ filesDir: '/app' }) }; }
  createStorageProp(_key, value) { return new Property(value); }
  observeComponentCreation2(callback) {
    const previous = current;
    current = undefined;
    try { callback(0, true); } finally { current = previous; }
  }
  ifElseBranchUpdateFunction(_id, callback) { callback(); }
  forEachUpdateFunction(_id, values, callback) { values.forEach(callback); }
}
const enums = new Proxy({}, { get: (_, key) => key });
const ui = { ViewPU, ObservedPropertySimplePU: Property, ObservedPropertyObjectPU: Property };
for (const kind of ['Stack','Scroll','Column','Row','Flex','Text','Image','Button','Blank',
  'TextInput','Grid','GridItem','ForEach','If']) {
  ui[kind] = new Proxy({}, { get: (_, method) => (...args) => {
    if (method === 'create' || method === 'createWithLabel') {
      current = { kind, value: args[0], events: {} };
      nodes.push(current);
    } else if (method === 'bindSheet') {
      // Native sheets belong to a host; another binding on that host replaces it.
      current.sheet = { binding: args[0], builder: args[1].builder, options: args[2] };
    } else if (method.startsWith('on')) {
      current.events[method] = args[0];
    }
  }});
}
for (const name of ['Color','FontWeight','FlexDirection','FlexAlign','ItemAlign','HorizontalAlign',
  'GradientDirection','BarState','SheetSize','SheetType','FlexWrap','BorderStyle','ImageFit']) ui[name] = enums;
function load(file, extra = {}) {
  const context = { exports: {}, ...ui, ...extra };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText, context);
  return context.exports;
}
const adaptive = load('entry/src/main/ets/utils/AdaptiveLayout.ets');
const files = new Map();
const handles = new Map();
let nextFd = 0;
const io = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 },
  openSync(name) { const fd = ++nextFd; handles.set(fd, name); return { fd }; },
  writeSync(fd, text) { files.set(handles.get(fd), text); }, fsyncSync() {}, closeSync() {},
  renameSync(from, to) { files.set(to, files.get(from)); files.delete(from); },
  readTextSync(name) { if (!files.has(name)) throw Error('missing'); return files.get(name); },
  accessSync(name) { return files.has(name); }, unlinkSync(name) { files.delete(name); }
};
const profileModule = load('entry/src/main/ets/model/UserProfileStore.ets', {
  require: () => ({ fileIo: io })
});
const { avatarInitial } = profileModule;
const { ServiceWidget } = load(
  'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/components/ServiceWidget.ts', {
    require(name) {
      if (name.includes('/utils/AdaptiveLayout')) return adaptive;
      if (name.includes('/model/UserProfileStore')) return profileModule;
      if (name.includes('photoAccessHelper')) return { default: {} };
      if (name.includes('promptAction')) return { default: { showToast() {} } };
      if (name.includes('/model/AppState')) return { AppState: {
        getOverview: () => ({ questionCount: 0, overallMastery: 0, hasMastery: false, doneTaskCount: 0 }),
        getPlan: () => []
      } };
      if (name.includes('/utils/TabSwitch')) return {};
      throw new Error('Unexpected import: ' + name);
    }
  });

for (const width of [390, 720, 1120]) {
  files.clear();
  const screen = new ServiceWidget(undefined, {});
  screen.aboutToAppear();
  screen.contentWidth = width;
  for (const method of ['PageHeader','WidgetSmall','WidgetMedium','WidgetLarge']) screen[method] = () => {};
  function render() { nodes = []; screen.initialRender(); }
  function click(label) {
    const button = nodes.find(node => node.kind === 'Button' && node.value === label);
    assert.ok(button, 'Missing button: ' + label);
    button.events.onClick();
  }
  function show(title) {
    render();
    const visible = nodes.filter(node => node.sheet?.binding.value);
    assert.equal(visible.length, 1, `${width}vp: clicking the entry must immediately open its sheet`);
    const sheet = visible[0].sheet;
    assert.equal(sheet.options.title.title, title);
    assert.equal(sheet.options.preferType, width >= 600 ? 'CENTER' : 'BOTTOM');
    sheet.builder();
    return sheet;
  }
  function input(index, value) {
    nodes.filter(node => node.kind === 'TextInput')[index].events.onChange(value);
  }
  function selectGrade(value) {
    nodes.find(node => node.kind === 'Text' && node.value === value && node.events.onClick).events.onClick();
  }
  function closed() {
    render();
    assert.equal(nodes.filter(node => node.sheet?.binding.value).length, 0);
  }

  render();
  click('修改信息');
  show('修改个人信息');
  input(0, '  李同学  '); input(1, '  软件工程  '); selectGrade('大四');
  click('确认修改');
  assert.equal(screen.username, '李同学');
  assert.equal(avatarInitial(screen.username), '李');
  assert.equal(screen.identity, '软件工程');
  assert.equal(screen.grade, '大四');
  closed();

  click('修改信息'); show('修改个人信息');
  assert.equal(screen.editUsername, '');
  assert.equal(screen.editIdentity, '');
  assert.equal(screen.editGrade, '大四');
  input(0, '不应保存'); selectGrade('大一'); click('取消');
  assert.equal(screen.username, '李同学'); assert.equal(screen.grade, '大四');
  closed();

  click('修改信息');
  const dismissed = show('修改个人信息');
  input(0, '关闭后应清空'); dismissed.binding.changeEvent(false);
  closed();
  click('修改信息'); show('修改个人信息');
  assert.equal(screen.editUsername, '');
  assert.equal(screen.editGrade, '大四');
  input(0, '   '); input(1, ''); click('确认修改');
  assert.equal(screen.username, '李同学'); assert.equal(screen.identity, '软件工程');
  closed();

  const avatar = nodes.find(node => node.kind === 'Column' && node.events.onClick);
  assert.ok(avatar, 'Missing avatar entry');
  avatar.events.onClick(); show('选择头像');
  assert.ok(nodes.some(node => node.value === '从相册选照片'));
  assert.ok(nodes.some(node => node.value === '恢复默认头像'));
  click('取消'); closed();
  const restored = new ServiceWidget(undefined, {});
  restored.aboutToAppear();
  assert.equal(restored.username, '李同学');
  assert.equal(restored.identity, '软件工程');
  assert.equal(restored.grade, '大四');
  click('修改信息'); show('修改个人信息'); click('取消'); closed();
  console.log(`PASS ${width}vp: edit opens directly; save, cancel, system dismissal, reopen and avatar selection are independent.`);
}
