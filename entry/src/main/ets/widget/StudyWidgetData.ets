// Small, read-only projection of the existing plan. No answers or chat history.
export interface WidgetTask {
  kc: number;
  name: string;
  done: boolean;
  answered: number;
  total: number;
}

export interface StudyWidgetData {
  course: string;
  courseName: string;
  planId: number;
  total: number;
  done: number;
  percent: number;
  summary: string;
  emptyHint: string;
  tasks: WidgetTask[];
}

export function emptyStudyWidget(): StudyWidgetData {
  return {
    course: 'math', courseName: '小学数学', planId: 0,
    total: 0, done: 0, percent: 0, summary: '还没有学习待办',
    emptyHint: '打开知径，让 Agent 帮你生成学习计划', tasks: []
  };
}

export function buildStudyWidget(course: string, planId: number, tasks: WidgetTask[],
  completedCount: number): StudyWidgetData {
  const done = tasks.filter((task: WidgetTask) => task.done).length;
  const pending = tasks.filter((task: WidgetTask) => !task.done);
  const finished = tasks.filter((task: WidgetTask) => task.done);
  return {
    course: course, courseName: course === 'dsa' ? 'Java 数据结构' : '小学数学',
    planId: planId, total: tasks.length, done: done,
    percent: tasks.length > 0 ? Math.round(done * 100 / tasks.length) : 0,
    summary: tasks.length > 0 ? '已完成 ' + done + ' / ' + tasks.length + ' 项' :
      (completedCount > 0 ? '已完成 ' + completedCount + ' 条学习路径' : '还没有学习待办'),
    emptyHint: completedCount > 0 ? '本轮没有待办，打开应用继续规划学习' :
      '打开知径，让 Agent 帮你生成学习计划',
    tasks: pending.concat(finished).slice(0, 3)
  };
}
