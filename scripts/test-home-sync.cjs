// Run after an ArkTS build: node scripts/test-home-sync.cjs <typescript-module>
// Exercise the compiler-generated homepage rendering callbacks with observable
// property stubs. This catches values captured once by a nonreactive @Builder.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');

let currentNode;
const storage = new Map();
const storageProps = new Map();
const AppStorage = {
  setOrCreate(key, value) {
    storage.set(key, value);
    for (const property of storageProps.get(key) || []) property.set(value);
  },
  get: key => storage.get(key)
};

function load(file, globals) {
  const context = { exports: {}, ...globals, require: name => {
    if (name.includes('/utils/AdaptiveLayout')) return load(path.join(__dirname, '../entry/src/main/ets/utils/AdaptiveLayout.ets'), {});
    return globals.require(name);
  }};
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText;
  vm.runInNewContext(code, context);
  return context.exports;
}

function render(node, initial = false) {
  const previous = currentNode;
  currentNode = node;
  try { node.callback(0, initial); } finally { currentNode = previous; }
}

class ObservableProperty {
  constructor(value, owner, name) {
    this.value = value;
    this.owner = owner;
    this.name = name;
    this.nodes = new Set();
  }
  get() {
    if (currentNode) this.nodes.add(currentNode);
    return this.value;
  }
  set(value) {
    if (Object.is(this.value, value)) return;
    this.value = value;
    const watcher = this.owner.watches.get(this.name);
    if (watcher) watcher.call(this.owner);
    for (const node of this.nodes) render(node);
  }
  reset(value) { this.set(value); }
}

class ViewPU {
  constructor() { this.watches = new Map(); this.nodes = []; }
  declareWatch(name, callback) { this.watches.set(name, callback); }
  createStorageProp(key, initial, name) {
    const property = new ObservableProperty(storage.get(key) ?? initial, this, name);
    storageProps.set(key, (storageProps.get(key) || []).concat(property));
    return property;
  }
  observeComponentCreation2(callback) {
    const node = { callback };
    this.nodes.push(node);
    render(node, true);
  }
}

const noopUI = () => new Proxy({}, { get: () => () => {} });
const ui = {
  ViewPU,
  ObservedPropertySimplePU: ObservableProperty,
  ObservedPropertyObjectPU: ObservableProperty,
  SynchedPropertySimpleOneWayPU: ObservableProperty,
  AppStorage,
  Column: noopUI(), Row: noopUI(), Stack: noopUI(),
  Circle: new Proxy({}, {
    get: (_, name) => name === 'strokeDashArray' ? value => { currentNode.arc = value[0]; } : () => {}
  }),
  Text: new Proxy({}, {
    get: (_, name) => name === 'create' ? value => { currentNode.text = String(value); } : () => {}
  }),
  Progress: new Proxy({}, {get: (_, name) => name === 'create' ? value => { currentNode.progress = value.value; } : () => {}}),
  ProgressType: { Ring: 0 },
  Color: { White: '#fff' }, FontWeight: { Bold: 700 },
  FlexAlign: { SpaceBetween: 0 }, LineCapStyle: { Round: 0 },
  makeBuilderParameterProxy: (_name, bindings) => new Proxy({}, {
    get: (_, property) => typeof bindings[property] === 'function' ? bindings[property]() : bindings[property]
  })
};

const root = path.join(__dirname, '..');
const { AppState } = load(path.join(root, 'entry/src/main/ets/model/AppState.ets'), { AppStorage });
const generated = path.join(root,
  'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/components/Index.ts');
const { Index } = load(generated, {
  ...ui,
  require: name => {
    if (name.includes('/model/AppState')) return { AppState };
    if (name.includes('/utils/TabSwitch')) return { switchTab() {} };
    throw new Error('Unexpected dependency: ' + name);
  }
});
const home = new Index(undefined, { isActive: true });
home.aboutToAppear();
home.StatsSection();
const values = () => home.nodes.filter(node => node.text !== undefined).map(node => node.text);
assert.ok(values().includes('待诊断'));
assert.ok(values().includes('0 道'));

