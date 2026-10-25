import { switchTab, openPractice } from '../utils/TabSwitch';
import { AppState } from '../model/AppState';

interface StudyTask {
  kc: number;
  name: string;
  done: boolean;
}

interface StatWidgetParams {
  value: string;
  label: string;
}

@Component
export struct ServiceWidget {
  @State tasks: StudyTask[] = [];
  @State questionCount: number = 0;
  @State overallMastery: number = 0;
  @State hasMastery: boolean = false;
  @State doneTaskCount: number = 0;
  @StorageProp('appStateVersion') @Watch('refresh') stateVersion: number = 0;

  // 用户信息状态
  @State username: string = '张三';
  @State grade: string = '大三';
  @State identity: string = '计算机科学与技术';
  @State selectedAvatar: number = 0;
  @State showEditDialog: boolean = false;
  @State showAvatarDialog: boolean = false;

  // 弹窗编辑用的临时变量
  @State editUsername: string = '';
  @State editGrade: string = '';
  @State editIdentity: string = '';

  // 头像颜色列表（6个备选）
  private avatarColors: ResourceColor[] = [
    $r('app.color.brand_solid'), '#BF3443', '#257449', '#946000', '#7850AA', '#087D79'
  ];
  // 头像对应首字母
  private avatarInitials: string[] = [
    '张', '李', '王', '赵', '孙', '周'
  ];

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    const overview = AppState.getOverview();
    this.questionCount = overview.questionCount;
    this.overallMastery = overview.overallMastery;
    this.hasMastery = overview.hasMastery;
    this.doneTaskCount = overview.doneTaskCount;
    const tasks: StudyTask[] = [];
    for (const item of AppState.getPlan()) {
      tasks.push({ kc: item.kc, name: item.name, done: AppState.isDone(item.kc) });
    }
    this.tasks = tasks;
  }

  private focusGraph(kc: number): void {
    AppStorage.setOrCreate('focusKcId', kc);
    const seq = (AppStorage.get<number>('focusSeq') ?? 0) + 1;
    AppStorage.setOrCreate('focusSeq', seq);
    switchTab(1);
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          // 渐变区域：包含"服务卡片"标题 + 用户信息卡片
          Column() {
            this.PageHeader()
            this.UserProfileCard()
          }
          .width('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              ['#ff0e79ff', 0.0],
              ['#ff4597ff', 0.45],
              ['#ff8bbaff', 1.0]
            ]
          })
          .padding({ bottom: 16 })
          .margin({ bottom: 16 })
          .shadow({
            radius: 12,
            color: '#402B6BC5',
            offsetX: 0,
            offsetY: 6
          })

          // Widget卡片
          Column() {
            this.WidgetSmall()
          }
          .margin({ bottom: 16 })

          Column() {
            this.WidgetMedium()
          }
          .margin({ bottom: 16 })

          Column() {
            this.WidgetLarge()
          }

          Blank().height(24)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .scrollBar(BarState.Off)

    }
    .bindSheet($$this.showEditDialog, this.EditProfileDialog(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      title: { title: '修改个人信息' },
      backgroundColor: $r('app.color.surface')
    })
    .bindSheet($$this.showAvatarDialog, this.AvatarPickerDialog(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      title: { title: '选择头像' },
      backgroundColor: $r('app.color.surface')
    })
  }

  // ======================== 页面头部 ========================
  @Builder
  PageHeader() {
    Column() {
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .margin({ top: 24, bottom: 12 })
  }

  // ======================== 用户信息卡片 ========================
  @Builder
  UserProfileCard() {
    Column() {
      // 头像区域
      Column() {
        // 圆形头像
        Column() {
          Text(this.avatarInitials[this.selectedAvatar])
            .fontSize(32)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor(this.avatarColors[this.selectedAvatar])
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showAvatarDialog = true;
        })
        .shadow({
          radius: 8,
          color: '#33000000',
          offsetX: 0,
          offsetY: 4
        })

        Text('点击更换头像')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.7)')
          .margin({ top: 6 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .alignItems(HorizontalAlign.Center)

      // 用户名
      Text(this.username)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 10 })

      // 身份信息行
      Row() {
        Text(`${this.identity}`)
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.85)')
        Text(' | ')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.6)')
        Text(`${this.grade}`)
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.85)')
      }
      .margin({ top: 6 })

      // 修改信息按钮
      Button('修改信息')
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor('rgba(255,255,255,0.2)')
        .borderRadius(18)
        .height(34)
        .padding({ left: 18, right: 18 })
        .margin({ top: 14 })
        .onClick(() => {
          // 打开弹窗时，重置输入为空（placeholder 显示原值），年级选中当前值
          this.editUsername = '';
          this.editIdentity = '';
          this.editGrade = this.grade;
          this.showEditDialog = true;
        })
    }
    .width('100%')
    .padding({ top: 24, bottom: 24, left: 20, right: 20 })
  }

  // ======================== 修改信息弹窗 ========================
  @Builder
  EditProfileDialog() {
      Column() {

        // 用户名输入 —— 显示原值为 placeholder，文本初始为空
        Column() {
          Text('用户名')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 6 })
            .width('100%')

          TextInput({ placeholder: `当前：${this.username}` })
            .fontSize(14)
            .placeholderColor($r('app.color.text_placeholder'))
            .backgroundColor($r('app.color.surface_subtle'))
            .borderRadius(8)
            .height(42)
            .padding({ left: 12, right: 12 })
            .width('100%')
            .onChange((value: string) => {
              this.editUsername = value;
            })
        }
        .width('100%')
        .margin({ bottom: 14 })

        // 身份信息输入
        Column() {
          Text('身份信息')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 6 })
            .width('100%')

          TextInput({ placeholder: `当前：${this.identity}` })
            .fontSize(14)
            .placeholderColor($r('app.color.text_placeholder'))
            .backgroundColor($r('app.color.surface_subtle'))
            .borderRadius(8)
            .height(42)
            .padding({ left: 12, right: 12 })
            .width('100%')
            .onChange((value: string) => {
              this.editIdentity = value;
            })
        }
        .width('100%')
        .margin({ bottom: 14 })

        // 年级选择
        Column() {
          Text('年级')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 6 })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.getAllGrades(), (gradeItem: string) => {
              Text(gradeItem)
                .fontSize(13)
                .fontColor(this.editGrade === gradeItem ? Color.White : $r('app.color.text_primary'))
                .backgroundColor(this.editGrade === gradeItem ? '#3B7DD8' : $r('app.color.surface_subtle'))
                .borderRadius(14)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.editGrade = gradeItem;
                })
            })
          }
          .width('100%')
        }
        .width('100%')
        .margin({ bottom: 10 })

        // 按钮行
        Row() {
          Button('取消')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface_subtle'))
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              this.showEditDialog = false;
            })

          Blank().width(12)

          Button('确认修改')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#3B7DD8')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              // 若用户未输入新内容，则保留原信息
              if (this.editUsername.trim() !== '') {
                this.username = this.editUsername.trim();
              }
              if (this.editIdentity.trim() !== '') {
                this.identity = this.editIdentity.trim();
              }
              this.grade = this.editGrade;
              // 重置编辑临时变量
              this.editUsername = '';
              this.editIdentity = '';
              this.showEditDialog = false;
            })
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: 24 })
  }

  // ======================== 头像选择弹窗 ========================
  @Builder
  AvatarPickerDialog() {
      Column() {

        // 头像网格（3列2行 = 6个备选头像）
        Grid() {
          ForEach(this.avatarColors, (color: string, index: number) => {
            GridItem() {
              Column() {
                Column() {
                  Text(this.avatarInitials[index])
                    .fontSize(28)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .width(60)
                .height(60)
                .borderRadius(30)
                .backgroundColor(color)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .border({
                  width: this.selectedAvatar === index ? 3 : 0,
                  color: '#3B7DD8',
                  style: BorderStyle.Solid
                })

                Text(this.avatarInitials[index])
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                this.selectedAvatar = index;
              })
            }
          })
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(16)
        .rowsGap(16)
        .width('100%')
        .height(200)
        .margin({ bottom: 16 })

        Button('确定')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#3B7DD8')
          .borderRadius(20)
          .height(42)
          .width('60%')
          .onClick(() => {
            this.showAvatarDialog = false;
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: 24 })
  }

  // ======================== 年级列表 ========================
  private getAllGrades(): string[] {
    return ['大一', '大二', '大三', '大四', '研一', '研二', '研三'];
  }

  // 1×1 小卡片
  @Builder
  WidgetSmall() {
    Column() {

      Text('知径学习助手')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)

      Text('点击快速对话')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.8)')
    }
    .width(160)
    .height(80)
    .padding(10)
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
    })
    .borderRadius(24)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
    .shadow({
      radius: 12,
      color: '#254A90D9',
      offsetX: 0,
      offsetY: 6
    })
    .onClick(() => {
      switchTab(2)
    })
  }

  // 2×2 中卡片
  @Builder
  WidgetMedium() {
    Column() {
      Row() {

        Text('当前学习任务')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('查看路径 →')
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .onClick(() => switchTab(3))
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column() {
        if (this.tasks.length === 0) {
          Text('暂无正在进行的任务，去学习助手 接受新的学习路径')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .onClick(() => switchTab(2))
        } else {
          Text(`已完成 ${this.doneTaskCount} / ${this.tasks.length} 个任务`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ bottom: 12 })
          ForEach(this.tasks, (task: StudyTask) => {
            this.TaskItem(task)
          }, (task: StudyTask) => task.kc.toString() + '_' + task.done.toString())
        }
      }
      .width('100%')
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  TaskItem(task: StudyTask) {
    Row() {
      Row() {
        Stack() {
          if (task.done) {
            Circle()
              .width(20)
              .height(20)
              .fill($r('app.color.success'))
            Text('✓')
              .fontSize(12)
              .fontColor(Color.White)
          } else {
            Circle()
              .width(20)
              .height(20)
              .fill($r('app.color.surface'))
              .stroke($r('app.color.divider'))
              .strokeWidth(2)
          }
        }
        .width(20)
        .height(20)
        .margin({ right: 10 })

        Text(task.name)
          .fontSize(13)
          .fontColor(task.done ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
          .decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => this.focusGraph(task.kc))

      if (!task.done) {
        Button('去做题')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand_solid'))
          .height(32)
          .margin({ left: 10 })
          .onClick(() => openPractice(task.kc))
      } else {
        Text('已完成任务')
          .fontSize(12)
          .fontColor($r('app.color.success'))
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  // 4×2 大卡片
  @Builder
  WidgetLarge() {
    Column() {
      Row() {

        Text('学习进度看板')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.StatWidget({ value: this.hasMastery ? this.overallMastery + '%' : '待诊断', label: AppState.isDsa() ? '预测答对率' : '综合掌握度' })
        this.StatWidget({ value: this.questionCount.toString(), label: '已做题目' })
        this.StatWidget({ value: (this.tasks.length - this.doneTaskCount).toString(), label: '待完成任务' })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      Row() {
        Button('问学习助手')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .linearGradient({
            angle: 135,
            colors: [[$r('app.color.brand_solid'), 0], [$r('app.color.brand_end'), 1]]
          })
          .fontColor(Color.White)
          .onClick(() => {
            switchTab(2)
          })

        Button('查看路径')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .backgroundColor($r('app.color.surface_subtle'))
          .fontColor($r('app.color.brand'))
          .margin({ left: 10 })
          .onClick(() => {
            switchTab(3)
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  StatWidget(params: StatWidgetParams) {
    Column() {
      Text(params.value)
        .fontSize(params.value === '待诊断' ? 16 : 24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand'))

      Text(params.label)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('32%')
    .padding({ left: 6, right: 6, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(16)
  }
}
