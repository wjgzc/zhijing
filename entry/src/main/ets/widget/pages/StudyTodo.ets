import { WidgetTask } from '../StudyWidgetData';

let storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct StudyTodo {
  @LocalStorageProp('course') course: string = 'math';
  @LocalStorageProp('courseName') courseName: string = '小学数学';
  @LocalStorageProp('planId') planId: number = 0;
  @LocalStorageProp('total') total: number = 0;
  @LocalStorageProp('done') done: number = 0;
  @LocalStorageProp('percent') percent: number = 0;
  @LocalStorageProp('summary') summary: string = '还没有学习待办';
  @LocalStorageProp('emptyHint') emptyHint: string = '打开知径，生成学习计划';
  @LocalStorageProp('tasks') tasks: WidgetTask[] = [];
  @LocalStorageProp('cardDimension') cardDimension: number = 2;

  private openTask(kc: number): void {
    postCardAction(this, {
      action: 'router', abilityName: 'EntryAbility',
      params: { source: 'study-widget', course: this.course, planId: this.planId, kc: kc }
    });
  }

  build() {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        Text('学习待办').fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1).maxLines(1)
        Text(this.course === 'dsa' ? 'Java' : '数学').fontSize(11).fontColor($r('app.color.brand'))
          .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor($r('app.color.brand_tint')).borderRadius(8)
      }.width('100%').onClick(() => { this.openTask(-1); })
      Text(this.summary).fontSize(11).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.total > 0) {
        Progress({ value: this.percent, total: 100, type: ProgressType.Linear })
          .width('100%').color($r('app.color.brand')).backgroundColor($r('app.color.divider')).height(4)
        Column({ space: 2 }) {
          ForEach(this.tasks.slice(0, this.cardDimension === 3 ? 3 : 2), (task: WidgetTask) => {
            Row({ space: 7 }) {
              Text(task.done ? '✓' : '○').fontSize(14).fontColor(task.done ? $r('app.color.success') : $r('app.color.brand'))
              Text(task.name).fontSize(12).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
              if (this.cardDimension === 3) {
                Text(task.done ? '已完成' : (task.total > 0 ? task.answered + '/' + task.total + ' 题' : '去练习'))
                  .fontSize(10).fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
            }.width('100%').layoutWeight(1).constraintSize({ minHeight: 18 })
              .onClick(() => { this.openTask(task.done ? -1 : task.kc); })
          }, (task: WidgetTask) => this.course + ':' + this.planId + ':' + task.kc + ':' +
            task.done + ':' + task.answered + ':' + task.total + ':' + task.name)
        }.width('100%').layoutWeight(1)
      } else {
        Text(this.emptyHint).fontSize(12).lineHeight(18)
          .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .onClick(() => { this.openTask(-1); })
      }
      Row() {
        Text(this.total > this.tasks.slice(0, this.cardDimension === 3 ? 3 : 2).length ?
          '查看全部 ' + this.total + ' 项' : '打开知径继续学习')
          .fontSize(10).fontColor($r('app.color.brand')).layoutWeight(1).maxLines(1)
        Text('›').fontSize(15).fontColor($r('app.color.brand'))
      }.width('100%').onClick(() => { this.openTask(-1); })
    }.width('100%').height('100%').padding(12)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg')).borderRadius(20)
      .alignItems(HorizontalAlign.Start)
  }
}
