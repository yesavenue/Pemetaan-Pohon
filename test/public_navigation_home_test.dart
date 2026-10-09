import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';
import 'package:pemetaan_pohon/widgets/public_navbar.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

TreeData tree(String id, TreeStatus status, TreeCondition condition) =>
    TreeData(
      id: id,
      latitude: -6.7183,
      longitude: 108.5522,
      photoBase64: '',
      surveyorId: 'test',
      surveyorName: 'Test',
      species: 'Pohon uji',
      timestamp: DateTime(2026),
      status: status,
      condition: condition,
    );

void main() {
  testWidgets('Navigasi responsif tanpa overflow termasuk teks 200%', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          app(
            PublicScaffold(
              currentPage: PublicPage.peta,
              onNavigate: (_) {},
              extraActions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                ),
              ],
              body: const Text('Peta'),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width / $scale');
        expect(
          find.byKey(const ValueKey('public-bottom-navigation')),
          width >= 1100 && scale == 1 ? findsNothing : findsOneWidget,
        );
      }
    }
  });

  testWidgets(
    'Menu aktif tidak bernavigasi; tujuan lain dan Back menuju Beranda',
    (tester) async {
      final navigated = <PublicPage>[];
      await tester.pumpWidget(
        app(
          PublicScaffold(
            currentPage: PublicPage.peta,
            onNavigate: navigated.add,
            body: const Text('Isi'),
          ),
        ),
      );
      await tester.tap(find.text('Peta'));
      expect(navigated, isEmpty);
      await tester.tap(find.text('Statistik'));
      expect(navigated, [PublicPage.statistik]);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(navigated.last, PublicPage.beranda);
    },
  );

  testWidgets('Navigasi dan Back diblokir selama submit', (tester) async {
    final navigated = <PublicPage>[];
    await tester.pumpWidget(
      app(
        PublicScaffold(
          currentPage: PublicPage.permohonan,
          navigationEnabled: false,
          onNavigate: navigated.add,
          body: const Text('Mengirim'),
        ),
      ),
    );
    expect(
      tester
          .widget<AbsorbPointer>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('public-bottom-navigation')),
                  matching: find.byType(AbsorbPointer),
                )
                .first,
          )
          .absorbing,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(navigated, isEmpty);
    expect(find.text('Mengirim'), findsOneWidget);
  });

  testWidgets('Beranda menghitung hanya pohon terverifikasi dan responsif', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    List<TreeData>? preview;
    await tester.pumpWidget(
      app(
        PublicHomeScreen(
          treeStream: Stream.value([
            tree('1', TreeStatus.verified, TreeCondition.sehat),
            tree('2', TreeStatus.verified, TreeCondition.rawanTumbang),
            tree('3', TreeStatus.pending, TreeCondition.sehat),
          ]),
          mapPreviewBuilder: (trees) {
            preview = trees;
            return const Text('Peta uji');
          },
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(preview?.map((t) => t.id).toList(), ['1', '2']);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('summary-Pohon terpetakan')))
          .data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-Sehat'))).data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('summary-Rawan Tumbang')))
          .data,
      '1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beranda membedakan loading, gagal, dan data kosong', (
    tester,
  ) async {
    final controller = StreamController<List<TreeData>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      app(PublicHomeScreen(treeStream: controller.stream)),
    );
    expect(find.text('Memuat data pohon…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('summary-Pohon terpetakan')),
      findsNothing,
    );
    controller.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('summary-Pohon terpetakan')),
      findsNothing,
    );
    controller.add([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada pohon terverifikasi untuk ditampilkan.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('summary-Pohon terpetakan')))
          .data,
      '0',
    );
    expect(tester.takeException(), isNull);
  });
}