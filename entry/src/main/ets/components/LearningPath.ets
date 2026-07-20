import { promptAction } from '@kit.ArkUI';

interface PathStage {
  dayRange: string;
  title: string;
  status: 'done' | 'active' | 'pending';
  mastery: number;
  description: string;
}

@Component
export struct LearningPath {
  @State stages: PathStage[] = [
    {
      dayRange: 'Day 1-3',
      title: '数组基础',
      status: 'done',
      mastery: 92,
      description: '掌握度 92% · 用时2.5天'
    },
    {
      dayRange: 'Day 4-6',
      title: '链表操作',
      status: 'active',
      mastery: 45,
      description: '掌握度 45% · 预计还需2天'
    },
    {
      dayRange: 'Day 7-10',
      title: '树结构',
      status: 'pending',
      mastery: 0,
      description: '二叉树、遍历算法 · 预计4天'
    },
    {
      dayRange: 'Day 11-13',
      title: '队列与栈',
      status: 'pending',
      mastery: 0,
      description: 'FIFO / LIFO · 双端队列 · 预计3天'
    },
    {
      dayRange: 'Day 14-16',
      title: '图论基础',
      status: 'pending',
      mastery: 0,
      description: 'DFS / BFS、最短路径 · 预计3天'
    }
  ];

  build() {
    Column() {
      // 页面头部
      this.PageHeader()

      // 时间轴
      this.Timeline()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  PageHeader() {
    Row() {
      Column() {
        Text('我的学习路径')
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
    }
    .width('90%')
    .height(60)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  Timeline() {
    Scroll() {
      Column() {
        ForEach(this.stages, (stage: PathStage, index: number) => {
          this.TimelineItem(stage, index)
        }, (stage: PathStage, index: number) => index.toString())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: 100 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  TimelineItem(stage: PathStage, index: number) {
    Row() {
      // 时间轴左侧
      Column() {
        // 节点
        Stack() {
          Circle()
            .width(20)
            .height(20)
            .fill(
              stage.status === 'done' ? '#7ED321' :
                stage.status === 'active' ? '#F5A623' :
                  Color.White
            )
            .stroke(
              stage.status === 'pending' ? '#E8E8E8' :
                stage.status === 'active' ? '#F5A623' :
                  '#7ED321'
            )
            .strokeWidth(3)

          if (stage.status === 'active') {
            Circle()
              .width(20)
              .height(20)
              .fill('none')
              .stroke('#F5A623')
              .strokeWidth(1)
              .scale({ x: 1.5, y: 1.5 })
              .opacity(0.3)
              .animation({
                duration: 2000,
                iterations: -1,
                playMode: PlayMode.Alternate
              })
          }
        }
        .width(20)
        .height(20)

        // 连线
        if (index < this.stages.length - 1) {
          Column()
            .width(3)
            .height(60)
            .linearGradient({
              angle: 180,
              colors: [
                [stage.status === 'done' ? '#7ED321' : '#E8E8E8', 0],
                [this.stages[index + 1].status !== 'pending' ? '#7ED321' : '#E8E8E8', 1]
              ]
            })
            .margin({ top: 4 })
        }
      }
      .width(30)
      .alignItems(HorizontalAlign.Center)

      // 卡片
      Column() {
        Row() {
          Text(stage.dayRange)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#4A90D9')
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor('#F0F7FF')
            .borderRadius(10)

          Text(
            stage.status === 'done' ? '已完成' :
              stage.status === 'active' ? '进行中' :
                '待开始'
          )
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(
              stage.status === 'done' ? '#7ED321' :
                stage.status === 'active' ? '#F5A623' :
                  '#8E92A4'
            )
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 12 })

        Row() {
          Column() {
            Text(stage.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')

            Text(stage.description)
              .fontSize(12)
              .fontColor('#8E92A4')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        if (stage.status !== 'pending') {
          Column() {
            Row() {
              Text(stage.mastery + '%')
                .fontSize(11)
                .fontColor('#8E92A4')

              Blank()

              Text(
                stage.status === 'done' ? '已完成' : '进行中'
              )
                .fontSize(11)
                .fontColor(
                  stage.status === 'done' ? '#7ED321' : '#F5A623'
                )
            }
            .width('100%')
            .margin({ bottom: 4 })

            Stack({ alignContent: Alignment.Start }) {
              Column()
                .width('100%')
                .height(6)
                .backgroundColor('#F0F0F0')
                .borderRadius(3)

              Column()
                .width(stage.mastery + '%')
                .height(6)
                .linearGradient({
                  angle: 90,
                  colors: [['#4A90D9', 0], ['#7ED321', 1]]
                })
                .borderRadius(3)
                .animation({
                  duration: 1000,
                  curve: Curve.EaseOut
                })
            }
            .width('100%')
          }
          .width('100%')
          .margin({ top: 12 })
        }

        if (stage.status === 'active') {
          Button('继续学习')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .height(44)
            .borderRadius(14)
            .linearGradient({
              angle: 135,
              colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
            })
            .fontColor(Color.White)
            .margin({ top: 12 })
            .onClick(() => {
              promptAction.showToast({ message: '继续学习: ' + stage.title, duration: 2000 });
            })
        }
      }
      .layoutWeight(1)
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .shadow({
        radius: 8,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
      .margin({ left: 12, bottom: 16 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}