import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { StudyWidgetStore } from '../widget/StudyWidgetStore';
import { widgetBinding } from '../widget/WidgetBinding';

export default class StudyFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const dimension = want.parameters?.[formInfo.FormParam.DIMENSION_KEY] as number;
    return widgetBinding(StudyWidgetStore.read(this.context.filesDir), dimension === 3 ? 3 : 2);
  }

  async onUpdateForm(formId: string): Promise<void> {
    try {
      const form = await formProvider.getPublishedRunningFormInfoById(formId);
      await formProvider.updateForm(formId,
        widgetBinding(StudyWidgetStore.read(this.context.filesDir), form.dimension));
    } catch (e) {
      console.error('[StudyWidget] 系统刷新待办卡片失败');
    }
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
