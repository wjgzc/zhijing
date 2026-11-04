// All sizes are window/content vp, never physical display pixels.
export class AdaptiveLayout {
  static navigationWidth(width: number): number {
    return width >= 1200 ? 200 : (width >= 600 ? 80 : 0);
  }

  static contentWidth(width: number): number {
    return Math.max(0, width - AdaptiveLayout.navigationWidth(width));
  }

  static split(width: number): boolean {
    return width >= 840;
  }
}
