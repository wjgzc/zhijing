import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';

interface ChatMessage {
  role: 'agent' | 'user';
  content: string;
  isCard?: boolean;
  cardItems?: string[];
}

@Component
export struct AgentChat {
  @State messages: ChatMessage[] = [
    {
      role: 'agent',
      content: '你好！我是知径Agent，可以帮你规划学习路径~ 想学什么告诉我吧！'
    },
    {
      role: 'user',
      content: '我想两周掌握数据结构中的树与图'
    },
    {
      role: 'agent',
      content: '好的！根据知识图谱分析，建议路径如下：',
      isCard: true,
      cardItems: [
        '第1-3天：数组基础（先修知识）',
        '第4-6天：链表操作',
        '第7-10天：树结构（二叉树、遍历）',
        '第11-14天：图算法（BFS/DFS）'
      ]
    },
    {
      role: 'user',
      content: '链表我已经会了，可以跳过吗？'
    },
    {
      role: 'agent',
      content: '收到！已调整路径，跳过链表阶段，预计缩短2天完成 🎉\n新路径：数组 → 树 → 图（12天）'
    }
  ];
  @State inputText: string = '';

  build() {
    Column() {
      Column() {
        // 页面头部
        this.PageHeader()

        // 聊天区域
        this.ChatArea()

        // 输入区域
        this.InputArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }

  sendMessage(): void {
    if (this.inputText.trim() === '') {
      return;
    }

    // 添加用户消息
    this.messages.push({
      role: 'user',
      content: this.inputText.trim()
    });

    // 清空输入框
    this.inputText = '';

    // 延迟模拟AI回复
    setTimeout(() => {
      this.messages.push({
        role: 'agent',
        content: '收到！正在根据知识图谱为你规划最优路径...'
      });
    }, 1000);
  }

  @Builder
  PageHeader() {
    Row() {
      Button('←')
        .fontSize(18)
        .fontColor('#1A1A2E')
        .backgroundColor(Color.White)
        .width(36)
        .height(36)
        .borderRadius(12)
        .shadow({
          radius: 4,
          color: '#10000000',
          offsetX: 0,
          offsetY: 2
        })
        .onClick(() => {
          switchTab(0);
        })

      Column() {
        Text('🤖 知径Agent')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')

        Text('AI学习规划助手')
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
    Scroll() {
      Column() {
        ForEach(this.messages, (msg: ChatMessage, index: number) => {
          if (msg.role === 'agent') {
            this.AgentMessage(msg)
          } else {
            this.UserMessage(msg)
          }
        }, (msg: ChatMessage, index: number) => index.toString())
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  AgentMessage(msg: ChatMessage) {
    Row() {
      // Agent头像
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
        Text('🤖')
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .margin({ right: 10 })

      // 气泡
      Column() {
        Text(msg.content)
          .fontSize(14)
          .fontColor('#1A1A2E')
          .lineHeight(20)
          .width('100%')

        if (msg.isCard && msg.cardItems) {
          this.StructuredCard(msg.cardItems)
        }
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
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  UserMessage(msg: ChatMessage) {
    Row() {
      // 气泡
      Column() {
        Text(msg.content)
          .fontSize(14)
          .fontColor(Color.White)
          .lineHeight(20)
          .width('100%')
      }
      .padding(12)
      .linearGradient({
        angle: 135,
        colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
      })
      .borderRadius(18)
      .borderRadius({ topRight: 4 })
      .constraintSize({ maxWidth: 260 })

      // 用户头像
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
  StructuredCard(items: string[]) {
    Column() {
      Text('📋 14天学习计划')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A90D9')
        .width('100%')
        .margin({ bottom: 8 })

      ForEach(items, (item: string, idx: number) => {
        Text(item)
          .fontSize(13)
          .fontColor('#1A1A2E')
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .border({
            width: { bottom: idx < items.length - 1 ? 1 : 0 },
            color: '#E8E8E8'
          })
      }, (item: string, idx: number) => idx.toString())
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F0F7FF')
    .borderRadius(12)
    .border({ width: { left: 4 }, color: '#4A90D9' })
    .margin({ top: 8 })
  }

  @Builder
  InputArea() {
    Column() {
      Row() {
        Button('🎤')
          .fontSize(20)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            promptAction.showToast({ message: '语音输入', duration: 2000 });
          })

        TextInput({ placeholder: '我想学...', text: this.inputText })
          .placeholderColor('#B0B4C3')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button('➤')
          .fontSize(16)
          .fontColor(Color.White)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
          .width(36)
          .height(36)
          .borderRadius(18)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#F7F9FC')
      .borderRadius(28)
    }
    .width('90%')
    .padding({ top: 12, bottom: 24 })
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#F0F0F0' })
  }
}