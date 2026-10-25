// Run: node scripts/test-study-state.cjs <path-to-typescript-module>
// Executes the real AppState source with only HarmonyOS AppStorage stubbed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require(process.argv[2] || 'typescript');

const source = fs.readFileSync(path.join(__dirname,
  '../entry/src/main/ets/model/AppState.ets'), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  reportDiagnostics: true
});
assert.equal((compiled.diagnostics || []).length, 0);

function freshState() {
  const updates = [];
  const storage = new Map();
  const context = {
    exports: {},
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => { storage.set(key, value); updates.push({ key, value }); } }
  };
  vm.runInNewContext(compiled.outputText, context);
  return { state: context.exports.AppState, updates };
}

function plan() {
  return [
    { kc: 0, name: '数组', mastery: 0.3 },
    { kc: 1, name: '链表', mastery: 0.4 }
  ];
}

function startPlan(state, items = plan()) {
  const accepted = state.setPlan(items);
  if (accepted) {
    for (const item of items) {
      state.registerTaskQuestions(state.getActivePlanId(), item.kc,
        [item.kc * 10, item.kc * 10 + 1, item.kc * 10 + 2]);
    }
  }
  return accepted;
}

function answerTask(state, kc) {
  const questions = state.getTaskQuestions(kc);
  let progress = { taskCompleted: false, planCompleted: false };
  for (const question of questions) {
    progress = state.addInteraction(kc, 0, question.qid);
  }
  return progress;
}

