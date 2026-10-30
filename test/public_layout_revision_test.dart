import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';
import 'package:pemetaan_pohon/screens/public_tracking_screen.dart';
import 'package:pemetaan_pohon/widgets/public_navbar.dart';

void main() {
  testWidgets('Beranda revisi menampilkan layanan atas tanpa tombol perbesar hero', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
          home: PublicHomeScreen(treeStream: Stream.value(<TreeData>[])),
        ));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Perbesar foto kota'), findsNothing);
        expect(find.byKey(const ValueKey('hero-track-request')), findsOneWidget);
        expect(find.byKey(const ValueKey('header-track-request')), findsNothing);
        expect(tester.takeException(), isNull, reason: '$width / text $scale');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('Pelacakan hero dapat dibuka dan kembali: $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 800 ? 600 : 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: PublicHomeScreen(
        treeStream: Stream.value(<TreeData>[]),
        mapPreviewBuilder: (_) => const SizedBox(height: 320))));
      await tester.pumpAndSettle();
      // Stay at the top: ensureVisible aligns the button to the viewport top,
      // scrolling far enough to deliberately hide the entire hero.
      final button = find.byKey(const ValueKey('hero-track-request'));
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(PublicTrackingScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PublicHomeScreen), findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Login header diblokir selama pengiriman formulir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PublicScaffold(
      currentPage: PublicPage.permohonan, navigationEnabled: false, body: Text('Mengirim'),
    )));
    await tester.pumpAndSettle();
    final button = tester.widget<IconButton>(find.byKey(const ValueKey('header-login')));
    expect(button.onPressed, isNull);
  });
}
