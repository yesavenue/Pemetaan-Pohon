import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/view_models/surveyor_dashboard_data.dart';
import 'package:pemetaan_pohon/screens/surveyor/dashboard_home.dart';

// Widget bisa sudah dibuat di dalam Column tetapi pusatnya masih di luar viewport.
// Scroll sampai target benar-benar menerima hit test sebelum mencoba tap.
Future<Finder> _revealForTap(
  WidgetTester tester,
  Finder target, {
  Offset dragOffset = const Offset(0, -240),
}) async {
  final scrollable = find.byType(ListView);
  expect(scrollable, findsOneWidget);
  for (
    var attempt = 0;
    attempt < 30 && target.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(scrollable, dragOffset);
    await tester.pumpAndSettle();
  }
  final tappable = target.hitTestable();
  expect(
    tappable,
    findsOneWidget,
    reason: 'Target harus berada dalam viewport dan dapat menerima tap.',
  );
  return tappable;
}

void main() {
  testWidgets('Dashboard kosong tetap menyediakan navigasi daftar', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardHome(
            user: AppUser(
              uid: 'u1',
              email: 'test@example.com',
              role: UserRole.surveyor,
              name: 'Surveyor Uji',
            ),
            data: SurveyorDashboardData.fromTrees([], 'u1'),
            onOpenTrees: () => opened = true,
            onOpenTree: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Halo, Surveyor Uji'), findsOneWidget);
    expect(find.text('Menunggu Sync'), findsNothing);
    expect(find.text('Selesai Sync'), findsNothing);
    expect(find.text('Input hari ini'), findsOneWidget);
    expect(find.text('Rawan tumbang'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Belum ada pohon'),
      200,
    );
    expect(find.textContaining('Belum ada pohon'), findsOneWidget);
    final totalCardLabel = await _revealForTap(
      tester,
      find.text('Total pohon Anda'),
      dragOffset: const Offset(0, 240),
    );
    await tester.tap(totalCardLabel);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Dashboard terbaru dengan nama panjang tetap dapat digunakan pada teks 200%',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final trees = List.generate(
        6,
        (index) => TreeData(
          id: '$index',
          latitude: -6.7183,
          longitude: 108.5522,
          photoBase64: index == 5 ? 'bukan-base64' : '',
          surveyorId: 'u1',
          surveyorName: 'Surveyor',
          species: 'Pohon $index dengan nama panjang',
          namaJalan: 'Jl. Siliwangi dengan keterangan lokasi yang panjang',
          kecamatan: 'Kejaksan',
          condition: TreeCondition.rawanTumbang,
          timestamp: DateTime(2026, 10, 6, index),
        ),
      );
      String? opened;
      for (final width in [320.0, 390.0, 1100.0]) {
        opened = null;
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: DashboardHome(
                  user: AppUser(
                    uid: 'u1',
                    email: 'test@example.com',
                    role: UserRole.surveyor,
                    name: 'Surveyor dengan nama panjang',
                  ),
                  data: SurveyorDashboardData.fromTrees(trees, 'u1'),
                  onOpenTrees: () {},
                  onOpenTree: (tree) => opened = tree.id,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final latestTreeLabel = await _revealForTap(
          tester,
          find.text('Pohon 5 dengan nama panjang'),
        );
        await tester.tap(latestTreeLabel);
        expect(opened, '5');
        expect(find.text('Menunggu Sync'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}