function loadSource(relativePath, globals) {
  const text = fs.readFileSync(path.join(__dirname, relativePath), 'utf8');
  const output = ts.transpileModule(text, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const context = { exports: {}, ...globals };
  vm.runInNewContext(output, context);
  return context.exports;
}

function practiceService(state, backend) {
  return loadSource('../entry/src/main/ets/services/PracticeService.ets', {
    require: name => {
      if (name === '../model/AppState') return { AppState: state };
      if (name === './BackendService') return { BackendService: backend };
      throw new Error('Unexpected dependency: ' + name);
    }
  }).PracticeService;
}

function planActions(state, dialog, requests, toasts = []) {
  return loadSource('../entry/src/main/ets/utils/PlanActions.ets', {
    console: { error() {} },
    require: name => {
      if (name === '../model/AppState') return { AppState: state };
      if (name === './TabSwitch') return { requestReplan: path => requests.push(path) };
      if (name === '@kit.ArkUI') return {
        promptAction: { showDialog: dialog, showToast: toast => toasts.push(toast) }
      };
      throw new Error('Unexpected dependency: ' + name);
    }
  });
}

test('initial overview remains undiagnosed after answering without a prediction', () => {
  const { state } = freshState();
  assert.equal(state.getOverview().hasMastery, false);
  assert.equal(state.questionCount(), 0);
  state.addInteraction(0, 1, 0);
  assert.equal(state.questionCount(), 1);
  assert.equal(state.getOverview().hasMastery, false);
});

test('switching courses preserves independent answers, predictions, plans and intake', () => {
  const { state } = freshState();
  state.addInteraction(0, 1, 0);
  state.setMastery([0.2, 0.8]);
  state.setIntake('年级', '三年级');
  state.setIntakeDone(true);
  startPlan(state);
  const oldEpoch = state.getCourseEpoch();
  state.switchCourse('dsa');
  assert.equal(state.getCourseEpoch(), oldEpoch + 1);
  assert.equal(state.questionCount(), 0);
  assert.equal(state.hasMastery(), false);
  assert.equal(state.hasPlan(), false);
  assert.equal(state.isIntakeDone(), false);
  state.addInteraction(8, 0, 0);
  const probabilities = Array(96).fill(0.9);
  probabilities[8] = 0.4;
  state.setMastery(probabilities, [8]);
  assert.equal(state.overallMastery(), 40, 'unobserved nodes and modules must not count toward a predicted score');
  assert.equal(state.getInteractions()[0].qid, 0);
  state.switchCourse('math');
  assert.equal(state.questionCount(), 1);
  assert.equal(state.overallMastery(), 50);
  assert.equal(state.hasPlan(), true);
  assert.equal(state.getIntake()['年级'], '三年级');
  assert.equal(state.getInteractions()[0].correct, 1);
  state.switchCourse('dsa');
  assert.equal(state.getInteractions()[0].correct, 0);
  assert.equal(state.overallMastery(), 40);
});

test('late question requests from another course cannot register a new course task', async () => {
  const { state } = freshState();
  startPlan(state, [plan()[0]]);
  let finish;
  const service = practiceService(state, { getQuestions: () => new Promise(resolve => { finish = resolve; }) });
  const old = service.getQuestions(0);
  state.switchCourse('dsa');
  state.setPlan([plan()[0]]);
  finish([{ kc: 0, qid: 0 }]);
  await assert.rejects(old, /课程已切换/);
  assert.equal(state.getTaskQuestions(0).length, 0);
});

test('repeated questions count once while every attempt reaches the model', () => {
  const { state } = freshState();
  state.addInteraction(0, 0, 0);
  state.addInteraction(0, 1, 0);
  state.addInteraction(0, 1, 1552);
  state.addInteraction(1, 1, 1552);
  assert.equal(state.questionCount(), 2);
  assert.equal(state.interactionCount(), 4);
  assert.equal(state.getInteractions()[0].correct, 0);
  assert.equal(state.getInteractions()[1].correct, 1);
  const request = state.getInteractions();
  request.pop();
  assert.equal(state.interactionCount(), 4);
});

test('overall mastery includes every knowledge point and valid zero is diagnosed', () => {
  const { state } = freshState();
  state.setMastery([0.2, 0.8, 1]);
  assert.equal(state.getOverview().overallMastery, 67);
  state.setMastery([0, 0, 0]);
  assert.equal(state.getOverview().hasMastery, true);
  assert.equal(state.overallMastery(), 0);
  state.setMastery([]);
  assert.equal(state.hasMastery(), false);
});

test('a pending path cannot be replaced or archived by completing only part of it', () => {
  const { state } = freshState();
  assert.equal(startPlan(state), true);
  assert.equal(answerTask(state, 0).planCompleted, false);
  assert.equal(state.hasPlan(), true);
  assert.equal(state.doneCount(), 1);
  assert.equal(state.getCompletedPlans().length, 0);
  assert.equal(state.setPlan([{ kc: 5, name: '新知识点', mastery: 0.1 }]), false);
  assert.equal(state.getPlan()[0].kc, 0);
});

test('unassigned questions or repeats do not complete another task', () => {
  const { state } = freshState();
  startPlan(state);
  answerTask(state, 0);
  assert.equal(state.addInteraction(0, 1, 0).taskCompleted, false);
  assert.equal(state.addInteraction(1, 1, 999).taskCompleted, false);
  assert.equal(state.doneCount(), 1);
  assert.equal(state.isDone(1), false);
});

test('last task archives the whole path and clears active tasks in one update', () => {
  const { state, updates } = freshState();
  startPlan(state);
  answerTask(state, 0);
  state.addInteraction(1, 0, 10);
  state.addInteraction(1, 0, 11);
  const before = updates.length;
  assert.equal(state.addInteraction(1, 0, 12).planCompleted, true);
  assert.equal(updates.length, before + 1);
  assert.equal(state.hasPlan(), false);
  assert.equal(state.getOverview().taskCount, 0);
  assert.equal(state.getOverview().doneTaskCount, 0);
  assert.equal(state.getCompletedPlans().length, 1);
  assert.equal(state.getCompletedPlans()[0].items.length, 2);
  assert.equal(state.getCompletedPlans()[0].questions.length, 6);
  state.addInteraction(1, 1, 12);
  assert.equal(state.getCompletedPlans().length, 1);
});

test('a new path starts fresh while the previous completed path stays archived', () => {
  const { state } = freshState();
  startPlan(state);
  answerTask(state, 0);
  answerTask(state, 1);
  const oldId = state.getCompletedPlans()[0].id;
  assert.equal(startPlan(state), true);
  assert.equal(state.isDone(0), false);
  assert.equal(state.getTaskQuestions(0).every(question => !question.answered), true);
  assert.equal(state.getCompletedPlans()[0].id, oldId);
  answerTask(state, 1);
  answerTask(state, 0);
  assert.equal(state.getCompletedPlans().length, 2);
  assert.notEqual(state.getCompletedPlans()[0].id, oldId);
});

test('archive holds completion-time mastery and task completion never changes mastery', () => {
  const { state } = freshState();
  state.setMastery([0.2, 0.8]);
  startPlan(state);
  answerTask(state, 0);
  answerTask(state, 1);
  assert.equal(state.overallMastery(), 50);
  assert.equal(state.getCompletedPlans()[0].diagnosed, true);
  assert.equal(state.getCompletedPlans()[0].items[0].mastery, 0.2);
  state.setMastery([1, 1]);
  assert.equal(state.getCompletedPlans()[0].items[0].mastery, 0.2);
});

test('duplicate knowledge points in a suggestion do not prevent whole-path completion', () => {
  const { state } = freshState();
  assert.equal(state.setPlan([]), false);
  startPlan(state, [plan()[0], plan()[0]]);
  assert.equal(state.getPlan().length, 1);
  assert.equal(state.getTaskQuestions(0).length, 3);
  assert.equal(answerTask(state, 0).planCompleted, true);
  assert.equal(state.getCompletedPlans()[0].diagnosed, false);
});

test('shared overview reports real progress and a fresh session resets all learning data', () => {
  const { state } = freshState();
  state.addInteraction(0, 1, 0);
  state.setMastery([0.2, 0.8]);
  startPlan(state);
  answerTask(state, 0);
  assert.equal(state.getOverview().overallMastery, 50);
  assert.equal(state.getOverview().taskCount, 2);
  assert.equal(state.getOverview().questionCount, 3);
  assert.equal(state.getOverview().doneTaskCount, 1);
  const restarted = freshState().state;
  assert.equal(restarted.questionCount(), 0);
  assert.equal(restarted.hasMastery(), false);
  assert.equal(restarted.hasPlan(), false);
  assert.equal(restarted.getCompletedPlans().length, 0);
});

test('partial practice and reopening never finish a task without all distinct answers', () => {
  const { state } = freshState();
  startPlan(state);
  const planId = state.getActivePlanId();
  state.addInteraction(0, 1, 0);
  state.addInteraction(0, 1, 0);
  state.registerTaskQuestions(planId, 0, [0, 1, 2]);
  assert.equal(state.isDone(0), false);
  assert.equal(state.getTaskQuestions(0).filter(question => question.answered).length, 1);
  assert.equal(state.addInteraction(0, 0, 1).taskCompleted, false);
  assert.equal(state.addInteraction(0, 0, 2).taskCompleted, true);
  assert.equal(state.isDone(0), true);
});

test('historical answers and empty question lists cannot auto-complete a new task', () => {
  const { state } = freshState();
  state.addInteraction(0, 1, 0);
  state.setPlan([plan()[0]]);
  const planId = state.getActivePlanId();
  state.registerTaskQuestions(planId, 0, []);
  assert.equal(state.addInteraction(0, 1, 0).taskCompleted, false);
  state.registerTaskQuestions(planId, 0, [0, 1]);
  assert.equal(state.getTaskQuestions(0).every(question => !question.answered), true);
  assert.equal(state.addInteraction(0, 1, 0).taskCompleted, false);
  assert.equal(state.addInteraction(0, 0, 1).planCompleted, true);
});

test('late question loads from an earlier path cannot register tasks on a new path', () => {
  const { state, updates } = freshState();
  startPlan(state, [plan()[0]]);
  const oldId = state.getActivePlanId();
  answerTask(state, 0);
  state.setPlan([plan()[0]]);
  const before = updates.length;
  state.registerTaskQuestions(oldId, 0, [0, 1, 2]);
  assert.equal(state.getTaskQuestions(0).length, 0);
  assert.equal(updates.length, before);
  assert.equal(state.addInteraction(0, 1, 0).taskCompleted, false);
});

test('path links and practice share fixed question IDs and concurrent requests', async () => {
  const { state } = freshState();
  state.setPlan([plan()[0]]);
  let calls = 0;
  const service = practiceService(state, {
    getQuestions: async () => {
      calls++;
      return [{ kc: 0, qid: 0 }, { kc: 0, qid: 1552 }, { kc: 0, qid: 1581 }];
    }
  });
  const [links, practice] = await Promise.all([service.getQuestions(0), service.getQuestions(0)]);
  assert.equal(calls, 1);
  assert.equal(links[0].qid, 0);
  assert.equal(practice[1].qid, 1552);
  assert.equal(state.getTaskQuestions(0).length, 3);
  assert.equal(state.doneCount(), 0);
  links.pop();
  const reopened = await service.getQuestions(0);
  assert.equal(reopened.length, 3);
  assert.equal(calls, 1);
});

test('failed or empty question loads never complete a task and allow retry', async () => {
  const { state } = freshState();
  state.setPlan([plan()[0]]);
  let calls = 0;
  const service = practiceService(state, {
    getQuestions: async () => {
      calls++;
      if (calls === 1) throw new Error('request timeout');
      if (calls === 2) return [];
      return [{ kc: 0, qid: 0 }];
    }
  });
  await assert.rejects(service.getQuestions(0), /request timeout/);
  await assert.rejects(service.getQuestions(0), /暂无题目/);
  assert.equal(state.getTaskQuestions(0).length, 0);
  assert.equal(state.hasPlan(), true);
  await service.getQuestions(0);
  assert.equal(state.isDone(0), false);
  assert.equal(state.addInteraction(0, 0, 0).planCompleted, true);
});

test('question links retain the exact ID including zero and support repeated clicks', () => {
  const storage = new Map();
  const tabs = [];
  const navigation = loadSource('../entry/src/main/ets/utils/TabSwitch.ets', {
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) }
  });
  navigation.setTabsController({ changeIndex: index => tabs.push(index) });
  navigation.openPractice(0, 0);
  assert.equal(storage.get('practiceKcId'), 0);
  assert.equal(storage.get('practiceQid'), 0);
  assert.equal(storage.get('practiceSeq'), 1);
  navigation.openPractice(0, 0);
  assert.equal(storage.get('practiceSeq'), 2);
  navigation.openPractice(1);
  assert.equal(storage.get('practiceQid'), -1);
  assert.equal(storage.get('practiceKcId'), 1);
  assert.deepEqual(tabs, [1, 1, 1]);
});

