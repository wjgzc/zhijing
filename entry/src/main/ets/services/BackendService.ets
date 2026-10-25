import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppState } from '../model/AppState';

/**
 * 知径后端服务：统一封装对 Python 后端的三类调用。
 * 后端地址集中在这里，改 IP 只改这一处。
 */
export const BACKEND_BASE_URL: string = 'http://47.117.97.44';

export interface Interaction {
  kc: number;
  correct: number;
  qid?: number;
}

export interface WeakKc {
  kc: number;
  name: string;
  mastery: number;
}

export interface QuestionItem {
  qid: number;
  kc: number;
  type: string;
  content: string;
  options: Record<string, string>;
  answer: string[];
  analysis: string;
  original?: string;
  starter_code?: string;
  source?: string;
  images?: string[];
  stem?: string;
  original_plain?: string;
  examples?: QuestionExample[];
  answer_count?: number;
  option_images?: Record<string, string[]>;
}

export interface QuestionExample { input: string; output: string; }
export interface MathGrade {
  status: string;
  graded: boolean;
  correct: number;
  detail: string;
  per_blank: boolean[];
  expected: string[];
  analysis: string;
  analysis_images: string[];
}
interface MathRequest { course: string; qid: number; kc: number; answers: string[]; }

export interface JudgeResult {
  course: string;
  qid: number;
  status: string;
  graded: boolean;
  correct: number;
  passed: number;
  total: number;
  detail: string;
  actual: string;
  expected: string;
  elapsed_ms: number;
}

interface SubmitRequest {
  course: string;
  qid: number;
  source: string;
  main_class: string;
}

export interface PredictResult {
  supported_kcs: number[];
  mastery: number[];
  weak: WeakKc[];
  n_kc: number;
}

export interface ChatMsg {
  role: string;
  content: string;
}

export interface ChatResult {
  content: string;
  weak: WeakKc[];
}

interface PredictRequest {
  course: string;
  interactions: Interaction[];
}

interface ChatRequest {
  course: string;
  interactions: Interaction[];
  intake: Record<string, string>;
  messages: ChatMsg[];
}

export class BackendService {
  private static request(method: http.RequestMethod, url: string, body?: string): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const client = http.createHttp();
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        connectTimeout: 30000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.STRING
      };
      if (body !== undefined) {
        options.extraData = body;
      }
      client.request(url, options, (err: BusinessError, data: http.HttpResponse) => {
        if (err) {
          client.destroy();
          reject(new Error(`网络请求失败: ${err.message}`));
          return;
        }
        if (data.responseCode !== 200) {
          client.destroy();
          let message = `服务器返回错误 ${data.responseCode}`;
          try {
            const body = JSON.parse(data.result as string) as Record<string, Object>;
            if (typeof body['detail'] === 'string') { message = body['detail'] as string; }
          } catch (e) {
            if (data.responseCode === 429) { message = '提交过于频繁，请稍后重试'; }
          }
          reject(new Error(message));
          return;
        }
        const result = data.result as string;
        client.destroy();
        resolve(result);
      });
    });
  }

  /** 获取某知识点下 n 道题 */
  static async getQuestions(kc: number, n: number = 3): Promise<QuestionItem[]> {
    const url = `${BACKEND_BASE_URL}/questions?kc=${kc}&n=${n}&course=${AppState.getCourse()}`;
    const raw = await BackendService.request(http.RequestMethod.GET, url);
    const data = JSON.parse(raw) as Record<string, Object>;
    const qs = data['questions'] as QuestionItem[];
    return qs ?? [];
  }

  /** 答题序列 -> 掌握度向量 */
  static async predict(interactions: Interaction[]): Promise<PredictResult> {
    const url = `${BACKEND_BASE_URL}/predict`;
    const reqBody: PredictRequest = { course: AppState.getCourse(), interactions: interactions.slice(-200) };
    const raw = await BackendService.request(http.RequestMethod.POST, url, JSON.stringify(reqBody));
    const data = JSON.parse(raw) as Record<string, Object>;
    return {
      mastery: data['mastery'] as number[],
      weak: data['weak'] as WeakKc[],
      n_kc: data['n_kc'] as number
      , supported_kcs: (data['supported_kcs'] as number[]) ?? []
    };
  }

  /** 掌握度 + 摸底信息 -> DeepSeek 学习建议（带超链接） */
  static async chat(interactions: Interaction[], intake: Record<string, string>,
    messages: ChatMsg[]): Promise<ChatResult> {
    const url = `${BACKEND_BASE_URL}/chat`;
    const reqBody: ChatRequest = { course: AppState.getCourse(), interactions: interactions.slice(-200), intake: intake, messages: messages.slice(-60) };
    const raw = await BackendService.request(http.RequestMethod.POST, url, JSON.stringify(reqBody));
    const data = JSON.parse(raw) as Record<string, Object>;
    return {
      content: data['content'] as string,
      weak: data['weak'] as WeakKc[]
    };
  }

  static async submitJava(qid: number, source: string, mainClass: string): Promise<JudgeResult> {
    const body: SubmitRequest = { course: AppState.getCourse(), qid: qid, source: source, main_class: mainClass };
    const raw = await BackendService.request(http.RequestMethod.POST, `${BACKEND_BASE_URL}/submit`, JSON.stringify(body));
    return JSON.parse(raw) as JudgeResult;
  }

  static async submitMath(qid: number, kc: number, answers: string[]): Promise<MathGrade> {
    const body: MathRequest = { course: AppState.getCourse(), qid: qid, kc: kc, answers: answers };
    const raw = await BackendService.request(http.RequestMethod.POST, `${BACKEND_BASE_URL}/submit-math`, JSON.stringify(body));
    return JSON.parse(raw) as MathGrade;
  }
}
