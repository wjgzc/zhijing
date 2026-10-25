// Runs the real compiled practice methods with transport/UI stubs.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = path.join(__dirname,'..');
const storage = new Map();
const AppStorage = { get: key => storage.get(key), setOrCreate: (key,value) => storage.set(key,value) };
const PersistentStorage = { persistProp: (key,value) => {
  if (!storage.has(key)) storage.set(key,value);
}};
function load(file,globals) {
  const context = {exports:{},...globals};
  const code = ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'), {
    compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}
  }).outputText;
  vm.runInNewContext(code,context);
  return context.exports;
}
const {AppState} = load('entry/src/main/ets/model/AppState.ets',{AppStorage});
const responses = [];
const submissions = [];
const backend = {submitJava: async (...args) => {
  submissions.push(args);
  const next = responses.shift();
  if (next instanceof Error) throw next;
  return await next;
}};
backend.submitMath = backend.submitJava;
const {KnowledgeGraph} = load('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/components/KnowledgeGraph.ts',{
  ViewPU:class{}, AppStorage, PersistentStorage, console,
  require:name => {
    if(name.includes('/model/AppState')) return {AppState};
    if(name.includes('/services/BackendService')) return {BackendService:backend};
    if(name.includes('/services/PracticeService')) return {PracticeService:{}};
    if(name==='@ohos:promptAction') return {default:{showToast(){}}};
    if(name==='@ohos:util') return {default:{}};
    throw Error('Unexpected dependency '+name);
  }
});
function graph() {
  const item = Object.create(KnowledgeGraph.prototype);
  const fields = {practiceQuestions:[{qid:0,kc:8}],practiceIndex:0,curQid:0,curKc:8,
    javaCode:'public class Solution {}',javaMainClass:'Solution',judgePending:false,
    judgeMessage:'',practiceJudged:false,practiceCorrect:false,mathInputs:['24'],
    mathFeedback:[],analysisImages:[],curAnswer:'',curCorrectKey:'',curAnalysis:'',
    selectedOptionKey:'',showOriginal:false,curContent:'',curOptions:[],curIsChoice:false,
    curIsJava:true,curOriginal:'',curImages:[],failedImages:[],curExamples:[]};
  for(const [key,value] of Object.entries(fields)) Object.defineProperty(item,key,{value,writable:true});
  item.practiceRequestId=1;
  item.courseEpoch=AppState.getCourseEpoch();
  item.refreshMastery=()=>{};
  return item;
}
const verdict = correct => ({course:'dsa',qid:0,status:correct?'accepted':'wrong_answer',graded:true,
  correct,passed:correct?7:0,total:7,detail:'fixture',actual:'',expected:''});
async function main(){
  AppState.switchCourse('dsa');
  const question = qid => ({qid,kc:8,type:'java',answer:[],content:'fixture',options:{},analysis:'',
    starter_code:'public class Solution {}'});
  let draft=graph();
  draft.practiceQuestions=[question(44),question(45)];
  storage.set('javaDraft_44','public class Main {}');
  draft.syncCurrentQuestion();
  assert.equal(draft.javaMainClass,'Solution','legacy drafts retain the default until a class is selected');
  draft.selectJavaMainClass('Main');
  assert.equal(storage.get('javaMainClass_44'),'Main');
  draft.practiceIndex=1;
  draft.syncCurrentQuestion();
  assert.equal(draft.javaMainClass,'Solution','each question has its own saved entry class');
  draft.practiceIndex=0;
  draft.syncCurrentQuestion();
  assert.equal(draft.javaCode,'public class Main {}');
  assert.equal(draft.javaMainClass,'Main','returning to a question restores the class with its code');
  draft=graph();
  draft.practiceQuestions=[question(44)];
  draft.syncCurrentQuestion();
  assert.equal(draft.javaMainClass,'Main','a newly created page restores persisted selection');
  responses.push(new Error('fixture: avoid recording a study attempt'));
  await draft.submitJava();
  assert.equal(submissions.at(-1)[2],'Main','the restored class must be sent to the backend');
  draft.selectJavaMainClass('Solution');
  draft.syncCurrentQuestion();
  assert.equal(draft.javaMainClass,'Solution','changing back to Solution also persists');
  draft.judgePending=true;
  draft.selectJavaMainClass('Main');
  assert.equal(storage.get('javaMainClass_44'),'Solution','submission locks class changes');
  draft.judgePending=false;
  storage.set('javaMainClass_44','invalid');
  draft.syncCurrentQuestion();
  assert.equal(draft.javaMainClass,'Solution','invalid saved metadata uses a supported class');
  console.log('PASS: entry class persists per Java question, survives page recreation, and reaches submissions.');
  let practice=graph();
  responses.push(new Error('服务繁忙'));
  await practice.submitJava();
  assert.equal(AppState.interactionCount(),0,'infrastructure failure must never become an incorrect answer');
  assert.equal(practice.judgePending,false);
  assert.ok(practice.judgeMessage.includes('未记录作答'));
  responses.push(verdict(1));
  await practice.submitJava();
  assert.equal(AppState.interactionCount(),1);
  assert.equal(AppState.getInteractions()[0].qid,0);
  assert.equal(practice.practiceCorrect,true);
  responses.push(verdict(0));
  await practice.submitJava();
  assert.equal(AppState.interactionCount(),2,'a deliberate resubmission is another attempt');
  assert.equal(AppState.questionCount(),1,'repeated submissions still count as one unique question');
  let finish;
  responses.push(new Promise(resolve=>{finish=resolve;}));
  const pending=practice.submitJava();
  AppState.switchCourse('math');
  finish(verdict(1));
  await pending;
  assert.equal(AppState.interactionCount(),0,'a late Java result must not enter math history');
  AppState.switchCourse('dsa');
  assert.equal(AppState.interactionCount(),2,'discarded results must not appear when switching back');

  AppState.switchCourse('math');
  practice=graph();
  responses.push(new Error('network error'));
  await practice.submitMath(['24']);
  assert.equal(AppState.interactionCount(),0);
  responses.push({graded:true,correct:1,detail:'正确',expected:['24'],analysis:'计算说明',analysis_images:[],per_blank:[true]});
  await practice.submitMath(['24']);
  assert.equal(AppState.interactionCount(),1);
  assert.equal(practice.curAnswer,'24');
  assert.ok(practice.mathFeedback[0].includes('正确'));

  let destroyed=false;
  const {BackendService}=load('entry/src/main/ets/services/BackendService.ets',{
    require:name=>{
      if(name==='../model/AppState')return {AppState};
      if(name==='@kit.NetworkKit')return {http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:'STRING'},
        createHttp:()=>({destroy(){destroyed=true;},request(url,options,callback){callback(null,{responseCode:429,result:'<html>rate limit</html>'});}})}};
      throw Error('Unexpected dependency '+name);
    }
  });
  await assert.rejects(BackendService.submitJava(0,'source','Solution'),/提交过于频繁/);
  assert.ok(destroyed);
  console.log('PASS: real practice methods record completed grades, preserve retries, and discard late cross-course results.');
  console.log('PASS: HTML rate-limit responses reject cleanly instead of leaving the submit UI waiting.');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