test('cancelling an unfinished path preserves mastery, answer history and completed paths', () => {
  const { state } = freshState();
  state.setMastery([0.2, 0.8]);
  startPlan(state);
  answerTask(state, 0);
  answerTask(state, 1);
  const completedId = state.getCompletedPlans()[0].id;
  startPlan(state);
  state.addInteraction(0, 0, 0);
  const count = state.questionCount();
  const attempts = state.interactionCount();
  assert.equal(state.cancelPlan(state.getActivePlanId()), true);
  assert.equal(state.hasPlan(), false);
  assert.equal(state.doneCount(), 0);
  assert.equal(state.getTaskQuestions(0).length, 0);
  assert.equal(state.getCompletedPlans().length, 1);
  assert.equal(state.getCompletedPlans()[0].id, completedId);
  assert.equal(state.questionCount(), count);
  assert.equal(state.interactionCount(), attempts);
  assert.equal(state.overallMastery(), 50);
  assert.equal(state.cancelPlan(0), false);
});

test('keeping the current path or dismissing the dialog never triggers cancellation', async () => {
  const { state } = freshState();
  startPlan(state);
  const id = state.getActivePlanId();
  const requests = [];
  const keep = planActions(state, async () => ({ index: 0 }), requests);
  await keep.cancelCurrentPlan(true);
  assert.equal(state.getActivePlanId(), id);
  const dismiss = planActions(state, async () => { throw new Error('dialog dismissed'); }, requests);
  await dismiss.cancelCurrentPlan(true);
  assert.equal(state.getActivePlanId(), id);
  assert.equal(requests.length, 0);
});

