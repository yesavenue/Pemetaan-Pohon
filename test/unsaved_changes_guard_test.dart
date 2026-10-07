import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/surveyor/unsaved_changes_guard.dart';

class _DraftForm extends StatefulWidget {
  final String initialText;
  const _DraftForm({this.initialText = ''});

  @override
  State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  final guardKey = GlobalKey<UnsavedChangesGuardState>();
  late final TextEditingController controller;
  int step = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    key: guardKey,
    hasChanges: controller.text != widget.initialText,
    busy: busy,
    hasPreviousStep: step > 0,
    onPreviousStep: () => setState(() => step--),
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali formulir',
          onPressed: () => unawaited(guardKey.currentState!.requestBack()),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Text('Langkah $step'),
          TextField(controller: controller, onChanged: (_) => setState(() {})),
          TextButton(
            onPressed: () => setState(() => step++),
            child: const Text('Lanjut'),
          ),
          TextButton(
            onPressed: () => setState(() => busy = true),
            child: const Text('Mulai proses'),
          ),
          TextButton(
            onPressed: () => unawaited(guardKey.currentState!.leave(true)),
            child: const Text('Simpan berhasil'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openForm(WidgetTester tester, {String initialText = ''}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<Object?>(
              context,
              MaterialPageRoute<Object?>(
                builder: (_) => _DraftForm(initialText: initialText),
              ),
            ),
            child: const Text('Buka formulir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka formulir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Back sistem pada draft berubah: batal menjaga input, buang keluar sekali',
    (tester) async {
      await _openForm(tester);
      await tester.enterText(find.byType(TextField), 'Jl. Siliwangi');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Buang perubahan?'), findsOneWidget);
      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();
      expect(find.text('Jl. Siliwangi'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali formulir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buang perubahan'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Buka formulir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Form kosong dan edit tanpa perubahan keluar tanpa dialog', (
    tester,
  ) async {
    for (final text in ['', 'Alamat asli']) {
      await _openForm(tester, initialText: text);
      await tester.tap(find.byTooltip('Kembali formulir'));
      await tester.pumpAndSettle();
      expect(find.text('Buang perubahan?'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // Pisahkan navigator antar kasus.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'Perubahan yang dikembalikan ke nilai awal tidak meminta konfirmasi',
    (tester) async {
      await _openForm(tester, initialText: 'Alamat asli');
      await tester.enterText(find.byType(TextField), 'Alamat baru');
      await tester.enterText(find.byType(TextField), 'Alamat asli');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Buang perubahan?'), findsNothing);
    },
  );

  testWidgets('Back antarlangkah menjaga draft, proses mengunci Back', (
    tester,
  ) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Langkah 0'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Buang perubahan?'), findsNothing);
    await tester.tap(find.text('Mulai proses'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.tap(find.byTooltip('Kembali formulir'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Buang perubahan?'), findsNothing);
  });

  testWidgets('Simpan berhasil melewati guard dan mengembalikan hasil true', (
    tester,
  ) async {
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<Object?>(
                  context,
                  MaterialPageRoute<Object?>(
                    builder: (_) => const _DraftForm(),
                  ),
                );
              },
              child: const Text('Buka formulir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka formulir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.text('Mulai proses'));
    await tester.pump();
    await tester.tap(find.text('Simpan berhasil'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Buang perubahan?'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}