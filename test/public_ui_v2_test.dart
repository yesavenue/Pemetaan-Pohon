import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';
import 'package:pemetaan_pohon/screens/public_map_viewer_screen.dart';
import 'package:pemetaan_pohon/screens/public_statistik_screen.dart';
import 'package:pemetaan_pohon/screens/public_pruning_request_screen.dart';
import 'package:pemetaan_pohon/screens/public_tentang_screen.dart';
import 'package:pemetaan_pohon/widgets/public_navbar.dart';
import 'package:pemetaan_pohon/widgets/public/public_ui.dart';
import 'package:pemetaan_pohon/widgets/public/public_bar_chart.dart';

List<TreeData> _fixture(int count) => [
  for (var i = 0; i < count; i++)
    TreeData(
      id: 'v$i',
      latitude: -6.7183,
      longitude: 108.5522,
      photoBase64: '',
      surveyorId: 'test',
      surveyorName: 'Test',
      species: i < 50
          ? 'Angsana'
          : i < 85
          ? 'Mahoni'
          : i < 105
          ? 'Trembesi'
          : 'Ketapang',
      kecamatan: i < 36
          ? 'Harjamukti'
          : i < 66
          ? 'Kesambi'
          : i < 90
          ? 'Lemahwungkuk'
          : i < 108
          ? 'Kejaksan'
          : 'Pekalipan',
      condition: i < 96
          ? TreeCondition.sehat
          : i < 114
          ? TreeCondition.sakit
          : TreeCondition.rawanTumbang,
      status: TreeStatus.verified,
      timestamp: DateTime(2026),
    ),
  TreeData(
    id: 'pending',
    latitude: -6.7,
    longitude: 108.5,
    photoBase64: '',
    surveyorId: 'test',
    surveyorName: 'Test',
    species: 'Pending',
    timestamp: DateTime(2026),
  ),
];
Widget _app(Widget page, double scale) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

void main() {
  test(
    'Skala integer menjaga nol, satu dan jumlah terbesar tanpa clipping',
    () {
      for (final value in [0, 1, 2, 6, 18, 50, 96, 120, 999, 10000]) {
        final scale = publicChartScale(value);
        expect(scale.max, greaterThanOrEqualTo(value));
        expect(scale.max % scale.step, 0);
        expect(scale.step, greaterThanOrEqualTo(1));
        if (value > 1) expect(scale.max ~/ scale.step, inInclusiveRange(2, 5));
      }
    },
  );
  testWidgets(
    'Navbar solid → glass → solid; scroll nested dan peta dikecualikan',
    (tester) async {
      final main = ScrollController();
      final nested = ScrollController();
      addTearDown(main.dispose);
      addTearDown(nested.dispose);
      Widget page(PublicPage selected) => MaterialApp(
        home: PublicScaffold(
          currentPage: selected,
          onNavigate: (_) {},
          body: PublicPageScroll(
            controller: main,
            children: [
              SizedBox(
                height: 160,
                child: ListView(
                  controller: nested,
                  children: const [SizedBox(height: 1000)],
                ),
              ),
              const SizedBox(height: 1800),
            ],
          ),
        ),
      );
      await tester.pumpWidget(page(PublicPage.beranda));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-solid')), findsOneWidget);
      nested.jumpTo(120);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-solid')), findsOneWidget);
      main.jumpTo(120);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-glass')), findsOneWidget);
      main.jumpTo(16);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-glass')), findsOneWidget);
      main.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-solid')), findsOneWidget);
      await tester.pumpWidget(page(PublicPage.peta));
      await tester.pumpAndSettle();
      main.jumpTo(120);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-header-solid')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Reduced motion tetap menampilkan isi dan arah navbar yang benar',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: PublicScaffold(
            currentPage: PublicPage.beranda,
            onNavigate: (_) {},
            body: PublicPageScroll(
              controller: scroll,
              children: const [
                PublicReveal(child: Text('Isi terlihat')),
                SizedBox(height: 1800),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Isi terlihat'), findsOneWidget);
      scroll.jumpTo(120);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('public-header-glass')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Statistik V2: data nol/satu/120 tetap benar pada desktop dan teks 200%',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final surface in [
        (const Size(1440, 900), 1.0),
        (const Size(320, 900), 2.0),
      ]) {
        tester.view.physicalSize = surface.$1;
        for (final count in [0, 1, 120]) {
          await tester.pumpWidget(
            _app(
              PublicStatistikScreen(treeStream: Stream.value(_fixture(count))),
              surface.$2,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('stat-Total pohon')))
                .data,
            '$count',
          );
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('stat-Sehat'))).data,
            '${count == 120 ? 96 : count}',
          );
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('stat-Sakit'))).data,
            '${count == 120 ? 18 : 0}',
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('stat-Rawan Tumbang')))
                .data,
            '${count == 120 ? 6 : 0}',
          );
          if (count == 0) {
            expect(find.text('Belum ada pohon terverifikasi.'), findsOneWidget);
            expect(find.text('Kondisi pohon'), findsNothing);
            expect(find.text('Jenis terbanyak'), findsNothing);
            expect(find.text('Sebaran per kecamatan'), findsNothing);
          } else {
            expect(
              find.text('Berdasarkan $count pohon terverifikasi'),
              findsOneWidget,
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${surface.$1}, scale ${surface.$2}, $count verified',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );
  testWidgets(
    'Layout V2: empat halaman lain pada ponsel/desktop/layar pendek/teks besar',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final surface in [
        (const Size(390, 844), 1.0),
        (const Size(1440, 900), 1.0),
        (const Size(1280, 720), 1.0),
        (const Size(320, 900), 2.0),
      ]) {
        tester.view.physicalSize = surface.$1;
        final pages = <Widget>[
          PublicHomeScreen(
            treeStream: Stream.value(_fixture(120)),
            mapPreviewBuilder: (_) =>
                const SizedBox(height: 280, child: Text('Preview uji')),
          ),
          PublicMapViewerScreen(
            treeStream: Stream.value(_fixture(120)),
            mapBuilder: (_, select) => const ColoredBox(color: PublicUi.mint),
          ),
          PublicPruningRequestScreen(createRequest: (_) async => 'REQ-TEST'),
          const PublicTentangScreen(),
        ];
        for (final page in pages) {
          await tester.pumpWidget(_app(page, surface.$2));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType}, ${surface.$1}, scale ${surface.$2}',
          );
          if (page is PublicHomeScreen) {
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const ValueKey('summary-Pohon terpetakan')),
                  )
                  .data,
              '120',
            );
          }
          if (page is PublicMapViewerScreen) {
            expect(find.text('120 hasil • 120 titik peta'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );
}