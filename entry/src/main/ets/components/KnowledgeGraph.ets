import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';

@Component
export struct KnowledgeGraph {
  @State selectedNode: string = '数组';
  @State selectedNodeStatus: string = 'learned';

  build() {
    Column() {
      // 页面头部
      this.PageHeader()

      // 图谱区域
      this.GraphArea()

      // 底部详情面板
      this.DetailPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
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
        Text('知识图谱')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')

        Text('数据结构 · 共24个知识点')
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
  GraphArea() {
    Stack() {
      Column() {
        // 根节点
        this.GraphNode('数据结构', 'root', 100, 48, 130, 20)

        // 第二层
        Row() {
          this.GraphNode('数组 ✅', 'learned', 80, 44, 40, 110)
          this.GraphNode('链表 🔄', 'learning', 80, 44, 200, 110)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)

        // 第三层
        Row() {
          this.GraphNode('树 ⏳', 'locked', 80, 44, 20, 220)
          this.GraphNode('图 ⏳', 'locked', 80, 44, 140, 220)
          this.GraphNode('队列', 'locked', 80, 44, 260, 220)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
      }
      .width('100%')
      .height(300)
      .padding({ top: 20 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  GraphNode(name: string, status: string, w: number, h: number, x: number, y: number) {
    Button() {
      Text(name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(
          status === 'root' || status === 'learned' || status === 'learning'
            ? Color.White : '#8E92A4'
        )
    }
    .width(w)
    .height(h)
    .backgroundColor(
      status === 'root' ? '#4A90D9' :
        status === 'learned' ? '#7ED321' :
          status === 'learning' ? '#F5A623' :
            Color.White
    )
    .border({
      width: status === 'locked' ? 2 : 0,
      color: '#D0D0D0',
      style: status === 'locked' ? BorderStyle.Dashed : BorderStyle.Solid
    })
    .borderRadius(14)
    .shadow({
      radius: 8,
      color: '#15000000',
      offsetX: 0,
      offsetY: 4
    })
    .position({ x: x, y: y })
    .onClick(() => {
      this.selectedNode = name.replace(/[✅🔄⏳]/g, '').trim();
      this.selectedNodeStatus = status;
    })
    .scale({ x: 1, y: 1 })
    .animation({
      duration: 300,
      curve: Curve.EaseOut
    })
  }

  @Builder
  DetailPanel() {
    Column() {
      Text('📖 ' + this.selectedNode)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .width('100%')
        .margin({ bottom: 8 })

      Text('基础线性结构，元素按顺序存储，支持随机访问。是理解其他数据结构的基础。')
        .fontSize(13)
        .fontColor('#8E92A4')
        .lineHeight(20)
        .width('100%')
        .margin({ bottom: 16 })

      Row() {
        Button('开始学习')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(44)
          .borderRadius(14)
          .linearGradient({
            angle: 135,
            colors: [['#4A90D9', 0], ['#6BA8E8', 1]]
          })
          .fontColor(Color.White)

        Button('加入路径')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(44)
          .borderRadius(14)
          .backgroundColor('#F0F4F8')
          .fontColor('#4A90D9')
          .margin({ left: 12 })
      }
      .width('100%')
    }
    .width('90%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: '#15000000',
      offsetX: 0,
      offsetY: -4
    })
    .margin({ bottom: 80 })
  }
}