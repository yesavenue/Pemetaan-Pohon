import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/view_models/surveyor_dashboard_data.dart';

void main() {
  TreeData tree(String id, String uid, DateTime date) => TreeData.fromMap(id, {
    'surveyorId': uid,
    'species': 'Ketapang',
    'timestamp': Timestamp.fromDate(date),
    'status': 'pending',
  });

  test(
    'Payload TreeData hanya menambah field ranah kewenangan yang disetujui',
    () {
      final data = tree('t1', 'u1', DateTime(2026, 10, 6)).toMap();
      expect(data.keys.toSet(), {
        'latitude',
        'longitude',
        'photoBase64',
        'surveyorId',
        'surveyorName',
        'species',
        'kecamatan',
        'kelurahan',
        'namaJalan',
        'ranahKewenangan',
        'condition',
        'keteranganKondisi',
        'timestamp',
        'status',
        'qrGenerated',
      });
      expect(data['status'], 'pending');
    },
  );

  test('Kewenangan: data lama, round-trip, edit lain, dan pengosongan', () {
    final legacy = tree('legacy', 'u1', DateTime(2026, 10, 8));
    expect(legacy.ranahKewenangan, isEmpty);
    for (final authority in [
      'Pusat',
      'Provinsi',
      'Kota Cirebon',
      'Kabupaten Cirebon',
      'Pengelola taman',
    ]) {
      final updated = legacy.copyWith(ranahKewenangan: authority);
      final readBack = TreeData.fromMap(updated.id, updated.toMap());
      expect(readBack.ranahKewenangan, authority);
      expect(readBack.copyWith(species: 'Mahoni').ranahKewenangan, authority);
      expect(
        readBack.copyWith(ranahKewenangan: '').toMap()['ranahKewenangan'],
        '',
      );
      expect(readBack.surveyorId, legacy.surveyorId);
      expect(readBack.status, legacy.status);
      expect(readBack.qrGenerated, legacy.qrGenerated);
    }
  });

  test('Dashboard memfilter pemilik dan mengurutkan tanpa mengubah sumber', () {
    final source = [
      tree('lama', 'u1', DateTime(2026, 10, 5)),
      tree('orang-lain', 'u2', DateTime(2026, 10, 6)),
      tree('baru', 'u1', DateTime(2026, 10, 6)),
    ];
    final data = SurveyorDashboardData.fromTrees(source, 'u1');
    expect(data.trees.map((t) => t.id).toList(), ['baru', 'lama']);
    expect(source.first.id, 'lama');
    expect(data.mappedToday(DateTime(2026, 10, 6)), 1);
    expect(data.mappedToday(DateTime(2026, 10, 7)), 0);
  });

  test('Edit field tampilan mempertahankan identitas dan verifikasi asli', () {
    final original = TreeData(
      id: 'pohon-asli',
      latitude: -6.7183,
      longitude: 108.5522,
      photoBase64: 'foto-lama',
      surveyorId: 'u1',
      surveyorName: 'Surveyor Asli',
      species: 'Ketapang',
      timestamp: DateTime(2026, 9, 24),
      status: TreeStatus.verified,
      qrGenerated: true,
    );
    final edited = original.copyWith(
      species: 'Mangga',
      namaJalan: 'Jl. Cipto',
      condition: TreeCondition.sakit,
      keteranganKondisi: 'Daun menguning',
      photoBase64: 'foto-baru',
    );
    expect(edited.id, original.id);
    expect(edited.surveyorId, original.surveyorId);
    expect(edited.surveyorName, original.surveyorName);
    expect(edited.timestamp, original.timestamp);
    expect(edited.status, TreeStatus.verified);
    expect(edited.qrGenerated, isTrue);
    expect(edited.toMap().keys.toSet(), original.toMap().keys.toSet());
    expect(edited.species, 'Mangga');
    expect(edited.photoBase64, 'foto-baru');
  });
  test('Ringkasan rawan tumbang hanya menghitung pohon milik surveyor', () {
    final now = DateTime(2026, 10, 6);
    final source = [
      tree(
        'milik-rawan',
        'u1',
        now,
      ).copyWith(condition: TreeCondition.rawanTumbang),
      tree('milik-sehat', 'u1', now),
      tree(
        'lain-rawan',
        'u2',
        now,
      ).copyWith(condition: TreeCondition.rawanTumbang),
    ];
    final data = SurveyorDashboardData.fromTrees(source, 'u1');
    expect(data.trees.length, 2);
    expect(data.mappedToday(now), 2);
    expect(data.atRiskCount, 1);
    expect(SurveyorDashboardData.fromTrees(source, 'u3').atRiskCount, 0);
  });
}