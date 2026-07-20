import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';
import { AiChatService, ChatMessage, AiServiceConfig } from '../services/AiChatService';

const AI_CONFIG: AiServiceConfig = {
  apiUrl: 'https://api.deepseek.com/v1/chat/completions',
  apiKey: 'sk-441bc33ebf184f2f88845f331c2234d7',
  model: 'deepseek-chat',
  systemPrompt: '你是一个友好的AI学习助手，名叫"知径Agent"，专门帮助用户规划学习路径、解答学习问题。请用中文回答，回答简洁有条理。'
};

interface UIMessage {
  role: 'agent' | 'user';
  content: string;
}

@Component
export struct AgentChat {
  @State messages: UIMessage[] = [
    {
      role: 'agent',
      content: '你好！我是知径Agent，可以帮你规划学习路径~ 想学什么告诉我吧！'
    }
  ];
  @State inputText: string = '';
  @State isLoading: boolean = false;

  private aiService: AiChatService | null = null;
  private scrollController: Scroller = new Scroller();

  aboutToAppear(): void {
    this.aiService = new AiChatService({
      apiUrl: AI_CONFIG.apiUrl,
      apiKey: AI_CONFIG.apiKey,
      model: AI_CONFIG.model,
      systemPrompt: AI_CONFIG.systemPrompt,
      timeout: 30000
    });
  }

  aboutToDisappear(): void {
    if (this.aiService) {
      this.aiService.destroy();
      this.aiService = null;
    }
  }

  build() {
    Column() {
      Column() {
        this.PageHeader()
        this.ChatArea()
        this.InputArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }

  async sendMessage(): Promise<void> {
    const text = this.inputText.trim();
    if (text === '' || this.isLoading) {
      return;
    }

    const userMsg: UIMessage = { role: 'user', content: text };
    this.messages.push(userMsg);
    this.inputText = '';
    this.isLoading = true;
    this.scrollToBottom();

    try {
      if (!this.aiService) {
        throw new Error('AI 服务未初始化');
      }

      const chatHistory: ChatMessage[] = [];
      for (let i = 0; i < this.messages.length; i++) {
        const msg = this.messages[i];
        chatHistory.push({
          role: msg.role === 'agent' ? 'assistant' : 'user',
          content: msg.content,
          timestamp: Date.now()
        });
      }

      const reply = await this.aiService.sendMessage(chatHistory);
      this.messages.push({ role: 'agent', content: reply });
      this.scrollToBottom();
    } catch (err) {
      const message = (err as Error).message || '网络请求失败，请检查网络连接或 API 配置。';
      this.messages.push({
        role: 'agent',
        content: `⚠️ ${message}\n\n💡 提示：请确认 API 密钥和网络连接正常。`
      });
      console.error('[AgentChat] 发送消息失败:', message);
    } finally {
      this.isLoading = false;
    }
  }

  private scrollToBottom(): void {
    this.scrollController.scrollEdge(Edge.Bottom);
  }

  @Builder
  PageHeader() {
    Row() {

      Column() {
        Text('🤖 知径Agent')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')

        Text(this.isLoading ? '思考中...' : 'AI学习规划助手')
          .fontSize(13)
          .fontColor('#8E92A4')
      }
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Blank()
    }
    .width('90%')
    .height(60)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  ChatArea() {
    Column() {
      Scroll(this.scrollController) {
        Column() {
          ForEach(this.messages, (msg: UIMessage, index: number) => {
            if (msg.role === 'agent') {
              this.AgentMessage(msg)
            } else {
              this.UserMessage(msg)
            }
          }, (msg: UIMessage, index: number) => index.toString())

          if (this.isLoading) {
            this.LoadingIndicator()
          }
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  LoadingIndicator() {
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill(Color.White)
        LoadingProgress()
          .width(20)
          .height(20)
          .color('#4A90D9')
      }
      .width(36)
      .height(36)
      .margin({ right: 10 })

      Row() {
        Text('思考中')
          .fontSize(14)
          .fontColor('#8E92A4')

        Text('.')
          .fontSize(14)
          .fontColor('#4A90D9')
      }
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(18)
      .borderRadius({ topLeft: 4 })
      .shadow({
        radius: 4,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  AgentMessage(msg: UIMessage) {
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill(Color.White)
        Text('🤖')
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .margin({ right: 10 })

      Column() {
        Text(msg.content)
          .fontSize(14)
          .fontColor('#1A1A2E')
          .lineHeight(20)
      }
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(18)
      .borderRadius({ topLeft: 4 })
      .shadow({
        radius: 4,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
      .constraintSize({ maxWidth: 260 })
      .flexShrink(1)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  UserMessage(msg: UIMessage) {
    Row() {
      Column() {
        Text(msg.content)
          .fontSize(14)
          .fontColor(Color.White)
          .lineHeight(20)
      }
      .padding(12)
      .linearGradient({
        angle: 135,
        colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
      })
      .borderRadius(18)
      .borderRadius({ topRight: 4 })
      .constraintSize({ maxWidth: 260 })
      .flexShrink(1)

      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill('#E8E8E8')
        Text('🙋')
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .margin({ left: 10 })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ bottom: 12 })
  }

  @Builder
  InputArea() {
    Column() {
      Row() {

        TextArea({ placeholder: '我想学...', text: this.inputText })
          .placeholderColor('#B0B4C3')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .enabled(!this.isLoading)
          .maxLines(5)
          .padding({ top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.inputText = value;
          })

        Button(this.isLoading ? '⏳' : '➤')
          .fontSize(14)
          .fontColor(Color.White)
          .padding(0)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
          .width(36)
          .height(36)
          .borderRadius(18)
          .enabled(!this.isLoading)
          .opacity(this.isLoading ? 0.5 : 1)
          .alignSelf(ItemAlign.End)
          .margin({ bottom: 10 })
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 56, maxHeight: 150 })
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor('#F7F9FC')
      .borderRadius(28)
      .clip(true)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('90%')
    .padding({ top: 12, bottom: 24 })
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#F0F0F0' })
  }
}
