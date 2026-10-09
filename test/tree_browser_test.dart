import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/surveyor/tree_browser.dart';

void main() {
  final trees = [
    TreeData(
      id: '1',
      latitude: -6.7183,
      longitude: 108.5522,
      photoBase64: '',
      surveyorId: 'u1',
      surveyorName: 'Surveyor',
      species: 'Mangga',
      namaJalan: 'Jl. Cipto',
      kecamatan: 'Kesambi',
      timestamp: DateTime(2026, 10, 6),
    ),
    TreeData(
      id: '2',
      latitude: -6.7183,
      longitude: 108.5522,
      photoBase64: '',
      surveyorId: 'u1',
      surveyorName: 'Surveyor',
      species: 'Mahoni',
      namaJalan: 'Jl. Siliwangi',
      kecamatan: 'Kejaksan',
      condition: TreeCondition.sakit,
      timestamp: DateTime(2026, 10, 5),
    ),
  ];

  testWidgets('Cari/filter/reset dan tap detail bekerja pada daftar', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreeBrowser(
            trees: trees,
            onOpenTree: (tree) => opened = tree.id,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'cipto');
    await tester.pump();
    expect(find.text('Mangga'), findsOneWidget);
    expect(find.text('Mahoni'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sakit · 1'));
    await tester.pump();
    expect(find.text('Tidak ada hasil yang cocok'), findsOneWidget);
    await tester.tap(find.text('Reset filter'));
    await tester.pump();
    expect(find.text('Mangga'), findsOneWidget);
    expect(find.text('Mahoni'), findsOneWidget);
    await tester.tap(find.text('Mahoni'));
    expect(opened, '2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar tidak meluber pada layar sempit dengan font besar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: TreeBrowser(trees: trees, onOpenTree: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Pencarian dan filter bertahan setelah halaman dilepas; reset bertahan',
    (tester) async {
      final memory = TreeBrowserMemory();
      Future<void> showBrowser() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TreeBrowser(
                trees: trees,
                memory: memory,
                onOpenTree: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      Future<void> hideBrowser() async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Tab lain'))),
        );
        await tester.pump();
      }

      await showBrowser();
      await tester.enterText(find.byType(TextField), 'Siliwangi');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sakit · 1'));
      await tester.pump();
      await hideBrowser();
      await showBrowser();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Siliwangi',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sakit · 1'))
            .selected,
        isTrue,
      );
      expect(find.text('Mahoni'), findsOneWidget);
      expect(find.text('Mangga'), findsNothing);
      await tester.enterText(find.byType(TextField), 'tidak cocok');
      await tester.pump();
      await tester.tap(find.text('Reset filter'));
      await tester.pump();
      await hideBrowser();
      await showBrowser();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Semua · 2'))
            .selected,
        isTrue,
      );
      expect(find.text('Mangga'), findsOneWidget);
      expect(find.text('Mahoni'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
