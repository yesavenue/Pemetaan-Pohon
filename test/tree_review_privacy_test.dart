import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/widgets/surveyor/review_inbox.dart';

TreeData rejected({
  DateTime? readAt,
  TreeStatus status = TreeStatus.rejected,
}) => TreeData(
  id: 'tree-1',
  latitude: -6.7,
  longitude: 108.5,
  photoBase64: '',
  surveyorId: 'private-owner',
  surveyorName: 'Private Name',
  species: 'Mahoni',
  timestamp: DateTime(2026),
  status: status,
  rejectionReason: 'Foto perlu diperjelas.',
  reviewedAt: DateTime(2026, 10, 10),
  reviewReadAt: readAt,
  revision: 3,
);

void main() {
  test(
    'Proyeksi memakai allowlist dan tidak membawa identitas atau review',
    () {
      final source = rejected(status: TreeStatus.verified);
      final public = source.toPublicMap();
      expect(public.keys.toSet(), {
        'latitude',
        'longitude',
        'photoBase64',
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
      final decoded = TreeData.fromMap(source.id, public);
      expect(decoded.surveyorId, isEmpty);
      expect(decoded.surveyorName, isEmpty);
      expect(decoded.rejectionReason, isEmpty);
      expect(decoded.reviewedAt, isNull);
      expect(source.surveyorId, 'private-owner');
    },
  );

  test('Dokumen lama terbaca dan status rejected round trip', () {
    final legacy = TreeData.fromMap('old', {
      'species': 'Mahoni',
      'timestamp': Timestamp.fromDate(DateTime(2026)),
      'status': 'verified',
    });
    expect(legacy.revision, 0);
    expect(legacy.hasUnreadReview, isFalse);
    final source = rejected();
    final restored = TreeData.fromMap(source.id, source.toMap());
    expect(restored.status, TreeStatus.rejected);
    expect(restored.rejectionReason, source.rejectionReason);
    expect(restored.revision, 3);
    expect(restored.hasUnreadReview, isTrue);
    expect(restored.copyWith(species: 'Angsana').reviewedAt, source.reviewedAt);
  });

  test('Unread hanya penolakan terbaru yang belum dibaca', () {
    expect(rejected().hasUnreadReview, isTrue);
    expect(rejected(readAt: DateTime(2026, 10, 9)).hasUnreadReview, isTrue);
    expect(rejected(readAt: DateTime(2026, 10, 10)).hasUnreadReview, isFalse);
    expect(rejected(readAt: DateTime(2026, 10, 11)).hasUnreadReview, isFalse);
    expect(rejected(status: TreeStatus.pending).hasUnreadReview, isFalse);
    expect(rejected(status: TreeStatus.verified).hasUnreadReview, isFalse);
  });

  testWidgets('Kotak pesan menampilkan alasan dan membuka pohon yang dipilih', (
    tester,
  ) async {
    TreeData? chosen;
    final source = rejected();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ReviewInbox(trees: [source], onOpen: (tree) => chosen = tree),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Pesan admin (1 belum dibaca)'));
    await tester.pumpAndSettle();
    expect(find.text('Foto perlu diperjelas.'), findsOneWidget);
    expect(find.text('Private Name'), findsNothing);
    await tester.tap(find.text('Mahoni'));
    await tester.pumpAndSettle();
    expect(identical(chosen, source), isTrue);
    expect(tester.takeException(), isNull);
  });
}