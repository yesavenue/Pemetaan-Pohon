import 'dart:convert';
import 'dart:io';
import 'package:pemetaan_pohon/utils/demo_tree_seed.dart';
import 'package:pemetaan_pohon/utils/cirebon_boundary.dart';

void check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void main(List<String> arguments) {
  final now = DateTime.utc(2026, 10, 8);
  final data = buildDemoTreeSeed(
    uid: 'admin',
    adminName: 'Admin Uji',
    now: now,
  );
  check(data.length == 30, 'Jumlah data harus 30');
  check(data.map((item) => item.id).toSet().length == 30, 'ID harus unik');
  final expected = {'sehat': 21, 'sakit': 6, 'rawanTumbang': 3};
  for (final condition in expected.entries) {
    check(
      data.where((item) => item.data['condition'] == condition.key).length ==
          condition.value,
      'Distribusi kondisi salah',
    );
  }
  check(
    data.map((e) => e.data['kecamatan']).toSet().length == 5,
    'Lima wilayah simulasi',
  );
  check(
    data.map((e) => e.data['ranahKewenangan']).toSet().length == 5,
    'Lima pilihan kewenangan',
  );
  final second = buildDemoTreeSeed(
    uid: 'admin',
    adminName: 'Admin Uji',
    now: now.add(const Duration(days: 1)),
  );
  for (var i = 0; i < data.length; i++) {
    final sample = data[i];
    check(sample.id == second[i].id, 'ID retry harus stabil');
    check(
      sample.id != demoTreeId('admin-lain', i),
      'ID antar akun harus berbeda',
    );
    check(
      isInsideCirebon(
        sample.data['latitude'] as double,
        sample.data['longitude'] as double,
      ),
      'Titik di luar Cirebon',
    );
    check(isOwnedDemoTree(sample.data, 'admin'), 'Tag contoh hilang');
    check(
      !isOwnedDemoTree(sample.data, 'admin-lain'),
      'Jangan hapus contoh akun lain',
    );
    check(
      !isOwnedDemoTree({
        ...sample.data,
        'keteranganKondisi': 'Data survei asli',
      }, 'admin'),
      'Jangan hapus data tanpa tag',
    );
    check(
      sample.data['status'] == 'verified' &&
          sample.data['qrGenerated'] == false,
      'Status/QR salah',
    );
    check(
      sample.data.keys.toSet().difference({
        'latitude',
        'longitude',
        'photoBase64',
        'surveyorId',
        'surveyorName',
        'species',
        'kecamatan',
        'kelurahan',
        'namaJalan',
        'condition',
        'keteranganKondisi',
        'ranahKewenangan',
        'timestamp',
        'status',
        'qrGenerated',
      }).isEmpty,
      'Field di luar skema',
    );
  }
  check(!isOwnedDemoTree(null, 'admin'), 'Dokumen kosong bukan contoh');
  if (arguments.contains('--json')) {
    stdout.writeln(
      jsonEncode([
        for (final item in data) {'id': item.id, 'data': item.data},
      ], toEncodable: (value) => (value as DateTime).toIso8601String()),
    );
  } else {
    stdout.writeln(
      'LULUS: 30 payload, 21/6/3 kondisi, 5 wilayah, 5 kewenangan, titik dalam batas, ID stabil/terpisah, guard penghapusan, field skema.',
    );
  }
}
