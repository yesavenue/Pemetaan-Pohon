import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, runTransaction, Timestamp } from 'firebase/firestore';

// Test ini sengaja hanya mengizinkan emulator lokal + project demo.
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):[0-9]+$/.test(host)) {
  throw new Error('Jalankan npm test: emulator lokal wajib, bukan Firebase produksi.');
}
let env;
const stamp = Timestamp.fromMillis(1700000000000);
const user = (name, role = 'surveyor', isActive = true) => ({
  name, email: `${name}@example.test`, role, isActive, requiresPasswordChange: false,
});
const tree = (extra = {}) => ({
  latitude: -6.72, longitude: 108.56, photoBase64: 'YWJj',
  surveyorId: 'a', surveyorName: 'a', species: 'Mangga',
  kecamatan: 'Kejaksan', kelurahan: 'Kesenden', namaJalan: 'Jalan Uji',
  condition: 'sehat', keteranganKondisi: '', timestamp: stamp,
  status: 'pending', qrGenerated: false, ...extra,
});
const pruning = (extra = {}) => ({
  requestNumber: 'REQ-000001', namaPemohon: 'Pemohon Uji',
  alamatPemohon: 'Alamat uji', nomorHp: '081234567890', emailPemohon: 'uji@example.test',
  nik: '1234567890123456', alamatPohon: 'Jalan Uji', kecamatan: 'Kejaksan',
  kelurahan: 'Kesenden', alasan: 'Cabang perlu dirapikan', latitude: null, longitude: null,
  fotoPohonBase64: 'YWJj', fotoKtpBase64: 'YWJj', status: 'menunggu',
  alasanPenolakan: '', createdAt: stamp, updatedAt: stamp, ...extra,
});
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (uid, path) => doc(db(uid), path);

before(async () => {
  const [hostname, port] = host.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-pemetaan-pohon',
    firestore: { host: hostname, port: Number(port), rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const trusted = context.firestore();
    for (const [path, data] of [
      ['users/admin', user('admin', 'admin')], ['users/a', user('a')], ['users/b', user('b')],
      ['users/off', user('off', 'surveyor', false)], ['users/adminOff', user('adminOff', 'admin', false)],
      ['trees/own', tree()], ['trees/other', tree({ surveyorId: 'b', surveyorName: 'b' })],
      ['tree_pruning_requests/existing', pruning()], ['counters/tree_pruning_requests', { value: 1 }],
    ]) await setDoc(doc(trusted, path), data);
  });
});
after(async () => { if (env) await env.cleanup(); });

