// Run after an ArkTS build: node scripts/test-agent-suggestions.cjs <typescript-module>
// Execute the actual compiler-generated Agent methods and suggestion buttons.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = path.join(__dirname, '..');
const storage = new Map();
const properties = new Map();
const buttons = [];
const toasts = [];
const requests = [];
const replies = [];
const texts = [];
const symbols = [];

const AppStorage = {
  get: key => storage.get(key),
  setOrCreate(key, value) {
    storage.set(key, value);
    for (const property of properties.get(key) || []) property.set(value);
  }
};
class Property {
  constructor(value, owner, name) { this.value = value; this.owner = owner; this.name = name; }
  get() { return this.value; }
  set(value) {
    if (Object.is(this.value, value)) return;
    this.value = value;
    this.owner.watches.get(this.name)?.call(this.owner);
  }
}
class ViewPU {
  constructor() { this.watches = new Map(); }
  declareWatch(name, callback) { this.watches.set(name, callback); }
  createStorageProp(key, value, name) {
    const property = new Property(storage.get(key) ?? value, this, name);
    properties.set(key, (properties.get(key) || []).concat(property));
    return property;
  }
  observeComponentCreation2(callback) { callback(0, true); }
  ifElseBranchUpdateFunction(_id, callback) { callback(); }
  forEachUpdateFunction(_id, items, callback) { items.forEach(callback); }
}
const noopUI = () => new Proxy({}, { get: () => () => {} });
const enums = new Proxy({}, { get: (_, key) => key });
const ui = {
  ViewPU, AppStorage,
  ObservedPropertySimplePU: Property, ObservedPropertyObjectPU: Property,
  Scroller: class { scrollEdge() {} },
  Row: noopUI(), Column: noopUI(), Stack: noopUI(), Circle: noopUI(), Span: noopUI(),
  Text: new Proxy({}, { get: (_, key) => key === 'create' ? text => texts.push(text) : () => {} }),
  SymbolGlyph: new Proxy({}, { get: (_, key) => key === 'create' ? symbol => symbols.push(symbol) : () => {} }),
  If: noopUI(), ForEach: noopUI(), Flex: noopUI(),
  Button: new Proxy({}, {
    get: (_, key) => key === 'createWithLabel' ? label => buttons.push(label) : () => {}
  }),
  Color: enums, FontWeight: enums, FlexAlign: enums, FlexWrap: enums,
  TextDecorationType: enums, Edge: enums, WordBreak: enums, HorizontalAlign: enums
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
const { AppState } = load(path.join(root, 'entry/src/main/ets/model/AppState.ets'), { AppStorage });
const { displayText } = load(path.join(root, 'entry/src/main/ets/utils/TextFormat.ets'), {});
const { requestReplan } = load(path.join(root, 'entry/src/main/ets/utils/TabSwitch.ets'), { AppStorage });
const { AgentChat } = load(path.join(root,
  'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/components/AgentChat.ts'), {
  ...ui,
  require: name => {
    if (name.includes('/model/AppState')) return { AppState };
    if (name.includes('/utils/TabSwitch')) return { switchTab() {} };
    if (name.includes('/utils/PlanActions')) return { cancelCurrentPlan() {} };
    if (name.includes('/utils/TextFormat')) return { displayText };
    if (name === '@ohos:promptAction') return { default: { showToast: toast => toasts.push(toast) } };
    if (name.includes('/services/BackendService')) return {
      BackendService: {
        async chat(interactions, intake, messages) {
          requests.push({ interactions, intake, messages });
          const reply = replies.shift();
          if (reply instanceof Error) throw reply;
          if (reply === undefined) throw new Error('Missing test reply');
          return await reply;
        }
      }
    };
    throw new Error('Unexpected dependency: ' + name);
  }
});
const agent = new AgentChat(undefined, {});
const message = id => agent.messages.find(item => item.id === id);
const flush = () => new Promise(resolve => setImmediate(resolve));

async function main() {
  AppState.setIntakeDone(true);
  agent.aboutToAppear();
  const label = '（本内容由ai生成）';
  function checkLabel(msg, expected) {
    texts.length = 0;
    agent.AgentMessage(msg);
    assert.equal(texts.filter(text => text === label).length, expected ? 1 : 0);
  }
  checkLabel(agent.messages[0], false);
  const originalPlan = [{ kc: 0, name: '数组', mastery: 0.2 }];
  replies.push({ content: '建议 A', weak: originalPlan });
  await agent.runChat('生成建议 A', true);
  const a = agent.messages.find(item => item.isSuggestion);
  checkLabel(a, true);
  assert.equal(a.content, '建议 A', 'the disclosure is display-only and must not enter model history');
  assert.ok(agent.buildHistory().every(item => !item.content.includes(label)));
  originalPlan[0].name = '后续改变';
  replies.push({ content: '解释一下原因', weak: [] });
  await agent.runChat('为什么这样安排', false);
  checkLabel(agent.messages.at(-1), true);
  texts.length = 0;
  agent.UserMessage(agent.messages.find(item => item.role === 'user'));
  assert.ok(!texts.includes(label), 'user messages have no AI disclosure');
  assert.ok(symbols.length >= 2 && symbols.every(symbol => typeof symbol.id === 'number'),
    'both avatars use compiler-resolved system symbols');
  buttons.length = 0;
  agent.AgentMessage(message(a.id));
  assert.deepEqual(buttons, ['✓ 接受', '✕ 不接受'], 'an older suggestion must keep its action buttons');
  assert.equal(message(a.id).plan[0].name, '数组', 'each suggestion needs its own immutable plan snapshot');

  replies.push({ content: '建议 B', weak: [{ kc: 1, name: '链表', mastery: 0.3 }] });
  await agent.runChat('生成建议 B', true);
  const b = agent.messages.filter(item => item.isSuggestion)[1];
  agent.acceptSuggestion(a.id);
  checkLabel(message(a.id), true);
  assert.equal(AppState.getPlan()[0].kc, 0, 'accepting an older suggestion must use that suggestion');
  assert.equal(message(a.id).suggestionState, 'accepted');
  assert.equal(message(b.id).suggestionState, 'pending');
  agent.acceptSuggestion(b.id);
  assert.equal(AppState.getPlan()[0].kc, 0, 'another suggestion must not overwrite the active path');
  const oldId = AppState.getActivePlanId();
  assert.equal(AppState.cancelPlan(oldId), true);
  assert.equal(message(a.id).suggestionState, 'cancelled');
  agent.acceptSuggestion(b.id);
  assert.equal(AppState.getPlan()[0].kc, 1);
  assert.equal(message(b.id).suggestionState, 'accepted');
  AppState.registerTaskQuestions(AppState.getActivePlanId(), 1, [10]);
  AppState.addInteraction(1, 1, 10);
  assert.equal(message(b.id).suggestionState, 'completed');

  // Replanning while a normal response is pending should wait, then use current learning data.
  let finishChat;
  replies.push(new Promise(resolve => { finishChat = resolve; }));
  const normal = agent.runChat('继续解释', false);
  const before = requests.length;
  replies.push({ content: '新路径建议', weak: [{ kc: 2, name: '树', mastery: 0.4 }] });
  requestReplan('数组 → 链表');
  assert.equal(requests.length, before);
  finishChat({ content: '解释回复', weak: [] });
  await normal;
  await flush();
  assert.equal(requests.length, before + 1);
  assert.ok(requests.at(-1).messages.at(-1).content.includes('数组 → 链表'));
  assert.equal(requests.at(-1).interactions.length, AppState.interactionCount());
  const regenerated = agent.messages.filter(item => item.isSuggestion).at(-1);
  assert.equal(regenerated.suggestionState, 'pending');
  assert.equal(AppState.hasPlan(), false, 'a regenerated suggestion needs acceptance before it starts');
  agent.acceptSuggestion(regenerated.id);
  assert.equal(AppState.getPlan()[0].kc, 2);

  AppState.cancelPlan(AppState.getActivePlanId());
  const count = AppState.questionCount();
  replies.push(new Error('request timeout'));
  requestReplan('树');
  await flush();
  assert.equal(AppState.hasPlan(), false);
  assert.equal(AppState.questionCount(), count);
  assert.equal(agent.isLoading, false);
  assert.ok(agent.messages.at(-1).content.includes('request timeout'));
  checkLabel(agent.messages.at(-1), false);

  replies.push({ content: '可忽略建议', weak: [{ kc: 3, name: '图', mastery: 0.4 }] });
  await agent.runChat('生成另一条建议', true);
  const ignored = agent.messages.filter(item => item.isSuggestion).at(-1);
  agent.rejectSuggestion(ignored.id);
  agent.acceptSuggestion(ignored.id);
  assert.equal(message(ignored.id).suggestionState, 'rejected');
  assert.equal(AppState.hasPlan(), false);
  // Reload pre-upgrade records, including old greeting, user message, reply and local error.
  const legacy = JSON.parse(JSON.stringify(agent.messages));
  legacy.forEach(msg => delete msg.isAiGenerated);
  storage.set('chat_' + agent.courseId, JSON.stringify(legacy));
  const restored = new AgentChat(undefined, {});
  restored.onReplanRequest = () => {};
  restored.aboutToAppear();
  for (const msg of restored.messages) {
    const generated = msg.role === 'agent' && msg.id !== 0 && !msg.content.startsWith('⚠️');
    assert.equal(msg.isAiGenerated, generated);
    if (msg.role === 'agent') checkLabel(msg, generated);
  }
  restored.aboutToDisappear();
  restored.aboutToAppear();
  for (const msg of restored.messages.filter(msg => msg.role === 'agent')) checkLabel(msg, msg.isAiGenerated);
  console.log('PASS: normal and legacy AI replies show one disclosure; greetings, errors and user messages do not; history stays clean.');
  console.log('PASS: old suggestion buttons persist, each accepts its own path, and cancellation/completion update message status.');
  console.log('PASS: replanning queues behind a response, uses current records, waits for acceptance, and preserves data on failure.');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
