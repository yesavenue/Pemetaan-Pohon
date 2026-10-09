import 'dart:convert';
import 'dart:math';
import 'cirebon_boundary.dart';
import 'cirebon_regions.dart';

const demoTreeCount = 30;
const demoTreeMarker = '[DATA CONTOH OTOMATIS v1]';

String demoTreeId(String uid, int index) =>
    'dummy_tree_v1_${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}_${index.toString().padLeft(2, '0')}';

/// Synthetic locations and district labels are only for exercising the UI.
/// Stable IDs allow retries without overwriting existing records.
List<({String id, Map<String, Object> data})> buildDemoTreeSeed({
  required String uid,
  required String adminName,
  required DateTime now,
  Map<String, String> photos = const {},
}) {
  if (uid.isEmpty) {
    throw ArgumentError('Akun admin diperlukan.');
  }
  final random = Random(481);
  final districts = cirebonKecamatanList;
  const species = [
    'Mahoni',
    'Mahoni',
    'Mahoni',
    'Trembesi',
    'Trembesi',
    'Angsana',
    'Ketapang Kencana',
    'Beringin',
    'Mangga',
    'Glodokan Tiang',
  ];
  const authorities = [
    'Pusat',
    'Provinsi',
    'Kota Cirebon',
    'Kabupaten Cirebon',
    'Pengelola taman contoh',
  ];
  return List.generate(demoTreeCount, (i) {
    double lat = 0, lng = 0;
    var found = false;
    for (var attempt = 0; attempt < 10000; attempt++) {
      lat = -6.775 + random.nextDouble() * .085;
      lng = 108.520 + random.nextDouble() * .045;
      if (isInsideCirebon(lat, lng)) {
        found = true;
        break;
      }
    }
    if (!found) {
      throw StateError(
        'Tidak berhasil membuat titik contoh di wilayah Cirebon.',
      );
    }
    final slot = (i + (i ~/ 10) * 3) % 10;
    final condition = slot < 7
        ? 'sehat'
        : slot < 9
        ? 'sakit'
        : 'rawanTumbang';
    final district = districts[i % districts.length];
    final villages = kelurahanFor(district);
    return (
      id: demoTreeId(uid, i),
      data: <String, Object>{
        'latitude': lat,
        'longitude': lng,
        'photoBase64': photos[condition] ?? '',
        'surveyorId': uid,
        'surveyorName': 'Admin: $adminName',
        'species': species[i % species.length],
        'kecamatan': district,
        'kelurahan': villages[(i ~/ districts.length) % villages.length],
        'namaJalan':
            'Lokasi simulasi ${(i + 1).toString().padLeft(2, '0')} — bukan hasil survei',
        'condition': condition,
        'keteranganKondisi':
            '$demoTreeMarker Ilustrasi untuk pengujian tampilan. Kondisi, koordinat dan pembagian wilayah merupakan simulasi, bukan hasil survei.',
        'ranahKewenangan': authorities[i % authorities.length],
        'timestamp': now.subtract(Duration(days: i % 14)),
        'status': 'verified',
        'qrGenerated': false,
      },
    );
  });
}

bool isOwnedDemoTree(Map<String, dynamic>? data, String uid) =>
    data != null &&
    data['surveyorId'] == uid &&
    data['keteranganKondisi'] is String &&
    (data['keteranganKondisi'] as String).startsWith(demoTreeMarker);