test('GIS publik dapat membaca dan query semua pohon', async () => {
  await assertSucceeds(getDoc(ref(null, 'trees/own')));
  await assertSucceeds(getDocs(collection(db(null), 'trees')));
});
test('Surveyor membuat pending milik sendiri', () => assertSucceeds(setDoc(ref('a', 'trees/new'), tree())));
for (const [label, uid, extra] of [
  ['anonim', null, {}], ['tanpa profil', 'unknown', {}], ['nonaktif', 'off', { surveyorId: 'off' }],
  ['pemilik lain', 'a', { surveyorId: 'b' }], ['verified', 'a', { status: 'verified' }],
  ['QR', 'a', { qrGenerated: true }], ['tanpa foto', 'a', { photoBase64: '' }],
  ['field tambahan', 'a', { role: 'admin' }], ['koordinat invalid', 'a', { latitude: 100 }],
  ['foto berlebihan', 'a', { photoBase64: 'x'.repeat(700001) }],
]) test(`Tolak create pohon: ${label}`, () => assertFails(setDoc(ref(uid, 'trees/new'), tree(extra))));
test('Surveyor update payload toMap lengkap', () => assertSucceeds(updateDoc(ref('a', 'trees/own'), tree({ species: 'Jambu' }))));
for (const [label, path, extra] of [
  ['pemilik lain', 'trees/other', { species: 'Jambu' }],
  ['mengambil kepemilikan', 'trees/other', { surveyorId: 'a' }],
  ['mengubah UID', 'trees/own', { surveyorId: 'b' }],
  ['mengubah nama surveyor', 'trees/own', { surveyorName: 'Palsu' }],
  ['mengubah timestamp', 'trees/own', { timestamp: Timestamp.fromMillis(1) }],
  ['verifikasi sendiri', 'trees/own', { status: 'verified' }],
  ['mengubah QR', 'trees/own', { qrGenerated: true }],
]) test(`Tolak update pohon: ${label}`, () => assertFails(updateDoc(ref('a', path), extra)));
test('Surveyor hanya delete miliknya', async () => {
  await assertFails(deleteDoc(ref('a', 'trees/other')));
  await assertSucceeds(deleteDoc(ref('a', 'trees/own')));
});
test('Akun nonaktif tidak menulis; admin nonaktif juga ditolak', async () => {
  await assertFails(updateDoc(ref('off', 'trees/own'), { species: 'Jambu' }));
  await assertFails(deleteDoc(ref('adminOff', 'trees/own')));
});
test('Admin membuat verified tanpa foto dan mengelola pohon', async () => {
  await assertSucceeds(setDoc(ref('admin', 'trees/new'), tree({ surveyorId: 'admin', surveyorName: 'Admin: admin', status: 'verified', photoBase64: '' })));
  await assertSucceeds(updateDoc(ref('admin', 'trees/own'), { status: 'verified' }));
  await assertSucceeds(updateDoc(ref('admin', 'trees/other'), tree({ surveyorId: 'b', surveyorName: 'b', species: 'Jambu' })));
  await assertSucceeds(deleteDoc(ref('admin', 'trees/own')));
});
test('Edit surveyor mempertahankan verified dari admin', async () => {
  await assertSucceeds(updateDoc(ref('admin', 'trees/own'), { status: 'verified' }));
  await assertSucceeds(updateDoc(ref('a', 'trees/own'), tree({ status: 'verified', species: 'Jambu' })));
});
test('Profil sendiri terbaca termasuk nonaktif; daftar hanya admin', async () => {
  await assertSucceeds(getDoc(ref('a', 'users/a')));
  await assertSucceeds(getDoc(ref('off', 'users/off')));
  await assertFails(getDoc(ref('a', 'users/b')));
  await assertFails(getDocs(collection(db('a'), 'users')));
  await assertSucceeds(getDocs(collection(db('admin'), 'users')));
});
test('Nama/email/sessionId sendiri dapat diubah', async () => {
  await assertSucceeds(updateDoc(ref('a', 'users/a'), { name: 'Nama Baru', email: 'baru@example.test', activeSessionId: 'session-123' }));
  await assertSucceeds(updateDoc(ref('a', 'users/a'), { requiresPasswordChange: false }));
});
for (const [label, path, extra] of [
  ['menjadi admin', 'users/a', { role: 'admin' }], ['aktifkan sendiri', 'users/off', { isActive: true }],
  ['ubah sesi orang lain', 'users/b', { activeSessionId: 'palsu' }],
  ['field tambahan', 'users/a', { unexpected: true }],
]) test(`Tolak profil: ${label}`, () => assertFails(updateDoc(ref(path === 'users/off' ? 'off' : 'a', path), extra)));
test('Klien tidak dapat create/delete profil sendiri', async () => {
  await assertFails(setDoc(ref('unknown', 'users/unknown'), user('unknown', 'admin')));
  await assertFails(deleteDoc(ref('a', 'users/a')));
});
test('Admin membuat, menamai, menonaktifkan, menghapus surveyor', async () => {
  await assertSucceeds(setDoc(ref('admin', 'users/new'), { ...user('new'), requiresPasswordChange: true }));
  await assertSucceeds(updateDoc(ref('admin', 'users/new'), { name: 'Baru', isActive: false }));
  await assertSucceeds(deleteDoc(ref('admin', 'users/new')));
  await assertFails(setDoc(ref('admin', 'users/anotherAdmin'), user('anotherAdmin', 'admin')));
  await assertFails(updateDoc(ref('admin', 'users/a'), { role: 'admin' }));
  await assertFails(deleteDoc(ref('admin', 'users/admin')));
});
test('Login pertama boleh melepas flag dan mendaftarkan sesi', async () => {
  await assertSucceeds(setDoc(ref('admin', 'users/new'), { ...user('new'), requiresPasswordChange: true }));
  await assertSucceeds(updateDoc(ref('new', 'users/new'), { activeSessionId: 'login-first' }));
  await assertSucceeds(updateDoc(ref('new', 'users/new'), { requiresPasswordChange: false }));
});
test('Public membuat permohonan valid tanpa GPS atau dengan GPS', async () => {
  await assertSucceeds(setDoc(ref(null, 'tree_pruning_requests/new'), pruning()));
  await assertSucceeds(setDoc(ref(null, 'tree_pruning_requests/gps'), pruning({ latitude: -6.72, longitude: 108.56 })));
});
for (const [label, extra] of [
  ['status palsu', { status: 'selesai' }], ['NIK invalid', { nik: 'abc' }], ['nomor invalid', { requestNumber: 'palsu' }],
  ['KTP kosong', { fotoKtpBase64: '' }], ['foto terlalu besar', { fotoPohonBase64: 'x'.repeat(350001) }],
  ['GPS parsial', { latitude: -6.72 }], ['field tambahan', { approved: true }],
]) test(`Tolak permohonan: ${label}`, () => assertFails(setDoc(ref(null, 'tree_pruning_requests/new'), pruning(extra))));
test('NIK/KTP hanya admin; surveyor/anonim tidak dapat baca/query/update/delete', async () => {
  for (const uid of [null, 'a', 'adminOff']) {
    await assertFails(getDoc(ref(uid, 'tree_pruning_requests/existing')));
    await assertFails(getDocs(collection(db(uid), 'tree_pruning_requests')));
    await assertFails(updateDoc(ref(uid, 'tree_pruning_requests/existing'), { status: 'selesai' }));
    await assertFails(deleteDoc(ref(uid, 'tree_pruning_requests/existing')));
  }
  await assertSucceeds(getDocs(collection(db('admin'), 'tree_pruning_requests')));
});
test('Admin hanya mengubah status/alasan/tanggal permohonan', async () => {
  await assertSucceeds(updateDoc(ref('admin', 'tree_pruning_requests/existing'), { status: 'ditolak', alasanPenolakan: 'Alasan uji', updatedAt: stamp }));
  await assertFails(updateDoc(ref('admin', 'tree_pruning_requests/existing'), { nik: '0000000000000000' }));
  await assertFails(updateDoc(ref('admin', 'tree_pruning_requests/existing'), { status: 'palsu' }));
  await assertSucceeds(deleteDoc(ref('admin', 'tree_pruning_requests/existing')));
});
test('Counter publik transaksi +1 kompatibel', async () => {
  const firestore = db(null);
  const counter = doc(firestore, 'counters/tree_pruning_requests');
  await assertSucceeds(runTransaction(firestore, async (tx) => {
    // Ref dan transaction menggunakan instance database yang sama.
    const snapshot = await tx.get(counter);
    tx.set(counter, { value: snapshot.data().value + 1 });
  }));
  assert.equal((await getDoc(counter)).data().value, 2);
});
test('Counter kosong mulai 1; dokumen lain/create angka palsu ditolak', async () => {
  await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), 'counters/tree_pruning_requests')));
  await assertFails(setDoc(ref(null, 'counters/tree_pruning_requests'), { value: 99 }));
  await assertSucceeds(setDoc(ref(null, 'counters/tree_pruning_requests'), { value: 1 }));
  await assertFails(setDoc(ref(null, 'counters/other'), { value: 1 }));
});
test('Counter tidak dapat list/delete/reset/lompat/menambah field', async () => {
  const counter = ref(null, 'counters/tree_pruning_requests');
  await assertFails(getDocs(collection(db(null), 'counters')));
  await assertFails(getDoc(ref(null, 'counters/other')));
  await assertFails(deleteDoc(counter));
  await assertFails(setDoc(counter, { value: 0 }));
  await assertFails(setDoc(counter, { value: 50 }));
  await assertFails(setDoc(counter, { value: 2, extra: true }));
  await assertFails(setDoc(counter, { value: 2.5 }));
});
test('Koleksi tak dikenal ditolak', async () => {
  await assertFails(setDoc(ref('admin', 'unknown/test'), { value: true }));
  await assertFails(getDoc(ref('admin', 'unknown/test')));
});

