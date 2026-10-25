import { formBindingData } from '@kit.FormKit';
import { StudyWidgetData } from './StudyWidgetData';

export const STUDY_FORM_NAME: string = 'StudyTodo';

export function widgetBinding(data: StudyWidgetData, dimension: number): formBindingData.FormBindingData {
  return formBindingData.createFormBindingData({
    course: data.course, courseName: data.courseName, planId: data.planId,
    total: data.total, done: data.done, percent: data.percent,
    summary: data.summary, emptyHint: data.emptyHint,
    tasks: data.tasks, cardDimension: dimension === 3 ? 3 : 2
  });
}