test('confirmed replanning cancels the current path and forwards its context once', async () => {
  const { state } = freshState();
  startPlan(state);
  state.addInteraction(0, 1, 0);
  const requests = [];
  const actions = planActions(state, async () => ({ index: 1 }), requests);
  await actions.cancelCurrentPlan(true);
  assert.equal(state.hasPlan(), false);
  assert.equal(state.getCompletedPlans().length, 0);
  assert.equal(state.questionCount(), 1);
  assert.deepEqual(requests, ['数组 → 链表']);
});

test('a delayed cancellation confirmation cannot cancel a newer path', async () => {
  const { state } = freshState();
  startPlan(state);
  let confirm;
  const requests = [];
  const actions = planActions(state, () => new Promise(resolve => { confirm = resolve; }), requests);
  const pending = actions.cancelCurrentPlan(true);
  answerTask(state, 0);
  answerTask(state, 1);
  startPlan(state);
  const newId = state.getActivePlanId();
  confirm({ index: 1 });
  await pending;
  assert.equal(state.getActivePlanId(), newId);
  assert.equal(requests.length, 0);
});

test('a path can be cancelled without requesting a new suggestion', async () => {
  const { state } = freshState();
  startPlan(state);
  const requests = [];
  const actions = planActions(state, async () => ({ index: 1 }), requests);
  await actions.cancelCurrentPlan();
  assert.equal(state.hasPlan(), false);
  assert.equal(requests.length, 0);
});

test('replanning signals select Agent and preserve the cancelled path context', () => {
  const storage = new Map();
  const tabs = [];
  const navigation = loadSource('../entry/src/main/ets/utils/TabSwitch.ets', {
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) }
  });
  navigation.setTabsController({ changeIndex: index => tabs.push(index) });
  navigation.requestReplan('数组 → 链表');
  assert.equal(storage.get('replanPreviousPath'), '数组 → 链表');
  assert.equal(storage.get('replanSeq'), 1);
  navigation.requestReplan();
  assert.equal(storage.get('replanPreviousPath'), '');
  assert.equal(storage.get('replanSeq'), 2);
  assert.deepEqual(tabs, [2, 2]);
});