AppState.addInteraction(0, 1, 0);
assert.ok(values().includes('1 道'), 'homepage should render the new question count without being recreated');
AppState.addInteraction(0, 0, 0);
assert.ok(values().includes('1 道'), 'repeated questions must keep the unique count');
AppState.addInteraction(0, 1, 1);
assert.ok(values().includes('2 道'));
AppState.setMastery([0.2, 0.8]);
assert.ok(values().includes('50%'), 'prediction must update the already rendered mastery card');
assert.ok(home.nodes.some(node => node.progress === 50));
AppState.setMastery([0, 0]);
assert.ok(values().includes('0%'), 'a valid zero prediction must render as diagnosed');

// Returning to the cached homepage must also catch up if a storage update was missed.
home.updateStateVars({ isActive: false });
const subscribers = storageProps.get('appStateVersion');
storageProps.set('appStateVersion', []);
AppState.addInteraction(0, 1, 2);
assert.ok(values().includes('2 道'));
storageProps.set('appStateVersion', subscribers);
home.updateStateVars({ isActive: true });
assert.ok(values().includes('3 道'), 'returning home must read the latest shared data');

async function checkMasterySync() {
  const requests = [];
  const backend = {
    predict(interactions) {
      return new Promise((resolve, reject) => requests.push({ interactions, resolve, reject }));
    }
  };
  const graphFile = path.join(root,
    'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/components/KnowledgeGraph.ts');
  const { KnowledgeGraph } = load(graphFile, {
    ...ui,
    console: { error() {} },
    require: name => {
      if (name.includes('/model/AppState')) return { AppState };
      if (name.includes('/services/BackendService')) return { BackendService: backend };
      if (name.includes('/services/PracticeService')) return { PracticeService: {} };
      if (name === '@ohos:promptAction') return { default: { showToast() {} } };
      if (name === '@ohos:util') return { default: {} };
      throw new Error('Unexpected dependency: ' + name);
    }
  });
  const graph = Object.create(KnowledgeGraph.prototype);
  graph.predictionPending = false;
  graph.courseEpoch = AppState.getCourseEpoch();
  graph.syncedInteractionCount = 0;
  graph.draw = () => {};
  const flush = () => new Promise(resolve => setImmediate(resolve));

  AppState.setMastery([]);
  graph.refreshMastery();
  AppState.addInteraction(0, 1, 3);
  graph.refreshMastery();
  assert.equal(requests.length, 1, 'answers during an in-flight prediction should be combined');
  requests[0].resolve({ mastery: [0.1, 0.1], weak: [] });
  await flush();
  assert.equal(AppState.hasMastery(), false, 'an older prediction must not overwrite newer answers');
  assert.equal(requests.length, 2);
  assert.equal(requests[1].interactions.length, AppState.interactionCount());
  requests[1].resolve({ mastery: [0.2, 0.8], weak: [] });
  await flush();
  assert.ok(values().includes('50%'), 'the latest prediction must render on the existing homepage');

  AppState.addInteraction(0, 1, 4);
  graph.refreshMastery();
  requests[2].reject(new Error('request timeout'));
  await flush();
  assert.ok(values().includes('50%'), 'network failure should retain the last real diagnosis');
  graph.refreshMastery();
  assert.equal(requests.length, 4, 'a failed prediction must allow retry');
  requests[3].resolve({ mastery: [0.3, 0.3], weak: [] });
  await flush();
  assert.ok(values().includes('30%'));
}

checkMasterySync().then(() => {
  console.log('PASS: homepage counts, mastery text and rings update through actual compiled rendering callbacks.');
  console.log('PASS: returning home refreshes cached data; predictions combine new answers and allow retry.');
}).catch(error => {
  console.error(error);
  process.exitCode = 1;
});
