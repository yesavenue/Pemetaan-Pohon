import 'dart:async';
import 'public_test_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_statistik_screen.dart';
import 'package:pemetaan_pohon/screens/public_tentang_screen.dart';
import 'package:pemetaan_pohon/view_models/public_statistics.dart';

Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
  await revealPublicTarget(tester, finder);
  final target = finder.hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'Target harus terlihat dan dapat disentuh setelah scroll/layout.',
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

TreeData tree(
  String id, {
  String species = 'Angsana',
  String kecamatan = 'Kesambi',
  TreeCondition condition = TreeCondition.sehat,
  TreeStatus status = TreeStatus.verified,
}) => TreeData(
  id: id,
  species: species,
  kecamatan: kecamatan,
  condition: condition,
  status: status,
  latitude: -6.7,
  longitude: 108.5,
  photoBase64: '',
  surveyorId: 'test',
  surveyorName: 'Test',
  timestamp: DateTime(2026),
);
Widget app(Widget home, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  test(
    'Jumlah kondisi/jenis/wilayah sama dengan total verified termasuk wilayah kosong',
    () {
      final data = [
        tree('1'),
        tree('2', condition: TreeCondition.sakit, kecamatan: ''),
        tree(
          '3',
          kecamatan: ' kesambi ',
          condition: TreeCondition.rawanTumbang,
        ),
        tree('4', status: TreeStatus.pending),
      ];
      final stats = PublicStatistics.fromTrees(data);
      expect(stats.total, 3);
      expect(stats.conditions.values.reduce((a, b) => a + b), 3);
      expect(stats.species.values.reduce((a, b) => a + b), 3);
      expect(stats.districts.values.reduce((a, b) => a + b), 3);
      expect(stats.districts['Belum diisi / wilayah lainnya'], 1);
      expect(PublicStatistics.fromTrees(data, kecamatan: 'Kesambi').total, 2);
    },
  );
  test('Top jenis menjaga total melalui Lainnya; data kosong bernilai nol', () {
    final stats = PublicStatistics.fromTrees([
      for (var i = 0; i < 16; i++) tree('$i', species: 'Jenis ${i ~/ 2}'),
    ]);
    final top = stats.topSpecies();
    expect(top, hasLength(6));
    expect(top.last.value, 6);
    expect(top.fold<int>(0, (sum, e) => sum + e.value), 16);
    final empty = PublicStatistics.fromTrees([]);
    expect(empty.total, 0);
    expect(empty.topSpecies(), isEmpty);
    expect(empty.conditions.values.every((n) => n == 0), isTrue);
  });
  testWidgets('Filter statistik mengubah angka/tabel dan diteruskan ke peta', (
    tester,
  ) async {
    String? target;
    await tester.pumpWidget(
      app(
        PublicStatistikScreen(
          treeStream: Stream.value([
            tree('1'),
            tree('2', kecamatan: 'Kejaksan'),
          ]),
          mapPageBuilder: (region) {
            target = region;
            return const Scaffold(body: Text('Peta uji'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stat-Total pohon'))).data,
      '2',
    );
    await tester.tap(find.text('Semua Kecamatan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kesambi').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stat-Total pohon'))).data,
      '1',
    );
    await revealPublicTarget(tester, find.text('Lihat tabel data'));
    await tester.tap(find.text('Lihat tabel data'));
    await tester.pumpAndSettle();
    expect(find.text('Kondisi — tabel data'), findsOneWidget);
    await revealPublicTarget(tester, find.text('Peta Kesambi'));
    await tester.tap(find.text('Peta Kesambi'));
    await tester.pumpAndSettle();
    expect(target, 'Kesambi');
    expect(find.text('Peta uji'), findsOneWidget);
  });
  testWidgets(
    'Statistik layar sempit teks 200% membedakan loading/error/empty',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final stream = StreamController<List<TreeData>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        app(PublicStatistikScreen(treeStream: stream.stream), scale: 2),
      );
      expect(find.byKey(const ValueKey('stat-Total pohon')), findsNothing);
      stream.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.byKey(const ValueKey('stat-Total pohon')), findsNothing);
      stream.add([]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('stat-Total pohon')))
            .data,
        '0',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Tentang teks 200%: FAQ bekerja, placeholder disembunyikan, lisensi dapat dibuka',
    (tester) async {
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() {
        WidgetController.hitTestWarningShouldBeFatal = previousFatal;
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(app(const PublicTentangScreen(), scale: 2));
      await tester.pumpAndSettle();
      expect(find.text('(0231) 000000'), findsNothing);
      await revealAndTap(tester, find.text('Apakah saya wajib login?'));
      expect(find.textContaining('Tidak. Peta dan statistik'), findsOneWidget);
      await revealAndTap(tester, find.text('Lihat lisensi'));
      expect(find.byType(LicensePage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Lihat lisensi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}