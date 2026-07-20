import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 聊天消息接口（UI 层使用）
 */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
  timestamp: number;
}

/**
 * API 请求体中的消息格式
 */
interface ApiMessage {
  role: string;
  content: string;
}

/**
 * API 聊天补全请求体
 */
interface ChatCompletionRequest {
  model: string;
  messages: ApiMessage[];
  temperature?: number;
}

/**
 * AI 聊天服务配置
 */
export interface AiServiceConfig {
  /** API 端点地址（OpenAI兼容接口） */
  apiUrl: string;
  /** API 密钥 */
  apiKey: string;
  /** 模型名称 */
  model: string;
  /** 系统提示词 */
  systemPrompt?: string;
  /** 请求超时时间(ms) */
  timeout?: number;
}

/**
 * AI 聊天服务
 * 封装对 LLM API 的 HTTP 调用，支持 OpenAI 兼容接口。
 */
export class AiChatService {
  private config: AiServiceConfig;
  private client: http.HttpRequest;

  constructor(config: AiServiceConfig) {
    this.config = {
      apiUrl: config.apiUrl,
      apiKey: config.apiKey,
      model: config.model,
      systemPrompt: config.systemPrompt ?? '你是一个友好的AI学习助手，请用中文回答。',
      timeout: config.timeout ?? 30000
    };
    this.client = http.createHttp();
  }

  /**
   * 发送对话请求，返回 AI 生成的回复内容字符串。
   * @param messages 历史消息列表
   * @returns AI 回复的 content 字符串
   */
  async sendMessage(messages: ChatMessage[]): Promise<string> {
    try {
      const apiMessages: ApiMessage[] = [];

      // 添加系统提示词
      const systemMsg: ApiMessage = {
        role: 'system',
        content: this.config.systemPrompt ?? '你是一个友好的AI学习助手，请用中文回答。'
      };
      apiMessages.push(systemMsg);

      // 添加历史消息（跳过 timestamp）
      for (let i = 0; i < messages.length; i++) {
        const msg: ApiMessage = {
          role: messages[i].role,
          content: messages[i].content
        };
        apiMessages.push(msg);
      }

      const requestBody: ChatCompletionRequest = {
        model: this.config.model,
        messages: apiMessages,
        temperature: 0.7
      };

      const response = await this.httpPost(this.config.apiUrl, requestBody);

      // 解析 OpenAI 兼容格式的响应
      const data = JSON.parse(response as string) as Record<string, Object>;

      const choices: Object[] = data['choices'] as Object[];
      if (!choices || choices.length === 0) {
        throw new Error('API 返回的 choices 为空');
      }

      const firstChoice: Record<string, Object> = choices[0] as Record<string, Object>;
      const message: Record<string, Object> = firstChoice['message'] as Record<string, Object>;
      const content: string = message['content'] as string;

      if (!content) {
        throw new Error('API 返回的消息内容为空');
      }

      return content;
    } catch (err) {
      const error = err as BusinessError;
      console.error('AiChatService.sendMessage 失败:', error.message);
      throw new Error(error.message);
    }
  }

  /**
   * 执行 HTTP POST 请求
   */
  private async httpPost(url: string, body: ChatCompletionRequest): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.apiKey}`
        },
        extraData: JSON.stringify(body) as string,
        connectTimeout: this.config.timeout ?? 30000,
        readTimeout: this.config.timeout ?? 30000,
        expectDataType: http.HttpDataType.STRING
      };

      this.client.request(url, requestOptions, (err: BusinessError, data: http.HttpResponse) => {
        if (err) {
          console.error('HTTP 请求失败:', err.message);
          reject(new Error(`网络请求失败: ${err.message}`));
          return;
        }

        if (data.responseCode !== 200) {
          reject(new Error(`服务器返回错误状态码: ${data.responseCode}`));
          return;
        }

        const result: string = data.result as string;
        resolve(result);
      });
    });
  }

  /**
   * 销毁 HTTP 客户端实例
   */
  destroy(): void {
    if (this.client) {
      this.client.destroy();
    }
  }
}
