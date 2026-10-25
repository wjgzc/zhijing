import { formProvider } from '@kit.FormKit';
import { AppState } from '../model/AppState';
import { buildStudyWidget, StudyWidgetData, WidgetTask } from './StudyWidgetData';
import { StudyWidgetStore } from './StudyWidgetStore';
import { STUDY_FORM_NAME, widgetBinding } from './WidgetBinding';

export class StudyWidgetSync {
  private static filesDir: string = '';
  private static running: boolean = false;
  private static dirty: boolean = false;
  private static lastSnapshot: string = '';

  static start(filesDir: string): void {
    StudyWidgetSync.filesDir = filesDir;
    AppState.setStudyChangeListener(() => { StudyWidgetSync.publish(); });
    StudyWidgetSync.publish();
  }

  private static snapshot(): StudyWidgetData {
    const tasks: WidgetTask[] = AppState.getPlan().map((item): WidgetTask => {
      const questions = AppState.getTaskQuestions(item.kc);
      return {
        kc: item.kc, name: item.name, done: AppState.isDone(item.kc),
        answered: questions.filter((question) => question.answered).length,
        total: questions.length
      };
    });
    return buildStudyWidget(AppState.getCourse(), AppState.getActivePlanId(),
      tasks, AppState.getCompletedPlans().length);
  }

  static publish(force: boolean = false): void {
    if (StudyWidgetSync.filesDir.length === 0) { return; }
    const data = StudyWidgetSync.snapshot();
    const serialized = JSON.stringify(data);
    if (serialized !== StudyWidgetSync.lastSnapshot) {
      try {
        StudyWidgetStore.write(StudyWidgetSync.filesDir, data);
        StudyWidgetSync.lastSnapshot = serialized;
      } catch (e) {
        console.error('[StudyWidget] 保存待办快照失败');
        return;
      }
    } else if (!force) {
      return;
    }
    StudyWidgetSync.dirty = true;
    StudyWidgetSync.flush();
  }

  private static async flush(): Promise<void> {
    if (StudyWidgetSync.running) { return; }
    StudyWidgetSync.running = true;
    try {
      while (StudyWidgetSync.dirty) {
        StudyWidgetSync.dirty = false;
        const data = StudyWidgetStore.read(StudyWidgetSync.filesDir);
        const forms = await formProvider.getPublishedRunningFormInfos();
        for (const form of forms) {
          if (form.formName === STUDY_FORM_NAME && form.moduleName === 'entry') {
            try {
              await formProvider.updateForm(form.formId, widgetBinding(data, form.dimension));
            } catch (e) {
              console.error('[StudyWidget] 更新桌面卡片失败，系统刷新时将重试');
            }
          }
        }
      }
    } catch (e) {
      console.error('[StudyWidget] 获取桌面卡片失败，系统刷新时将重试');
    } finally {
      StudyWidgetSync.running = false;
    }
  }
}
