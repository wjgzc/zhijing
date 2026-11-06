import { fileIo } from '@kit.CoreFileKit';

export interface UserProfile {
  username: string;
  grade: string;
  identity: string;
  avatarFile: string;
}

export function avatarInitial(username: string): string {
  return Array.from(username.trim())[0] ?? '同';
}

export class UserProfileStore {
  static defaults(): UserProfile {
    return { username: '张三', grade: '大三', identity: '计算机科学与技术', avatarFile: '' };
  }

  private static isAvatarFile(name: string): boolean {
    return /^avatar-\d+\.jpg$/.test(name);
  }

  static read(filesDir: string): UserProfile {
    const fallback = UserProfileStore.defaults();
    try {
      const saved = JSON.parse(fileIo.readTextSync(filesDir + '/user-profile.json')) as UserProfile;
      if (typeof saved.username === 'string' && saved.username.trim().length > 0) {
        fallback.username = saved.username.trim();
      }
      if (typeof saved.grade === 'string' && saved.grade.length > 0) { fallback.grade = saved.grade; }
      if (typeof saved.identity === 'string' && saved.identity.trim().length > 0) {
        fallback.identity = saved.identity.trim();
      }
      if (typeof saved.avatarFile === 'string' && UserProfileStore.isAvatarFile(saved.avatarFile) &&
        fileIo.accessSync(filesDir + '/' + saved.avatarFile)) {
        fallback.avatarFile = saved.avatarFile;
      }
    } catch (error) {
      // First launch, missing photo or an incomplete older profile uses the default avatar.
    }
    return fallback;
  }

  static write(filesDir: string, profile: UserProfile): void {
    const path = filesDir + '/user-profile.json';
    const file = fileIo.openSync(path + '.tmp',
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(profile));
      fileIo.fsyncSync(file.fd);
    } finally {
      fileIo.closeSync(file);
    }
    fileIo.renameSync(path + '.tmp', path);
  }

  static async importPhoto(filesDir: string, uri: string): Promise<string> {
    const name = 'avatar-' + Date.now().toString() + '.jpg';
    const source = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    try {
      // Copy bytes through the picker-granted descriptor; do not retain its temporary URI.
      await fileIo.copyFile(source.fd, filesDir + '/' + name);
    } catch (error) {
      UserProfileStore.removePhoto(filesDir, name);
      throw new Error('照片保存失败');
    } finally {
      await fileIo.close(source);
    }
    return name;
  }

  static removePhoto(filesDir: string, name: string): void {
    if (!UserProfileStore.isAvatarFile(name)) { return; }
    try { fileIo.unlinkSync(filesDir + '/' + name); } catch (error) { /* Already absent. */ }
  }
}
