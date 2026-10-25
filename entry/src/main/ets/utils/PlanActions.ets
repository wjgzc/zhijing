import { promptAction } from '@kit.ArkUI';
import { AppState, WeakKc } from '../model/AppState';
import { requestReplan } from './TabSwitch';

export async function cancelCurrentPlan(regenerate: boolean = false): Promise<void> {
  const planId = AppState.getActivePlanId();
  if (planId === 0) {
    if (regenerate) {
      requestReplan();
    }
    return;
  }
  const previousPath = AppState.getPlan().map((item: WeakKc) => item.name).join(' → ');
  try {
    const result = await promptAction.showDialog({
      title: regenerate ? '重新规划学习路径' : '取消当前路径',
      message: '当前路径及任务进度将被取消，已做题目、掌握度和已完成路径会保留。' +
        (regenerate ? 'Agent 将生成新的建议，接受后开始新路径。' : ''),
      buttons: [
        { text: '继续当前路径', color: '#8E92A4' },
        { text: regenerate ? '取消并重新生成' : '确认取消', color: '#E85D75' }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    // 对话框期间路径可能已经完成或更新，不能取消另一条路径。
    if (!AppState.cancelPlan(planId)) {
      promptAction.showToast({ message: '路径已发生变化，请重新操作', duration: 2000 });
      return;
    }
    if (regenerate) {
      requestReplan(previousPath);
    } else {
      promptAction.showToast({ message: '已取消当前路径，学习记录已保留', duration: 2000 });
    }
  } catch (error) {
    console.error('[PlanActions] 路径操作未完成:', (error as Error).message);
  }
}
