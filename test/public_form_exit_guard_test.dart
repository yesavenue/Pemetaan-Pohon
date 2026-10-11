import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/public/public_form_exit_guard.dart';

void main() {
  testWidgets(
    'Batal keluar mempertahankan isian dan mencegah dialog ganda',
    (tester) async {
      var exits = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PublicFormExitGuard(
            hasChanges: true,
            busy: false,
            onRootExit: () => exits++,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    if (await PublicFormExitScope.of(context)!.confirmExit()) {
                      exits++;
                    }
                  },
                  child: const Text('Pindah halaman'),
                ),
              ),
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(
        find.byType(TextButton),
      );

      button.onPressed!();
      button.onPressed!();

      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();

      expect(exits, 0);

      await tester.tap(find.text('Pindah halaman'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tinggalkan halaman'));
      await tester.pumpAndSettle();

      expect(exits, 1);
    },
  );

  testWidgets(
    'Back pada route form perlu persetujuan sebelum pop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PublicFormExitGuard(
                      hasChanges: true,
                      busy: false,
                      onRootExit: () {},
                      child: const Scaffold(
                        body: Text('Form terisi'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Buka form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka form'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.text('Tinggalkan permohonan?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();

      expect(find.text('Form terisi'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tinggalkan halaman'));
      await tester.pumpAndSettle();

      expect(find.text('Form terisi'), findsNothing);
    },
  );

  testWidgets(
    'Form kosong boleh keluar, busy tetap menahan navigasi',
    (tester) async {
      for (final busy in [false, true]) {
        bool? allowed;

        await tester.pumpWidget(
          MaterialApp(
            home: PublicFormExitGuard(
              hasChanges: false,
              busy: busy,
              onRootExit: () {},
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      allowed = await PublicFormExitScope.of(
                        context,
                      )!.confirmExit();
                    },
                    child: const Text('Keluar'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Keluar'));
        await tester.pumpAndSettle();

        expect(allowed, !busy);
        expect(find.byType(AlertDialog), findsNothing);
      }
    },
  );
}