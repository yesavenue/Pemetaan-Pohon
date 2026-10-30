import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/screens/public_tracking_screen.dart';
import 'package:pemetaan_pohon/services/pruning_request_service.dart';

void main() {
  test('Kode akses menolak nomor berurutan dan input salah', () {
    expect(PruningRequestService.validAccessCode('REQ-000001'), isFalse);
    expect(PruningRequestService.validAccessCode('abcdefgh234567xy'), isTrue);
    expect(PruningRequestService.validAccessCode('abcdefgh'), isFalse);
    expect(PruningRequestService.validAccessCode('0' * 16), isFalse);
    expect(PruningRequestService.validAccessCode('a' * 64), isTrue);
    expect(PruningRequestService.validAccessCode('z' * 64), isFalse);
  });
  testWidgets('Status tetap ditampilkan ketika riwayat gagal', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PublicTrackingScreen(
      initialCode: 'abcdefgh234567xy',
      lookup: (_) async => {'requestNumber': 'REQ-000001', 'status': 'diproses',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 29)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 29))},
      loadHistory: (_) async => throw StateError('offline'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Diproses'), findsOneWidget);
    expect(find.textContaining('riwayat belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Kode tidak ditemukan ditangani tanpa menampilkan data lama', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PublicTrackingScreen(
      initialCode: 'b' * 64, lookup: (_) async => null,
      loadHistory: (_) async => [],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permohonan tidak ditemukan'), findsOneWidget);
    expect(find.text('Riwayat perkembangan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}