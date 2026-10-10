import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_sections.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_export_picker.dart';
import 'package:pemetaan_pohon/widgets/surveyor/tree_thumbnail.dart';

const photo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
TreeData tree(
  String id, {
  String species = 'Mahoni',
  TreeStatus status = TreeStatus.pending,
}) => TreeData(
  id: id,
  latitude: -6.7,
  longitude: 108.5,
  photoBase64: '',
  surveyorId: 's',
  species: species,
  surveyorName: 'Surveyor',
  timestamp: DateTime(2026),
  status: status,
);
void main() {
  testWidgets(
    'Tinjau mengikuti update, error, dan penghapusan tanpa menulis data lama',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final source = StreamController<List<TreeData>>();
      addTearDown(source.close);
      var loads = 0, writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminTreesPane(
              admin: AppUser(
                uid: 'a',
                email: 'admin@example.com',
                name: 'Admin',
                role: UserRole.admin,
              ),
              load: () {
                loads++;
                return source.stream;
              },
              create: (_) async => null,
              update: (_) async => null,
              delete: (_) async => null,
              setStatus: (_, __) async {
                writes++;
                return null;
              },
              export: (_) async {},
            ),
          ),
        ),
      );
      source.add([tree('1')]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tinjau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tinjau').hitTestable());
      await tester.pumpAndSettle();
      expect(loads, 1);
      source.add([tree('1', species: 'Angsana', status: TreeStatus.verified)]);
      await tester.pumpAndSettle();
      expect(find.text('Tinjau Angsana'), findsOneWidget);
      expect(find.text('Batalkan verifikasi'), findsOneWidget);
      source.addError(StateError('offline'));
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('admin-dialog-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      source.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('Pohon ini sudah dihapus atau tidak lagi tersedia.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(source.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pencarian ekspor mempertahankan pilihan tersembunyi dan daftar dibuat lazily',
    (tester) async {
      final selected = <String>{};
      final rows = List.generate(500, (i) => tree('id-$i'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => Center(
                child: SizedBox(
                  width: 500,
                  child: AdminExportPicker(
                    items: rows,
                    selected: selected,
                    onChanged: () => refresh(() {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile).evaluate().length, lessThan(30));
      await tester.tap(find.byKey(const ValueKey('export-pick-id-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('export-search')),
        'id-499',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-pick-id-499')));
      await tester.pumpAndSettle();
      expect(selected, {'id-0', 'id-499'});
      expect(find.text('2 dipilih • 1 hasil pencarian'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('export-search')),
        'tidak-ada',
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada pohon yang cocok.'), findsOneWidget);
      expect(selected, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Thumbnail memakai ulang provider dan mengganti foto ketika data berubah',
    (tester) async {
      var data = photo;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return Center(child: TreeThumbnail(base64: data, size: 64));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      refresh(() {});
      await tester.pumpAndSettle();
      final second =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(identical(first.imageProvider, second.imageProvider), isTrue);
      expect(second.width, isNotNull);
      refresh(() => data = '%%%');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}