export interface WidgetLaunchRequest {
  source: string;
  course: string;
  planId: number;
  kc: number;
}

export function parseWidgetLaunch(parameters: Record<string, Object> | undefined): WidgetLaunchRequest | null {
  if (!parameters) { return null; }
  try {
    const raw = parameters['params'];
    const request = (typeof raw === 'string' ? JSON.parse(raw) : raw) as WidgetLaunchRequest;
    if (!request || request.source !== 'study-widget' ||
      (request.course !== 'math' && request.course !== 'dsa') ||
      !Number.isInteger(request.planId) || request.planId < 0 ||
      !Number.isInteger(request.kc) || request.kc < -1) { return null; }
    return request;
  } catch (e) {
    return null;
  }
}

export function queueWidgetLaunch(parameters: Record<string, Object> | undefined): void {
  const request = parseWidgetLaunch(parameters);
  if (!request) { return; }
  AppStorage.setOrCreate('widgetLaunchPending', JSON.stringify(request));
  AppStorage.setOrCreate('widgetLaunchSeq', (AppStorage.get<number>('widgetLaunchSeq') ?? 0) + 1);
}
