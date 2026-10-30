import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/screens/login_screen.dart';
import 'package:pemetaan_pohon/utils/auth_messages.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_shell.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_request_history.dart';

void main() {
  test('Pesan login tidak membedakan email tidak terdaftar dari password salah', () {
    expect(authMessage('user-not-found'), authMessage('wrong-password'));
    expect(authMessage('network-request-failed'), contains('Koneksi'));
    expect(authMessage('unknown'), contains('belum berhasil'));
  });

  testWidgets('Login memvalidasi email, menahan kirim ganda, dan menampilkan error', (tester) async {
    var calls = 0;
    final pending = Completer<String?>();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(standalone: true,
      signIn: (email, password) { calls++; expect(email, 'admin@example.com'); return pending.future; })));
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password-uji');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.complete('Email atau password tidak sesuai.');
    await tester.pumpAndSettle();
    expect(find.text('Email atau password tidak sesuai.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reset email mempertahankan email dan memberi pesan netral', (tester) async {
    String? sent;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(standalone: true,
      resetPassword: (email) async { sent = email; return null; })));
    await tester.enterText(find.byType(TextFormField).first, 'petugas@example.com');
    await tester.ensureVisible(find.text('Lupa password?'));
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kirim Link Reset'));
    await tester.tap(find.text('Kirim Link Reset'));
    await tester.pumpAndSettle();
    expect(sent, 'petugas@example.com');
    expect(find.textContaining('Jika email terdaftar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1440, 900), const Size(390, 850), const Size(320, 700)]) {
    testWidgets('Navigasi admin responsif ${size.width}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      AdminPage? selected;
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(size.width == 320 ? 2 : 1)), child: child!),
        home: AdminShell(user: AppUser(uid: 'a', name: 'Admin', email: 'admin@example.com', role: UserRole.admin),
          page: AdminPage.ringkasan, onSelect: (p) => selected = p, onLogout: () {}, body: const Text('Isi dashboard'))));
      await tester.pumpAndSettle();
      final destination = find.byKey(const ValueKey('admin-nav-permohonan'));
      await tester.ensureVisible(destination);
      await tester.pumpAndSettle();
      await tester.tap(destination);
      expect(selected, AdminPage.permohonan);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Riwayat dimuat saat dibuka dan dapat dicoba lagi setelah gagal', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: AdminRequestHistory(requestId: 'abcdefghijklmnop', load: (_) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return [{'status': 'diproses'}];
      })))));
    expect(calls, 0);
    await tester.tap(find.text('Riwayat status'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Diproses'), findsOneWidget);
    expect(find.text('Waktu belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Permohonan lama tidak membuat riwayat fiktif', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminRequestHistory(
      requestId: 'old-request', load: (_) async => throw StateError('Tidak boleh dipanggil')))));
    expect(find.textContaining('Permohonan lama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Error sinkron loader menjadi pesan Coba lagi', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminRequestHistory(
      requestId: 'abcdefghijklmnop', load: (_) => throw StateError('offline')))));
    await tester.tap(find.text('Riwayat status'));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kegagalan riwayat setelah dialog ditutup tidak bocor', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminRequestHistory(
      requestId: 'abcdefghijklmnop', load: (_) => pending.future))));
    await tester.tap(find.text('Riwayat status'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

}
