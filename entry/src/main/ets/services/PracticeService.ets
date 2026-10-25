import { AppState } from '../model/AppState';
import { BackendService, QuestionItem } from './BackendService';

// 本次运行中固定每个知识点的练习题，保证题号链接和实际打开的题目一致。
export class PracticeService {
  private static questions: Map<string, QuestionItem[]> = new Map<string, QuestionItem[]>();
  private static pending: Map<string, Promise<QuestionItem[]>> = new Map<string, Promise<QuestionItem[]>>();

  static async getQuestions(kc: number, planId: number = AppState.getActivePlanId()): Promise<QuestionItem[]> {
    const course = AppState.getCourse();
    const epoch = AppState.getCourseEpoch();
    const key = course + ":" + kc.toString();
    let questions = PracticeService.questions.get(key);
    if (questions === undefined) {
      let request = PracticeService.pending.get(key);
      if (request === undefined) {
        request = BackendService.getQuestions(kc, 3);
        PracticeService.pending.set(key, request);
      }
      try {
        questions = await request;
        questions = questions.filter((question: QuestionItem) => question.kc === kc);
        if (questions.length === 0) {
          throw new Error('该知识点暂无题目');
        }
        PracticeService.questions.set(key, questions);
      } finally {
        PracticeService.pending.delete(key);
      }
    }
    if (epoch !== AppState.getCourseEpoch()) { throw new Error("课程已切换，请重新打开练习"); }
    AppState.registerTaskQuestions(planId, kc, questions.map((question: QuestionItem) => question.qid));
    return questions.slice();
  }
}
