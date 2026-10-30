import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_shell.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Sidebar mengecil, navigasi tetap bekerja, reduced=$reduced', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var page = AdminPage.ringkasan;
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!),
        home: StatefulBuilder(builder: (context, refresh) => AdminShell(
          user: AppUser(uid: 'a', name: 'Administrator Utama', email: 'a@example.com', role: UserRole.admin),
          page: page, onSelect: (p) => refresh(() => page = p), onLogout: () {},
          body: const Text('Konten admin')))));
      await tester.pumpAndSettle();
      final sidebar = find.byKey(const ValueKey('admin-sidebar'));
      final toggle = find.byKey(const ValueKey('admin-sidebar-toggle'));
      expect(tester.getSize(sidebar).width, 80);
      expect(tester.getTopLeft(sidebar).dy, 0);
      expect(tester.getSize(sidebar).height, 900);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 248);
      expect(tester.getTopLeft(sidebar).dy, 0);
      expect(tester.getSize(sidebar).height, 900);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 80);
      expect(find.byTooltip('Perluas sidebar'), findsOneWidget);
      expect(find.byTooltip('Permohonan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-nav-permohonan')));
      await tester.pumpAndSettle();
      expect(page, AdminPage.permohonan);
      expect(tester.getSize(sidebar).width, 80);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 248);
      tester.view.physicalSize = const Size(390, 850);
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      expect(find.byKey(const ValueKey('admin-nav-permohonan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
