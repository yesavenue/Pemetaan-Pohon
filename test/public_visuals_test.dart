import 'dart:convert';
import 'public_test_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';
import 'package:pemetaan_pohon/screens/public_map_viewer_screen.dart';
import 'package:pemetaan_pohon/view_models/public_map_state.dart';
import 'package:pemetaan_pohon/widgets/public/public_ui.dart';
import 'package:pemetaan_pohon/widgets/public/public_visuals.dart';

const photo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
TreeData tree(
  String id, {
  TreeStatus status = TreeStatus.verified,
  TreeCondition condition = TreeCondition.sehat,
  String image = photo,
}) => TreeData(
  id: id,
  latitude: -6.7183,
  longitude: 108.5522,
  photoBase64: image,
  surveyorId: 'test',
  surveyorName: 'Test',
  species: 'Angsana $id',
  timestamp: DateTime(2026),
  status: status,
  condition: condition,
);

void main() {
  testWidgets('Foto dibuka, diperbesar, direset dan ditutup dengan Escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PublicPhotoFrame(
              image: MemoryImage(base64Decode(photo)),
              title: 'Angsana',
              width: 160,
              height: 160,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-open-Angsana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('public-photo-viewer')), findsOneWidget);
    await tester.tap(find.byTooltip('Perbesar foto'));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    final center = tester
        .getSize(find.byType(InteractiveViewer))
        .center(Offset.zero);
    final sceneCenter = viewer.transformationController!.toScene(center);
    expect(sceneCenter.dx, closeTo(center.dx, .01));
    expect(sceneCenter.dy, closeTo(center.dy, .01));
    await tester.tap(find.text('Ukuran awal'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('public-photo-viewer')), findsNothing);
    expect(find.byKey(const ValueKey('photo-open-Angsana')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Foto kosong dan Base64 rusak memakai fallback tanpa popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              PublicTreePhoto(tree: tree('1', image: '')),
              PublicTreePhoto(tree: tree('2', image: '%%%')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.park_rounded), findsNWidgets(2));
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Ringkasan memfilter pratinjau, tidak menampilkan pending, dan dapat direset',
    (tester) async {
      List<TreeData> preview = [];
      await tester.pumpWidget(
        MaterialApp(
          home: PublicHomeScreen(
            treeStream: Stream.value([
              tree('1'),
              tree('2', condition: TreeCondition.sakit),
              tree(
                '3',
                condition: TreeCondition.sakit,
                status: TreeStatus.pending,
              ),
            ]),
            mapPreviewBuilder: (trees) {
              preview = trees;
              return const SizedBox(height: 250, child: Text('Pratinjau uji'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(preview.map((t) => t.id), ['1', '2']);
      final sick = find.byKey(const ValueKey('home-condition-sakit'));
      await revealPublicTarget(tester, sick);
      expect(sick.hitTestable(), findsOneWidget);
      await tester.tap(sick.hitTestable());
      await tester.pumpAndSettle();
      expect(preview.map((t) => t.id), ['2']);
      expect(find.text('Pratinjau: Sakit • 1 pohon'), findsOneWidget);
      final reset = find.text('Tampilkan semua kondisi');
      await revealPublicTarget(tester, reset);
      expect(reset.hitTestable(), findsOneWidget);
      await tester.tap(reset.hitTestable());
      await tester.pumpAndSettle();
      expect(preview.map((t) => t.id), ['1', '2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Preview peta memilih satu kartu nyata dan membersihkan data yang hilang',
    (tester) async {
      Widget page(List<TreeData> trees) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PublicHomeMapPreview(
              trees: trees,
              mapBuilder: (points, select) => Center(
                child: Wrap(
                  children: [
                    for (final point in points)
                      TextButton(
                        onPressed: () => select(point),
                        child: Text('Marker ${point.id}'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        page([tree('1'), tree('2'), tree('3', status: TreeStatus.pending)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marker 3'), findsNothing);
      await tester.tap(find.text('Marker 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-selected-1')), findsOneWidget);
      await tester.tap(find.text('Marker 2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-selected-1')), findsNothing);
      expect(find.byKey(const ValueKey('home-selected-2')), findsOneWidget);
      await tester.pumpWidget(page([tree('1')]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-selected-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Peta lengkap menerima ID pilihan dari Beranda', (tester) async {
    final state = PublicMapState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicMapViewerScreen(
          state: state,
          initialTreeId: '1',
          treeStream: Stream.value([tree('1')]),
          mapBuilder: (_, select) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(state.selectedId, '1');
    expect(find.byKey(const ValueKey('selected-1')), findsOneWidget);
    expect(state.center.latitude, -6.7183);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reveal dimulai saat masuk viewport dan tidak diulang ketika scroll kembali',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: const Column(
                children: [
                  SizedBox(height: 1000),
                  PublicReveal(child: Text('Bagian berikutnya')),
                  SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final opacity = find.descendant(
        of: find.byType(PublicReveal),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      controller.jumpTo(900);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(tester.takeException(), isNull);
    },
  );
}