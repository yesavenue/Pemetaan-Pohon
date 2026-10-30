import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/utils/public_entry.dart';
import 'package:pemetaan_pohon/screens/auth_wrapper.dart';
import 'package:pemetaan_pohon/screens/public_map_viewer_screen.dart';
import 'package:pemetaan_pohon/screens/public_tracking_screen.dart';
import 'package:pemetaan_pohon/widgets/public/public_home_interactions.dart';

void main() {
  test('login and unknown paths retain the auth gate', () {
    final entry = publicEntry(Uri.parse('https://example.test/app/#/login'));
    expect(entry, isA<AuthWrapper>());
    expect((entry as AuthWrapper).showLogin, isTrue);
    expect(publicEntry(Uri.parse('https://example.test/app/#/admin')), isA<AuthWrapper>());
  });
  test('tracking fragment and selected tree reach their public screens', () {
    final tracking = publicEntry(Uri.parse('https://example.test/app/#/lacak?code=abcdefghijklmnop')) as PublicTrackingScreen;
    expect(tracking.initialCode, 'abcdefghijklmnop');
    final map = publicEntry(Uri.parse('https://example.test/app/#/peta?tree=tree-1')) as PublicMapViewerScreen;
    expect(map.initialTreeId, 'tree-1');
  });
  testWidgets('desktop quick cards have equal heights with wrapped text', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(24), child: PublicQuickActions(onMap: () {}, onGuide: () {}, onStatistics: () {}),
    ))));
    final cards = find.byType(InkWell);
    expect(cards, findsNWidgets(3));
    final heights = List.generate(3, (i) => tester.getSize(cards.at(i)).height);
    expect(heights[0], heights[1]); expect(heights[1], heights[2]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('quick cards remain readable on narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), textScaler: TextScaler.linear(2)),
      child: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(20), child: PublicQuickActions(onMap: () {}, onGuide: () {}, onStatistics: () {}),
      ))),
    )));
    expect(find.text('Lihat ringkasan kondisi dan sebaran pohon.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
