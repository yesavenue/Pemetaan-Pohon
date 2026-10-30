import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/widgets/public/public_ui.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Beranda publik responsif $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: PublicHomeScreen(
            treeStream: Stream.value(<TreeData>[]),
            mapPreviewBuilder: (_) => const SizedBox(height: 320),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kenali pohonnya.\nJaga kotanya.'), findsOneWidget);
    });
  }
  testWidgets('Hero serempak, input fokus tetap tampil, kode tetap tersimpan', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: PublicHomeScreen(
      treeStream: Stream.value(<TreeData>[]),
      mapPreviewBuilder: (_) => const SizedBox(height: 320))));
    await tester.pumpAndSettle();
    final scroll = tester.widget<PublicPageScroll>(find.byType(PublicPageScroll).first).controller!;
    double opacity() => tester.widget<Opacity>(find.byKey(const ValueKey('hero-content-opacity'))).opacity;
    final input = find.byKey(const ValueKey('hero-tracking-code'));
    expect(opacity(), 1);
    expect(find.text('PEMETAAN POHON • KOTA CIREBON'), findsNothing);
    scroll.jumpTo(104);
    await tester.pumpAndSettle();
    expect(opacity(), closeTo(.5, .001));
    expect(tester.widget<AnimatedSlide>(find.byKey(const ValueKey('public-header-slide'))).offset.dy, closeTo(-.5, .001));
    scroll.jumpTo(184);
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    expect(input.hitTestable(), findsNothing);
    expect(find.text('Jelajahi Peta').hitTestable(), findsNothing);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'a1b2c3d4e5f6g7h8');
    await tester.pumpAndSettle();
    scroll.jumpTo(184);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'a1b2c3d4e5f6g7h8');
    expect(opacity(), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
