import { switchTab } from '../utils/TabSwitch';

@Component
export struct ServiceWidget {
  // 原有状态
  @State task1Done: boolean = true;
  @State task2Done: boolean = false;
  @State task3Done: boolean = false;

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
  private avatarColors: string[] = [
    '#4A90D9', '#E85D75', '#5CB85C', '#F0AD4E', '#9B59B6', '#1ABC9C'
  ];
  // 头像对应首字母
  private avatarInitials: string[] = [
    '张', '李', '王', '赵', '孙', '周'
  ];

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

          Blank().height(100)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
      .scrollBar(BarState.Off)

    // 修改信息弹窗
    if (this.showEditDialog) {
      this.EditProfileDialog()
    }

    // 头像选择弹窗
    if (this.showAvatarDialog) {
      this.AvatarPickerDialog()
    }
    }
  }

  // ======================== 页面头部 ========================
  @Builder
  PageHeader() {
    Column() {
      Text('服务卡片')
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
    Stack() {
      // 半透明遮罩（点击关闭）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          this.showEditDialog = false;
        })

      // 弹窗内容（阻止冒泡）
      Column() {
        Text('修改个人信息')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        // 用户名输入 —— 显示原值为 placeholder，文本初始为空
        Column() {
          Text('用户名')
            .fontSize(13)
            .fontColor('#888')
            .margin({ bottom: 6 })
            .width('100%')

          TextInput({ placeholder: `当前：${this.username}` })
            .fontSize(14)
            .placeholderColor('#A0A0A0')
            .backgroundColor('#F8F8F8')
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
            .fontColor('#888')
            .margin({ bottom: 6 })
            .width('100%')

          TextInput({ placeholder: `当前：${this.identity}` })
            .fontSize(14)
            .placeholderColor('#A0A0A0')
            .backgroundColor('#F8F8F8')
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
            .fontColor('#888')
            .margin({ bottom: 6 })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.getAllGrades(), (gradeItem: string) => {
              Text(gradeItem)
                .fontSize(13)
                .fontColor(this.editGrade === gradeItem ? Color.White : '#555')
                .backgroundColor(this.editGrade === gradeItem ? '#3B7DD8' : '#F0F0F0')
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
            .fontColor('#888')
            .backgroundColor('#F0F0F0')
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
      .width('88%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(24)
      .shadow({
        radius: 16,
        color: '#40000000',
        offsetX: 0,
        offsetY: 8
      })
      .onClick(() => {
        // 阻止事件冒泡到遮罩
      })
    }
    .width('100%')
    .height('100%')
  }

  // ======================== 头像选择弹窗 ========================
  @Builder
  AvatarPickerDialog() {
    Stack() {
      // 半透明遮罩（点击关闭）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          this.showAvatarDialog = false;
        })

      // 弹窗内容（阻止冒泡）
      Column() {
        Text('选择头像')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

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
                  .fontColor('#888')
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
      .width('82%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(24)
      .shadow({
        radius: 16,
        color: '#40000000',
        offsetX: 0,
        offsetY: 8
      })
      .onClick(() => {
        // 阻止事件冒泡到遮罩
      })
    }
    .width('100%')
    .height('100%')
  }

  // ======================== 年级列表 ========================
  private getAllGrades(): string[] {
    return ['大一', '大二', '大三', '大四', '研一', '研二', '研三'];
  }

  // 1×1 小卡片
  @Builder
  WidgetSmall() {
    Column() {

      Text('知径Agent')
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
      colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
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

        Text('今日学习任务')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column() {
        Column() {
          this.TaskItem('数组复习（已完成）', this.task1Done)
        }
        .width('100%')
        .onClick(() => { this.task1Done = !this.task1Done })

        Column() {
          this.TaskItem('链表插入操作练习', this.task2Done)
        }
        .width('100%')
        .onClick(() => { this.task2Done = !this.task2Done })

        Column() {
          this.TaskItem('链表删除操作练习', this.task3Done)
        }
        .width('100%')
        .onClick(() => { this.task3Done = !this.task3Done })
      }
      .width('100%')
    }
    .width(335)
    .height(160)
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  TaskItem(text: string, done: boolean) {
    Row() {
      Stack() {
        if (done) {
          Circle()
            .width(20)
            .height(20)
            .fill('#7ED321')
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White)
        } else {
          Circle()
            .width(20)
            .height(20)
            .fill(Color.White)
            .stroke('#E8E8E8')
            .strokeWidth(2)
        }
      }
      .width(20)
      .height(20)
      .margin({ right: 10 })

      Text(text)
        .fontSize(13)
        .fontColor(done ? '#8E92A4' : '#1A1A2E')
        .decoration({ type: done ? TextDecorationType.LineThrough : TextDecorationType.None })
        .layoutWeight(1)
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
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.StatWidget('68%', '掌握度')
        this.StatWidget('12', '连续天')
        this.StatWidget('3', '今日任务')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      Row() {
        Button('问Agent')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
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
          .backgroundColor('#F0F4F8')
          .fontColor('#4A90D9')
          .margin({ left: 10 })
          .onClick(() => {
            switchTab(3)
          })
      }
      .width('100%')
    }
    .width(335)
    .height(200)
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  StatWidget(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A90D9')

      Text(label)
        .fontSize(11)
        .fontColor('#8E92A4')
        .margin({ top: 4 })
    }
    .width('30%')
    .padding(12)
    .backgroundColor('#F7F9FC')
    .borderRadius(16)
  }
}