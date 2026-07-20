/**
 * 学习计划数据模型 - 使用单例模式 + AppStorage 实现跨页面数据共享
 */

// 用户信息接口
export interface UserInfo {
  username: string;
  isLoggedIn: boolean;
}

// 学习数据类
export class StudyData {
  correctQuestions: string[] = [];
  wrongQuestions: string[] = [];
  studyPlan: string = '';

  constructor() {
    this.studyPlan = '暂无学习计划，请先导入做题数据';
  }

  // 添加正确题号
  addCorrectQuestions(questions: string[]): void {
    for (const q of questions) {
      if (!this.correctQuestions.includes(q)) {
        this.correctQuestions.push(q);
      }
      // 从错误列表中移除（如果存在）
      const wrongIdx = this.wrongQuestions.indexOf(q);
      if (wrongIdx !== -1) {
        this.wrongQuestions.splice(wrongIdx, 1);
      }
    }
    this.generateStudyPlan();
  }

  // 添加错误题号
  addWrongQuestions(questions: string[]): void {
    for (const q of questions) {
      if (!this.wrongQuestions.includes(q)) {
        this.wrongQuestions.push(q);
      }
      // 从正确列表中移除（如果存在）
      const correctIdx = this.correctQuestions.indexOf(q);
      if (correctIdx !== -1) {
        this.correctQuestions.splice(correctIdx, 1);
      }
    }
    this.generateStudyPlan();
  }

  // 根据数据生成学习计划
  generateStudyPlan(): void {
    if (this.correctQuestions.length === 0 && this.wrongQuestions.length === 0) {
      this.studyPlan = '暂无学习计划，请先导入做题数据';
      return;
    }

    let plan = '';
    const totalCorrect = this.correctQuestions.length;
    const totalWrong = this.wrongQuestions.length;
    const total = totalCorrect + totalWrong;
    const accuracy = total > 0 ? Math.round((totalCorrect / total) * 100) : 0;

    plan += `📊 学习概况\n`;
    plan += `已完成题目：${total} 道\n`;
    plan += `正确率：${accuracy}%\n\n`;

    if (totalWrong > 0) {
      plan += `🎯 今日学习建议\n`;
      plan += `需重点复习 ${totalWrong} 道错题\n`;
      if (totalWrong <= 10) {
        plan += `建议今日全部复习一遍\n`;
      } else if (totalWrong <= 30) {
        plan += `建议分3天复习，每天约${Math.ceil(totalWrong / 3)}道\n`;
      } else {
        plan += `建议分7天复习，每天约${Math.ceil(totalWrong / 7)}道\n`;
      }
    }

    if (totalCorrect > 0 && totalWrong === 0) {
      plan += `🎉 太棒了！所有已做题目全部正确！\n`;
      plan += `建议继续练习新的题目`;
    }

    this.studyPlan = plan;
  }

  // 获取总题数
  getTotalCount(): number {
    return this.correctQuestions.length + this.wrongQuestions.length;
  }

  // 获取正确率
  getAccuracy(): number {
    const total = this.getTotalCount();
    if (total === 0) {
      return 0;
    }
    return Math.round((this.correctQuestions.length / total) * 100);
  }

  // 清空数据
  clearAll(): void {
    this.correctQuestions = [];
    this.wrongQuestions = [];
    this.studyPlan = '暂无学习计划，请先导入做题数据';
  }
}

// 全局单例管理
export class AppStateManager {
  private static studyData: StudyData = new StudyData();
  private static userInfo: UserInfo = { username: '', isLoggedIn: false };

  static getStudyData(): StudyData {
    return AppStateManager.studyData;
  }

  static getUserInfo(): UserInfo {
    return AppStateManager.userInfo;
  }

  static setUserInfo(info: UserInfo): void {
    AppStateManager.userInfo = info;
  }

  static login(username: string, password: string): boolean {
    // 简单模拟登录：用户名和密码非空即成功
    if (username.trim().length > 0 && password.trim().length > 0) {
      AppStateManager.userInfo = { username: username.trim(), isLoggedIn: true };
      return true;
    }
    return false;
  }

  static logout(): void {
    AppStateManager.userInfo = { username: '', isLoggedIn: false };
  }
}
