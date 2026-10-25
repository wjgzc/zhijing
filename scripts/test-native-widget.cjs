// Real plan/bridge/ability code, with OS form service and atomic file storage stubbed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = path.join(__dirname, '..');
const storage = new Map();
const AppStorage = {get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value)};
const PersistentStorage = {persistProp(key, value) {if (!storage.has(key)) storage.set(key, value);}};
function load(file, dependencies = {}, extra = {}) {
  const context = {exports:{}, AppStorage, PersistentStorage, console, ...extra,
    require(name) {
      const key = Object.keys(dependencies).find(key => name === key || name.includes(key));
      if (key) return dependencies[key];
      throw Error('Unexpected dependency: ' + name);
    }};
  let source = fs.readFileSync(path.join(root, file), 'utf8');
  // The generated @Entry class has no public export and schedules framework startup.
  if (file.endsWith('MainPage.ts')) {
    source = source.replace(/(?:registerNamedRoute|ViewStackProcessor\.StartGetAccessRecordingFor)[\s\S]*$/, 'exports.MainPage = MainPage;');
  }
  const output = ts.transpileModule(source, {
    compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}
  }).outputText;
  vm.runInNewContext(output, context);
  return context.exports;
}
const {AppState} = load('entry/src/main/ets/model/AppState.ets');
const dataModule = load('entry/src/main/ets/widget/StudyWidgetData.ets');
const files = new Map();
let fileCounter = 0;
const handles = new Map();
const io = {
  OpenMode:{CREATE:1,WRITE_ONLY:2,TRUNC:4},
  openSync(name) {const file={fd:++fileCounter};handles.set(file.fd,name);files.set(name,'');return file;},
  writeSync(fd,text) {files.set(handles.get(fd),text);return text.length;}, fsyncSync(){}, closeSync(){},
  renameSync(from,to){files.set(to,files.get(from));files.delete(from);},
  readTextSync(name){if(!files.has(name))throw Error('missing');return files.get(name);}
};
const {StudyWidgetStore} = load('entry/src/main/ets/widget/StudyWidgetStore.ets', {
  '@kit.CoreFileKit':{fileIo:io}, './StudyWidgetData':dataModule
});
const updates = [];
let gate;
const formProvider = {
  async getPublishedRunningFormInfos() {
    if (gate) {const wait=gate;gate=null;await wait;}
    return [
      {formId:'small',formName:'StudyTodo',moduleName:'entry',dimension:2},
      {formId:'wide',formName:'StudyTodo',moduleName:'entry',dimension:3},
      {formId:'other',formName:'Other',moduleName:'entry',dimension:2}
    ];
  },
  async getPublishedRunningFormInfoById(formId){return {dimension:formId==='wide'?3:2};},
  async updateForm(id,binding){updates.push({id,data:JSON.parse(JSON.stringify(binding.data))});}
};
const kit = {formProvider, formBindingData:{createFormBindingData:data=>({data})},
  FormExtensionAbility:class{}, formInfo:{FormParam:{DIMENSION_KEY:'dimension'},FormState:{READY:0}}};
