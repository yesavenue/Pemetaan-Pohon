import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/public/public_motion.dart';

const _photo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';

void main() {
  testWidgets(
    'Foto mengikuti scroll, diam saat idle, dan berhenti pada reduced motion',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final image = MemoryImage(base64Decode(_photo));
      Widget page({bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  SizedBox(
                    height: 460,
                    width: double.infinity,
                    child: PublicScrollImage(image: image),
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      );
      double offset() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('public-city-photo-motion')),
          )
          .transform
          .getTranslation()
          .y;

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final start = offset();
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(offset(), greaterThan(start));
      expect(offset().abs(), lessThanOrEqualTo(12));
      final moved = offset();
      await tester.pump(const Duration(seconds: 1));
      expect(offset(), moved);

      await tester.pumpWidget(page(reduced: true));
      await tester.pumpAndSettle();
      expect(offset(), 0);
      scroll.jumpTo(250);
      await tester.pumpAndSettle();
      expect(offset(), 0);
      // Re-enable, then dispose during a queued scroll callback.
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      scroll.jumpTo(280);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Nilai baru langsung benar tanpa nilai lama atau angka perantara',
    (tester) async {
      Widget page(int value) => MaterialApp(
        home: Scaffold(
          body: PublicValueChange(identity: value, child: Text('$value pohon')),
        ),
      );
      await tester.pumpWidget(page(30));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(12));
      expect(find.text('12 pohon'), findsOneWidget);
      expect(find.text('30 pohon'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('12 pohon'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}