import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/tree_authority_field.dart';
import 'package:pemetaan_pohon/widgets/civic_design.dart';

void main() {
  testWidgets(
    'Lainnya wajib diisi; pergantian pilihan mempertahankan draft manual',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      String? selection = 'Lainnya';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Form(
                key: form,
                child: Column(
                  children: [
                    TreeAuthorityField(
                      selection: selection,
                      customController: controller,
                      onChanged: (value) => setState(() => selection = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Isi ranah kewenangan.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Pengelola taman');
      expect(form.currentState!.validate(), isTrue);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pusat').last);
      await tester.pumpAndSettle();
      expect(selection, 'Pusat');
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lainnya').last);
      await tester.pumpAndSettle();
      expect(controller.text, 'Pengelola taman');
      expect(form.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'Heading dan kewenangan dapat dibaca pada 320px teks200 tanpa animasi',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = TextEditingController(text: 'Pengelola taman');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const CivicHeading(
                    eyebrow: 'RUANG KERJA SURVEYOR',
                    title: 'Pendataan pohon Kota Cirebon',
                    description: 'Lengkapi data pohon di sekitar Anda.',
                  ),
                  TreeAuthorityField(
                    selection: 'Lainnya',
                    customController: controller,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sebutkan ranah kewenangan'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(CivicEntrance),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
    },
  );
}