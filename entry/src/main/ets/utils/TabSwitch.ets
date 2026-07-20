let _controller: TabsController | null = null;

export function setTabsController(controller: TabsController): void {
  _controller = controller;
}

export function switchTab(index: number): void {
  _controller?.changeIndex(index);
}
