let _controller: TabsController | null = null;

export function setTabsController(controller: TabsController): void {
  _controller = controller;
}

export function switchTab(index: number): void {
  _controller?.changeIndex(index);
}

export function openPractice(kc: number, qid: number = -1): void {
  AppStorage.setOrCreate('practiceKcId', kc);
  AppStorage.setOrCreate('practiceQid', qid);
  const seq = (AppStorage.get<number>('practiceSeq') ?? 0) + 1;
  AppStorage.setOrCreate('practiceSeq', seq);
  switchTab(1);
}

export function requestReplan(previousPath: string = ''): void {
  AppStorage.setOrCreate('replanPreviousPath', previousPath);
  const seq = (AppStorage.get<number>('replanSeq') ?? 0) + 1;
  AppStorage.setOrCreate('replanSeq', seq);
  switchTab(2);
}
