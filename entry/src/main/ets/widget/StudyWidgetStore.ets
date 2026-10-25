import { fileIo } from '@kit.CoreFileKit';
import { emptyStudyWidget, StudyWidgetData } from './StudyWidgetData';

// Both abilities belong to the entry module and share its private filesDir.
// Atomic rename lets the form extension read a complete snapshot across processes.
export class StudyWidgetStore {
  static write(filesDir: string, data: StudyWidgetData): void {
    const path = filesDir + '/study-widget.json';
    const file = fileIo.openSync(path + '.tmp',
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(data));
      fileIo.fsyncSync(file.fd);
    } finally {
      fileIo.closeSync(file);
    }
    fileIo.renameSync(path + '.tmp', path);
  }

  static read(filesDir: string): StudyWidgetData {
    try {
      const data = JSON.parse(fileIo.readTextSync(filesDir + '/study-widget.json')) as StudyWidgetData;
      if ((data.course === 'math' || data.course === 'dsa') && Array.isArray(data.tasks) &&
        typeof data.planId === 'number' && typeof data.total === 'number') {
        return data;
      }
    } catch (e) {
      // The first widget can be added before the application has ever been opened.
    }
    return emptyStudyWidget();
  }
}
