import { promptAction } from '@kit.ArkUI';
import { switchTab } from '../utils/TabSwitch';

@Component
export struct KnowledgeGraph {
  @State selectedNode: string = '数组';
  @State selectedNodeStatus: string = 'learned';
  @State panOffsetX: number = 0;
  @State panOffsetY: number = 0;

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

      Column() {
        Text('知识图谱')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')

        Text('数据结构')
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
      // 节点 — 直接放在Stack内，.position()相对Stack

      // 第一层
      this.GraphNode('数据结构', 'root', 100, 48, 130, 20)

      // 第二层
      this.GraphNode('数组 ✅', 'learned', 80, 44, 40, 110)
      this.GraphNode('链表 🔄', 'learning', 80, 44, 200, 110)

      // 第三层
      this.GraphNode('树 ⏳', 'locked', 80, 44, 20, 220)
      this.GraphNode('图 ⏳', 'locked', 80, 44, 140, 220)
      this.GraphNode('队列', 'locked', 80, 44, 260, 220)
    }
    .width('100%')
    .layoutWeight(1)
    .offset({ x: this.panOffsetX, y: this.panOffsetY })
    .gesture(
      PanGesture({ fingers: 1 })
        .onActionUpdate((event: GestureEvent) => {
          this.panOffsetX += event.offsetX;
          this.panOffsetY += event.offsetY;
        })
    )
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

  getDescription(nodeName: string): string {
    const descriptions: Record<string, string> = {
      '数据结构': '所有数据结构的基础概念，涵盖数据组织、存储和操作的基本原理。',
      '数组': '基础线性结构，元素按顺序存储，支持随机访问。是理解其他数据结构的基础。',
      '链表': '由节点组成的线性结构，每个节点包含数据和指向下一节点的指针。插入删除高效。',
      '树': '层次化的非线性结构，由节点和边组成。二叉树、搜索树是最常见的形式。',
      '图': '由顶点和边组成的非线性结构，可表示复杂的网络关系，支持多种遍历算法。',
      '队列': '先进先出(FIFO)的线性结构，元素在队尾入队、队首出队。常用于任务调度。'
    };
    return descriptions[nodeName] ?? '点击图谱中的节点查看详细介绍';
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

      Text(this.getDescription(this.selectedNode))
        .fontSize(13)
        .fontColor('#8E92A4')
        .lineHeight(20)
        .width('100%')
        .margin({ bottom: 16 })

      Button('开始学习')
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