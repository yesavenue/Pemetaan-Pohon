import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/models/tree_pruning_request.dart';
import 'package:pemetaan_pohon/screens/public_home_screen.dart';
import 'package:pemetaan_pohon/screens/public_pruning_request_screen.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_sections.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_dialogs.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_dialog_scope.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_shell.dart';
import 'public_test_actions.dart';

void main() {
  testWidgets(
    'Dialog privat dan stream admin dibuang saat session UI menjadi publik',
    (tester) async {
      final requests = StreamController<List<TreePruningRequest>>();
      addTearDown(requests.close);
      var signedIn = true;
      late StateSetter refresh;
      var publicCount = 0;
      final admin = AppUser(
        uid: 'a',
        email: 'admin@example.com',
        role: UserRole.admin,
        name: 'Admin',
      );
      final verified = TreeData(
        id: 'v',
        latitude: -6.7,
        longitude: 108.5,
        photoBase64: '',
        surveyorId: 's',
        surveyorName: 'Surveyor',
        species: 'Mahoni',
        timestamp: DateTime(2026),
        status: TreeStatus.verified,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              refresh = setState;
              return signedIn
                  ? AdminDialogScope(
                      child: AdminShell(
                        user: admin,
                        page: AdminPage.permohonan,
                        onSelect: (_) {},
                        onLogout: () => setState(() => signedIn = false),
                        body: AdminRequestsPane(
                          load: () => requests.stream,
                          update: (_, __, ___) async => null,
                          exportWord: (_) async {},
                          downloadPhoto: (_, __) {},
                        ),
                      ),
                    )
                  : PublicHomeScreen(
                      treeStream: Stream.value([
                        verified,
                        verified.copyWith(status: TreeStatus.pending),
                      ]),
                      mapPreviewBuilder: (items) {
                        publicCount = items.length;
                        return const Text('Peta publik uji');
                      },
                    );
            },
          ),
        ),
      );
      // The pending stream keeps its loading animation active until data arrives.
      await tester.pump(const Duration(milliseconds: 350));
      expect(requests.hasListener, true);
      requests.add([
        TreePruningRequest(
          id: 'r1',
          requestNumber: 'REQ-000001',
          namaPemohon: 'Pemohon',
          alamatPemohon: 'Alamat',
          nomorHp: '081234567890',
          emailPemohon: 'uji@example.com',
          nik: '1234567890123456',
          alamatPohon: 'Jalan uji',
          alasan: 'Rimbun',
          fotoPohonBase64: '',
          fotoKtpBase64: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await tester.pumpAndSettle();
      final review = find.text('Tinjau');
      // SliverList builds cards lazily; ensureVisible alone cannot find an
      // unbuilt button below the taller heading and filters.
      final requestScroll = find
          .descendant(
            of: find.byType(AdminRequestsPane),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        review,
        200,
        scrollable: requestScroll,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(review, findsOneWidget);
      expect(review.hitTestable(), findsOneWidget);
      await tester.tap(review.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('1234567890123456'), findsOneWidget);
      refresh(() => signedIn = false);
      await tester.pumpAndSettle();
      expect(find.byType(AdminShell), findsNothing);
      expect(find.byType(AdminActionDialog), findsNothing);
      expect(find.text('1234567890123456'), findsNothing);
      expect(find.byType(AdminRequestsPane), findsNothing);
      expect(requests.hasListener, false);
      expect(find.byType(PublicHomeScreen), findsOneWidget);
      expect(find.text('Peta publik uji'), findsOneWidget);
      expect(publicCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Lanjut form invalid memfokuskan field pertama dan reduced motion tidak menghalangi',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: PublicPruningRequestScreen(
            createRequest: (_) async => 'REQ-000001',
          ),
        ),
      );
      final next = find.text('Lanjut');
      await revealPublicTarget(tester, next);
      expect(next.hitTestable(), findsOneWidget);
      await tester.tap(next.hitTestable());
      await tester.pumpAndSettle();
      final name = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Nama Lengkap *',
        ),
      );
      expect(name.focusNode!.hasFocus, true);
      expect(find.text('Wajib diisi'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}