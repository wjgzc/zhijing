// Exercise the real profile store against an in-memory filesystem, including failed writes/copies.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || path.join(__dirname, '..');
const disk = new Map();
const descriptors = new Map();
let nextFd = 0;
let failRename = false;
let failCopy = false;
const io = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4, READ_ONLY: 8 },
  openSync(name) { const file = { fd: ++nextFd }; descriptors.set(file.fd, name); return file; },
  async open(name) { return this.openSync(name); },
  writeSync(fd, value) { disk.set(descriptors.get(fd), value); }, fsyncSync() {},
  closeSync(file) { descriptors.delete(file.fd); }, async close(file) { this.closeSync(file); },
  renameSync(from, to) {
    if (failRename) throw Error('disk unavailable');
    disk.set(to, disk.get(from)); disk.delete(from);
  },
  readTextSync(name) { if (!disk.has(name)) throw Error('missing'); return disk.get(name); },
  accessSync(name) { return disk.has(name); }, unlinkSync(name) { disk.delete(name); },
  async copyFile(fd, destination) {
    disk.set(destination, disk.get(descriptors.get(fd)));
    if (failCopy) throw Error('copy failed');
  }
};
const context = { exports: {}, require: () => ({ fileIo: io }) };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'entry/src/main/ets/model/UserProfileStore.ets'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
}).outputText, context);
const { UserProfileStore: store, avatarInitial } = context.exports;
async function main() {
  assert.equal(avatarInitial(' 林同学 '), '林');
  assert.equal(avatarInitial('😀同学'), '😀');
  assert.equal(avatarInitial(' '), '同');
  assert.equal(store.read('/app').username, '张三');
  disk.set('/app/user-profile.json', '{invalid');
  assert.equal(store.read('/app').avatarFile, '');
  const profile = { username: '林同学', grade: '大四', identity: '软件工程', avatarFile: '' };
  store.write('/app', profile);
  assert.equal(store.read('/app').username, '林同学');
  failRename = true;
  assert.throws(() => store.write('/app', { ...profile, username: '未提交' }));
  assert.equal(store.read('/app').username, '林同学', 'failed writes retain the committed profile');
  assert.equal(descriptors.size, 0);
  failRename = false;
  const uri = 'file://media/Photo/1/test.png';
  disk.set(uri, 'original-photo-bytes');
  const name = await store.importPhoto('/app', uri);
  assert.equal(disk.get('/app/' + name), 'original-photo-bytes');
  assert.equal(descriptors.size, 0);
  store.write('/app', { ...profile, avatarFile: name });
  assert.equal(store.read('/app').avatarFile, name);
  store.removePhoto('/app', '../outside');
  assert.equal(disk.get(uri), 'original-photo-bytes');
  store.removePhoto('/app', name);
  assert.equal(store.read('/app').avatarFile, '', 'missing photo falls back to nickname avatar');
  failCopy = true;
  await assert.rejects(store.importPhoto('/app', uri));
  assert.equal(descriptors.size, 0, 'failed copies close the picker descriptor');
  assert.ok(![...disk.keys()].some(name => /^\/app\/avatar-/.test(name)), 'partial photo copies are removed');
  assert.equal(disk.get(uri), 'original-photo-bytes', 'source gallery image is never modified');
  console.log('PASS: initials, corrupt/missing profile recovery, atomic write failure, private photo copy and failure cleanup.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