const bindingModule = load('entry/src/main/ets/widget/WidgetBinding.ets',{'@kit.FormKit':kit});
const {StudyWidgetSync} = load('entry/src/main/ets/widget/StudyWidgetSync.ets', {
  '@kit.FormKit':kit, '../model/AppState':{AppState}, './StudyWidgetData':dataModule,
  './StudyWidgetStore':{StudyWidgetStore}, './WidgetBinding':bindingModule
});
const tick = () => new Promise(resolve => setImmediate(resolve));
const last = id => updates.filter(update => update.id===id).at(-1).data;
const json = value => JSON.parse(JSON.stringify(value));
const sourceRequest = (course,planId,kc) => ({source:'study-widget',course,planId,kc});
const launchModule = load('entry/src/main/ets/widget/WidgetLaunch.ets');
const opened = [];
const tabsModule = {setTabsController(){},openPractice:kc=>opened.push(kc)};
const {MainPage} = load('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/pages/MainPage.ts', {
  '/model/AppState':{AppState}, '/utils/TabSwitch':tabsModule,
  '/components/Index':{}, '/components/KnowledgeGraph':{}, '/components/AgentChat':{},
  '/components/LearningPath':{}, '/components/ServiceWidget':{},
  '/widget/StudyWidgetSync':{StudyWidgetSync}
}, {ViewPU:class{}});
function page(chosen=false) {
  const item=Object.create(MainPage.prototype);
  for (const [key,value] of Object.entries({courseChosen:chosen,currentIndex:0,
    activeCourse:AppState.getCourse(),pendingWidgetKc:-1,tabsController:{changeIndex(index){item.currentIndex=index;}}})) {
    Object.defineProperty(item,key,{value,writable:true});
  }
  return item;
}
async function main() {
  storage.set('lastStudyCourse','dsa');
  AppState.initializeStorage();
  assert.equal(AppState.getCourse(),'dsa','restore the last course before publishing a cold-start snapshot');
  assert.equal(StudyWidgetStore.read('/app').total,0,'new install has an empty widget');
  files.set('/app/study-widget.json','broken json');
  assert.equal(StudyWidgetStore.read('/app').total,0,'corrupt snapshot does not break the form');
  StudyWidgetSync.start('/app');
  await tick();
  const plan=[{kc:4,name:'栈',mastery:0.2},{kc:5,name:'队列',mastery:0.3}];
  AppState.setPlan(plan);
  const planId=AppState.getActivePlanId();
  AppState.registerTaskQuestions(planId,4,[41,42]);
  AppState.registerTaskQuestions(planId,5,[51]);
  AppState.addInteraction(4,1,41);
  await tick();
  assert.equal(last('small').course,'dsa');
  assert.equal(last('small').tasks[0].answered,1);
  assert.equal(last('small').cardDimension,2);
  assert.equal(last('wide').cardDimension,3);
  assert.ok(!updates.some(update=>update.id==='other'));
  assert.ok(!files.has('/app/study-widget.json.tmp'),'atomic rename leaves a complete shared snapshot');
  assert.ok(!('interactions' in last('small')) && !('messages' in last('small')),'only the display projection is shared');

  const FormAbility=load('entry/src/main/ets/entryformability/StudyFormAbility.ets', {
    '@kit.FormKit':kit, '../widget/StudyWidgetStore':{StudyWidgetStore}, '../widget/WidgetBinding':bindingModule
  }).default;
  const form=new FormAbility();form.context={filesDir:'/app'};
  assert.equal(form.onAddForm({parameters:{dimension:3}}).data.tasks[0].answered,1,
    'a newly added form reads the latest persisted snapshot');
  await form.onUpdateForm('wide');
  assert.equal(last('wide').planId,planId);

  assert.equal(launchModule.parseWidgetLaunch({params:'broken'}),null);
  assert.equal(launchModule.parseWidgetLaunch({params:sourceRequest('bad',1,4)}),null);
  assert.equal(launchModule.parseWidgetLaunch({params:sourceRequest('dsa',1,4.5)}),null);
  launchModule.queueWidgetLaunch({params:JSON.stringify(sourceRequest('dsa',planId,4))});
  let screen=page();
  screen.consumeWidgetLaunch();
  assert.equal(screen.courseChosen,true);
  assert.equal(screen.currentIndex,1);
  assert.equal(opened.length,0,'cold launch waits for native tabs to mount');
  screen.applyPendingWidgetPractice();
  assert.equal(opened.at(-1),4);
  assert.equal(storage.get('widgetLaunchPending'),'','launch intent is consumed once');
  const epoch=AppState.getCourseEpoch();
  launchModule.queueWidgetLaunch({params:sourceRequest('dsa',planId,5)});
  screen.consumeWidgetLaunch();
  assert.equal(opened.at(-1),5,'a running app opens the requested task');
  assert.equal(AppState.getCourseEpoch(),epoch,'same-course launch keeps existing pages and requests valid');
  AppState.switchCourse('math');
  screen.activeCourse='math';
  launchModule.queueWidgetLaunch({params:sourceRequest('dsa',planId,4)});
  screen.consumeWidgetLaunch();
  assert.equal(AppState.getCourse(),'dsa');
  assert.equal(screen.activeCourse,'dsa','cross-course launch changes the page key to recreate course-bound views');
  screen.applyPendingWidgetPractice();
  assert.equal(opened.at(-1),4);
  const before=opened.length;
  launchModule.queueWidgetLaunch({params:sourceRequest('dsa',planId+100,4)});
  screen.consumeWidgetLaunch();
  assert.equal(screen.currentIndex,3,'stale card routes to the current path');
  assert.equal(opened.length,before,'stale tasks cannot start an unrelated practice');

  AppState.addInteraction(4,1,42);
  await tick();
  assert.equal(last('small').percent,50);
  assert.deepEqual(last('small').tasks.map(task=>task.kc),[5,4],'pending tasks appear before completed tasks');
  AppState.addInteraction(5,0,51);
  await tick();
  assert.equal(last('small').total,0,'existing whole-plan completion archives the path and clears widget tasks');
  assert.equal(last('small').summary,'已完成 1 条学习路径');
  launchModule.queueWidgetLaunch({params:sourceRequest('dsa',planId,5)});
  screen.consumeWidgetLaunch();
  assert.equal(screen.currentIndex,2,'an archived task leads to planning instead of reopening a completed task');
  assert.equal(opened.length,before);

  let release;
  gate=new Promise(resolve=>{release=resolve;});
  AppState.switchCourse('math');
  AppState.setPlan([{kc:8,name:'加法',mastery:0.2}]);
  AppState.switchCourse('dsa');
  release();
  await tick();await tick();
  assert.equal(last('wide').course,'dsa','updates arriving during a form service request finish on the newest course');
  assert.equal(json(StudyWidgetStore.read('/app')).course,'dsa');
  console.log('PASS: native widget persists a minimal snapshot, refreshes both sizes, and follows task progress/course changes.');
  console.log('PASS: widget cold/warm launches route to the right course; stale and completed tasks are rejected.');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
