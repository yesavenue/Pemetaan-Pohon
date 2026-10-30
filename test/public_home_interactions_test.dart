import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/public/public_home_interactions.dart';

void main() {
  testWidgets('Panduan mengubah isi dan menjalankan aksi layanan', (tester) async {
    var apply = 0;
    var track = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: PublicApplicationGuide(onApply: () => apply++, onTrack: () => track++)))));
    expect(find.text('Data pemohon yang dapat dihubungi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guide-step-1')));
    await tester.pumpAndSettle();
    expect(find.text('Pastikan lokasi pohon sesuai'), findsOneWidget);
    expect(find.text('Data pemohon yang dapat dihubungi'), findsNothing);
    await tester.ensureVisible(find.text('Langkah berikutnya'));
    await tester.tap(find.text('Langkah berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan bukti dan kode akses'), findsOneWidget);
    await tester.ensureVisible(find.text('Mulai permohonan'));
    await tester.tap(find.text('Mulai permohonan'));
    await tester.ensureVisible(find.text('Sudah mengajukan? Lacak'));
    await tester.tap(find.text('Sudah mengajukan? Lacak'));
    expect(apply, 1);
    expect(track, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Akses cepat bekerja pada ponsel dengan teks besar', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)), child: child!),
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16),
        child: PublicQuickActions(onMap: () => calls.add('map'), onGuide: () => calls.add('guide'),
          onStatistics: () => calls.add('statistics')))))));
    for (final title in ['Lihat kondisi pohon', 'Persiapan permohonan', 'Statistik kota']) {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
    }
    expect(calls, ['map', 'guide', 'statistics']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion menonaktifkan pergeseran latar hero', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: SingleChildScrollView(controller: controller, child: Column(children: [
        SizedBox(height: 500, child: PublicHeroBackdrop(controller: controller)),
        const SizedBox(height: 1800),
      ])))));
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(find.byKey(const ValueKey('hero-parallax')));
    expect(transform.transform.getTranslation().y, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}