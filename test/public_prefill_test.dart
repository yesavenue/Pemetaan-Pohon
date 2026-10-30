import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_pruning_request_screen.dart';

void main() {
  testWidgets('Pengajuan dari pohon mengisi lokasi dan wilayah', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicPruningRequestScreen(
          initialTree: TreeData(
            id: 'tree-123',
            latitude: -6.72,
            longitude: 108.55,
            photoBase64: '',
            surveyorId: 's',
            surveyorName: 'S',
            species: 'Angsana',
            kecamatan: 'Kesambi',
            kelurahan: 'Kesambi',
            namaJalan: 'Jalan Uji',
            timestamp: DateTime(2026),
            status: TreeStatus.verified,
          ),
          createRequest: (_) async => 'REQ-000001',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final labels = {
      'Nama Lengkap *': 'Warga Uji',
      'Alamat Pemohon *': 'Jalan Warga',
      'Nomor HP *': '081234567890',
      'Email *': 'uji@example.com',
      'Nomor KTP/NIK *': '1234567890123456',
    };
    for (final e in labels.entries) {
      final f = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == e.key,
      );
      await tester.ensureVisible(f);
      await tester.enterText(f, e.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    final address = tester.widget<TextField>(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Alamat/Lokasi Pohon *',
      ),
    );
    expect(address.controller!.text, contains('tree-123'));
    expect(address.controller!.text, contains('Jalan Uji'));
    expect(find.textContaining('Koordinat pohon:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}