// Optional authority metadata must never grant a role or relax ownership.
for (const value of ['', 'Pusat', 'Provinsi', 'Kota Cirebon', 'Kabupaten Cirebon', 'Pengelola taman']) {
  test(`Kewenangan diterima: ${value || 'belum diketahui'}`, () =>
    assertSucceeds(setDoc(ref('a', 'trees/authority'), tree({ ranahKewenangan: value }))));
}
for (const value of [null, 42, {}, 'x'.repeat(121)]) {
  test(`Kewenangan invalid ditolak: ${JSON.stringify(value).slice(0, 25)}`, () =>
    assertFails(setDoc(ref('a', 'trees/authority'), tree({ ranahKewenangan: value }))));
}
test('Kewenangan dapat diisi dan dikosongkan pemilik; bukan akses admin', async () => {
  await assertSucceeds(updateDoc(ref('a', 'trees/own'), { ranahKewenangan: 'Pusat' }));
  await assertSucceeds(updateDoc(ref('a', 'trees/own'), { ranahKewenangan: '' }));
  await assertFails(updateDoc(ref('a', 'trees/other'), { ranahKewenangan: 'Pusat' }));
  await assertFails(updateDoc(ref(null, 'trees/own'), { ranahKewenangan: 'Pusat' }));
  await assertFails(updateDoc(ref('off', 'trees/own'), { ranahKewenangan: 'Pusat' }));
  await assertFails(updateDoc(ref('a', 'trees/own'), { ranahKewenangan: 'Pusat', status: 'verified' }));
});