import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_map_viewer_screen.dart';
import 'package:pemetaan_pohon/view_models/public_map_state.dart';
import 'public_test_actions.dart';

TreeData sample(
  String id, {
  TreeStatus status = TreeStatus.verified,
  TreeCondition condition = TreeCondition.sehat,
  double latitude = -6.7183,
  String species = 'Angsana',
  String kecamatan = 'Kesambi',
  int day = 1,
  String photoBase64 = '',
}) => TreeData(
  id: id,
  latitude: latitude,
  longitude: 108.5522,
  photoBase64: photoBase64,
  surveyorId: 'test',
  surveyorName: 'Test',
  species: species,
  kecamatan: kecamatan,
  namaJalan: 'Jalan Uji',
  timestamp: DateTime(2026, 10, day),
  condition: condition,
  status: status,
);

Widget fakeMap(PublicMapState state, ValueChanged<TreeData> select) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final tree in state.mappedTrees)
        TextButton(
          key: ValueKey('marker-${tree.id}'),
          onPressed: () => select(tree),
          child: Text('Marker ${tree.id}'),
        ),
    ],
  ),
);

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  testWidgets(
    'Filter kondisi awal hanya menampilkan pohon terverifikasi yang sesuai',
    (tester) async {
      await tester.pumpWidget(
        app(
          PublicMapViewerScreen(
            initialCondition: TreeCondition.sakit,
            treeStream: Stream.value([
              sample('1'),
              sample('2', condition: TreeCondition.sakit),
              sample(
                '3',
                condition: TreeCondition.sakit,
                status: TreeStatus.pending,
              ),
            ]),
            mapBuilder: fakeMap,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('marker-1')), findsNothing);
      expect(find.byKey(const ValueKey('marker-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-3')), findsNothing);
      await revealPublicTarget(tester, find.text('Reset filter'));
      await tester.tap(find.text('Reset filter').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('marker-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-3')), findsNothing);
    },
  );

  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });
  test('Publik menolak pending, memisahkan hasil/titik, dan mengurutkan', () {
    final state = PublicMapState();
    addTearDown(state.dispose);
    state.setTrees([
      sample('1'),
      sample('2', day: 2, latitude: double.nan),
      sample('3', status: TreeStatus.pending),
      sample('4', day: 3, latitude: 91),
    ]);
    expect(state.visibleTrees.map((t) => t.id), ['4', '2', '1']);
    expect(state.mappedTrees.map((t) => t.id), ['1']);
    state.setFilters(const PublicMapFilters(newestFirst: false));
    expect(state.visibleTrees.map((t) => t.id), ['1', '2', '4']);
  });

  test('Pencarian/filter mengubah selection; reset tidak mengubah kamera', () {
    final state = PublicMapState();
    addTearDown(state.dispose);
    state.setTrees([
      sample('1'),
      sample(
        '2',
        species: 'Mahoni',
        kecamatan: 'Kejaksan',
        condition: TreeCondition.rawanTumbang,
      ),
    ]);
    state.select('1');
    state.setQuery('  KEJAKSAN  ');
    expect(state.selectedId, isNull);
    expect(state.visibleTrees.single.id, '2');
    state.setFilters(const PublicMapFilters(species: 'Angsana'));
    expect(state.visibleTrees, isEmpty);
    state.center = const LatLng(-6.7, 108.5);
    state.zoom = 17;
    state.resetFilters();
    expect(state.visibleTrees, hasLength(2));
    expect(state.query, isEmpty);
    expect(state.center.latitude, -6.7);
    expect(state.zoom, 17);
    state.toggleCondition(TreeCondition.rawanTumbang);
    expect(state.visibleTrees.single.id, '2');
  });

  test(
    'Perubahan data memperbarui detail atau membersihkan ID yang hilang',
    () {
      final state = PublicMapState();
      addTearDown(state.dispose);
      state.setTrees([sample('1')]);
      state.select('1');
      state.setTrees([sample('1', species: 'Mahoni')]);
      expect(state.selectedTree?.species, 'Mahoni');
      state.setTrees([sample('1', status: TreeStatus.pending)]);
      expect(state.selectedId, isNull);
      expect(state.selectedTree, isNull);
      state.select('unknown');
      expect(state.selectedId, isNull);
    },
  );

  testWidgets(
    'Kartu dan marker memilih ID sama; detail mempertahankan filter',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = PublicMapState();
      addTearDown(state.dispose);
      LatLng? camera;
      await tester.pumpWidget(
        app(
          PublicMapViewerScreen(
            state: state,
            treeStream: Stream.value([
              sample('1'),
              sample('2', species: 'Mahoni', day: 2),
            ]),
            mapBuilder: fakeMap,
            onCameraMove: (point, zoom) => camera = point,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tree-card-1')));
      await tester.pumpAndSettle();
      expect(state.selectedId, '1');
      expect(camera?.latitude, -6.7183);
      await tester.tap(find.byKey(const ValueKey('marker-2')));
      await tester.pumpAndSettle();
      expect(state.selectedId, '2');
      expect(find.byKey(const ValueKey('selected-2')), findsOneWidget);
      await revealPublicTarget(tester, find.text('Lihat detail'));
      expect(find.text('Lihat detail').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Lihat detail'));

      await tester.pumpAndSettle();
      expect(find.text('Detail pohon'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(state.selectedId, '2');
      expect(state.visibleTrees, hasLength(2));
    },
  );

  testWidgets(
    'Ponsel teks 200%: daftar, pilih, cari lalu reset tanpa overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = PublicMapState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        app(
          PublicMapViewerScreen(
            state: state,
            treeStream: Stream.value([
              sample('1'),
              sample('2', species: 'Mahoni'),
            ]),
            mapBuilder: fakeMap,
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await revealPublicTarget(tester, find.text('Daftar pohon'));
      await tester.tap(find.text('Daftar pohon'));
      await tester.pumpAndSettle();
      await revealPublicTarget(
        tester,
        find.byKey(const ValueKey('tree-card-1')),
      );
      await tester.tap(find.byKey(const ValueKey('tree-card-1')));
      await tester.pumpAndSettle();
      expect(state.selectedId, '1');
      await revealPublicTarget(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Mahoni');
      await tester.pumpAndSettle();
      expect(state.selectedId, isNull);
      expect(state.visibleTrees.single.id, '2');
      await revealPublicTarget(tester, find.text('Reset filter'));
      await tester.tap(find.text('Reset filter'));
      await tester.pumpAndSettle();
      expect(state.visibleTrees, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GPS hanya diminta lewat tombol; gagal tidak menghilangkan peta',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          PublicMapViewerScreen(
            treeStream: Stream.value([sample('1')]),
            mapBuilder: fakeMap,
            locate: () async {
              calls++;
              throw StateError('denied');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(const ValueKey('marker-1')), findsOneWidget);
      expect(find.textContaining('Lokasi belum tersedia.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Loading/gagal dibedakan; data berubah menutup detail terpilih', (
    tester,
  ) async {
    final stream = StreamController<List<TreeData>>();
    addTearDown(stream.close);
    final state = PublicMapState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      app(
        PublicMapViewerScreen(
          state: state,
          treeStream: stream.stream,
          mapBuilder: fakeMap,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    stream.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Coba Lagi'), findsOneWidget);
    stream.add([sample('1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('marker-1')));
    await tester.pumpAndSettle();
    await revealPublicTarget(tester, find.text('Lihat detail'));
    expect(find.text('Lihat detail').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Lihat detail'));
    await tester.pumpAndSettle();
    expect(find.text('Detail pohon'), findsOneWidget);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(state.selectedId, isNull);
    expect(find.text('Detail pohon'), findsNothing);
    expect(find.byKey(const ValueKey('selected-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Peta utama: popup tetap di canvas, tidak menutup kontrol, tombol detail terlihat',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final scenario in [
        (const Size(1440, 900), 1.0),
        (const Size(980, 700), 1.0),
        (const Size(1280, 500), 1.0),
        (const Size(390, 844), 1.0),
        (const Size(320, 900), 2.0),
      ]) {
        tester.view.physicalSize = scenario.$1;
        await tester.pumpWidget(
          app(
            PublicMapViewerScreen(
              initialTreeId: '1',
              treeStream: Stream.value([
                sample(
                  '1',
                  species: 'Mahoni dengan nama panjang untuk pengujian',
                ),
              ]),
              mapBuilder: fakeMap,
            ),
            scale: scenario.$2,
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const ValueKey('public-map-detail-action'));
        await revealPublicTarget(tester, action);
        expect(action.hitTestable(), findsOneWidget, reason: '$scenario');
        final canvas = tester.getRect(
          find.byKey(const ValueKey('public-map-canvas')),
        );
        final popup = tester.getRect(find.byKey(const ValueKey('selected-1')));
        final controls = tester.getRect(
          find.byKey(const ValueKey('public-map-controls')),
        );
        expect(canvas.contains(popup.topLeft), isTrue, reason: '$scenario');
        expect(canvas.contains(popup.bottomRight), isTrue, reason: '$scenario');
        expect(controls.overlaps(popup), isFalse, reason: '$scenario');
        expect(
          find.byKey(const ValueKey('public-header-solid')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$scenario');
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Detail pohon'), findsOneWidget);
        if (scenario.$1.width >= 960 && scenario.$2 == 1) {
          expect(
            find.byKey(const ValueKey('public-map-detail-dialog')),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Tutup'));
        } else {
          expect(
            find.byKey(const ValueKey('public-map-detail-dialog')),
            findsNothing,
          );
          await revealPublicTarget(tester, action);
          await tester.tap(action);
        }
        await tester.pumpAndSettle();
        expect(find.text('Detail pohon'), findsNothing);
        expect(find.byKey(const ValueKey('selected-1')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$scenario');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'Foto popup peta utama terbuka besar dan kembali ke pilihan yang sama',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const photo =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
      await tester.pumpWidget(
        app(
          PublicMapViewerScreen(
            initialTreeId: '1',
            treeStream: Stream.value([
              sample('1', species: 'Mahoni', photoBase64: photo),
            ]),
            mapBuilder: fakeMap,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final photoButton = find.byKey(const ValueKey('photo-open-Mahoni'));
      await revealPublicTarget(tester, photoButton);
      expect(photoButton.hitTestable(), findsOneWidget);
      await tester.tap(photoButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-photo-viewer')), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup foto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-map-detail-action')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}