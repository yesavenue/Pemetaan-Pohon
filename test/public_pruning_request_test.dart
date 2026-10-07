import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pemetaan_pohon/models/tree_pruning_request.dart';
import 'package:pemetaan_pohon/screens/public_pruning_request_screen.dart';

const _homeKey = ValueKey('test-public-home');
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  const fields = {
    'Nama Lengkap *': 'Pemohon Uji',
    'Alamat Pemohon *': 'Alamat uji',
    'Nomor HP *': '081234567890',
    'Email *': 'uji@example.com',
    'Nomor KTP/NIK *': '1234567890123456',
    'Alamat/Lokasi Pohon *': 'Jalan uji Kesambi',
  };
  for (final entry in fields.entries) {
    final finder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == entry.key,
    );
    await tester.ensureVisible(finder);
    await tester.enterText(finder, entry.value);
    await tester.pump();
  }
  // Set valid dropdown selections through the public widget callbacks.
  const selections = ['Kesambi', 'Kesambi', 'Pohon terlalu rimbun'];
  for (var index = 0; index < selections.length; index++) {
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).at(index),
    );
    dropdown.onChanged!(selections[index]);
    await tester.pump();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  for (final label in ['Tambahkan Foto Pohon', 'Tambahkan Foto KTP']) {
    await _tap(tester, find.text(label));
    await _tap(tester, find.text('Pilih dari Galeri'));
  }
  await _tap(tester, find.byType(CheckboxListTile));
}

Widget _screen(Future<String> Function(TreePruningRequest) submit) =>
    PublicPruningRequestScreen(
      createRequest: submit,
      pickImage: (_) async => XFile.fromData(_photo, mimeType: 'image/png'),
      homeBuilder: (_) =>
          const Scaffold(key: _homeKey, body: Text('Beranda uji')),
    );

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  for (final replaced in [false, true]) {
    testWidgets('Sukses kembali ke Beranda, replacement=$replaced', (
      tester,
    ) async {
      await _largeSurface(tester);
      var calls = 0;
      final pending = Completer<String>();
      final screen = _screen((request) {
        calls++;
        expect(request.namaPemohon, 'Pemohon Uji');
        expect(request.fotoPohonBase64, isNotEmpty);
        return pending.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: replaced
              ? Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => screen),
                      ),
                      child: const Text('Buka permohonan'),
                    ),
                  ),
                )
              : screen,
        ),
      );
      if (replaced) await _tap(tester, find.text('Buka permohonan'));
      await _fill(tester);
      final button = find.widgetWithText(FilledButton, 'KIRIM PERMOHONAN');
      final callback = tester.widget<FilledButton>(button).onPressed!;
      callback();
      callback(); // Stale callback / rapid double activation must still write once.
      await tester.pump();
      expect(calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PublicPruningRequestScreen), findsOneWidget);
      pending.complete('REQ-000123');
      await tester.pumpAndSettle();
      expect(find.text('Nomor Permohonan: REQ-000123'), findsOneWidget);
      expect(find.text('KIRIM PERMOHONAN'), findsNothing);
      await _tap(tester, find.text('Kembali ke Beranda'));
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byType(PublicPruningRequestScreen), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Gagal mempertahankan draft dan foto, retry berhasil', (
    tester,
  ) async {
    await _largeSurface(tester);
    final payloads = <TreePruningRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _screen((request) async {
          payloads.add(request);
          if (payloads.length == 1) throw StateError('Simulated write failure');
          return 'REQ-000124';
        }),
      ),
    );
    await _fill(tester);
    await _tap(tester, find.text('KIRIM PERMOHONAN'));
    expect(find.textContaining('Isian tetap tersedia'), findsOneWidget);
    expect(find.text('Pemohon Uji'), findsOneWidget);
    expect(find.text('Permohonan Berhasil Dikirim'), findsNothing);
    await _tap(tester, find.text('KIRIM PERMOHONAN'));
    expect(payloads, hasLength(2));
    expect(payloads.last.namaPemohon, payloads.first.namaPemohon);
    expect(payloads.last.nik, payloads.first.nik);
    expect(payloads.last.fotoKtpBase64, payloads.first.fotoKtpBase64);
    expect(payloads.last.fotoPohonBase64, payloads.first.fotoPohonBase64);
    expect(find.text('Nomor Permohonan: REQ-000124'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hasil submit setelah widget dilepas tidak menavigasi', (
    tester,
  ) async {
    await _largeSurface(tester);
    final pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(home: _screen((_) => pending.future)));
    await _fill(tester);
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'KIRIM PERMOHONAN'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Halaman lain')));
    pending.complete('REQ-000125');
    await tester.pumpAndSettle();
    expect(find.text('Halaman lain'), findsOneWidget);
    expect(find.text('Permohonan Berhasil Dikirim'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}