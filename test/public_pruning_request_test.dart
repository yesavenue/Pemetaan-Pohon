import 'dart:async';
import 'dart:convert';
import 'public_test_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pemetaan_pohon/models/tree_pruning_request.dart';
import 'package:pemetaan_pohon/screens/public_pruning_request_screen.dart';

const _homeKey = ValueKey('test-public-home');
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settleBefore = true,
  bool settleAfter = true,
}) async {
  await revealPublicTarget(tester, finder, settle: settleBefore);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  if (settleAfter) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _fillApplicant(WidgetTester tester) async {
  const fields = {
    'Nama Lengkap *': 'Pemohon Uji',
    'Alamat Pemohon *': 'Alamat uji',
    'Nomor HP *': '081234567890',
    'Email *': 'uji@example.com',
    'Nomor KTP/NIK *': '1234567890123456',
  };
  for (final entry in fields.entries) {
    final finder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == entry.key,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, entry.value);
    await tester.pump();
  }
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> _fill(
  WidgetTester tester, {
  bool gps = false,
  bool otherReason = false,
}) async {
  await _fillApplicant(tester);
  await _tap(tester, find.text('Lanjut'));
  final address = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'Alamat/Lokasi Pohon *',
  );
  await tester.ensureVisible(address);
  await tester.pumpAndSettle();
  await tester.enterText(address, 'Jalan uji Kesambi');
  await tester.pump();
  // Set valid dropdown selections through the public widget callbacks.
  final selections = [
    'Kesambi',
    'Kesambi',
    otherReason ? 'Lainnya' : 'Pohon terlalu rimbun',
  ];
  for (var index = 0; index < selections.length; index++) {
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).at(index),
    );
    dropdown.onChanged!(selections[index]);
    await tester.pump();
  }
  if (otherReason) {
    final reason = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.labelText == 'Jelaskan alasan Anda',
    );
    await tester.ensureVisible(reason);
    await tester.pumpAndSettle();
    await tester.enterText(reason, 'Alasan uji lainnya');
    await tester.pump();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  if (gps) await _tap(tester, find.text('Gunakan Lokasi Saya'));
  for (final label in ['Tambahkan Foto Pohon', 'Tambahkan Foto KTP']) {
    await _tap(tester, find.text(label), settleAfter: false);
    await _tap(tester, find.text('Pilih dari Galeri'), settleBefore: false);
  }
  await _tap(tester, find.text('Lanjut'));
  await _tap(tester, find.byType(CheckboxListTile));
}

Widget _screen(
  Future<String> Function(TreePruningRequest) submit, {
  Future<Position> Function()? locate,
  Future<void> Function(String)? copyNumber,
  Future<XFile?> Function(ImageSource)? pickImage,
}) => PublicPruningRequestScreen(
  createRequest: submit,
  pickImage:
      pickImage ?? (_) async => XFile.fromData(_photo, mimeType: 'image/png'),
  locate: locate,
  copyNumber: copyNumber,
  homeBuilder: (_) => const Scaffold(key: _homeKey, body: Text('Beranda uji')),
);

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late bool previousHitTestPolicy;
  setUp(() {
    previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
  });
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
      expect(find.byKey(const ValueKey('public-header-solid')), findsOneWidget);
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

  testWidgets('Validasi per langkah dan Back mempertahankan isian', (
    tester,
  ) async {
    await _largeSurface(tester);
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _screen((_) async {
          writes++;
          return 'REQ-000126';
        }),
      ),
    );
    await _tap(tester, find.text('Lanjut'));
    expect(find.text('Wajib diisi'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await _fillApplicant(tester);
    await _tap(tester, find.text('Lanjut'));
    await _tap(tester, find.text('Lanjut'));
    expect(find.text('Foto pohon wajib diisi.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    await _tap(tester, find.text('Kembali'));
    expect(find.text('Pemohon Uji'), findsOneWidget);
    expect(find.text('1234567890123456'), findsOneWidget);
    expect(writes, 0);
  });

  testWidgets(
    'Ponsel teks 200%: salin gagal/retry, ajukan lagi bersih tanpa kirim otomatis',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var writes = 0, copies = 0;
      String? copied;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: _screen(
            (_) async {
              writes++;
              return writes == 1 ? 'REQ-000126' : 'REQ-000127';
            },
            copyNumber: (number) async {
              copies++;
              if (copies == 1) throw StateError('clipboard denied');
              copied = number;
            },
          ),
        ),
      );
      await _fill(tester);
      await _tap(tester, find.text('KIRIM PERMOHONAN'));
      await _tap(tester, find.text('Salin nomor'));
      expect(
        find.textContaining('Nomor belum berhasil disalin'),
        findsOneWidget,
      );
      expect(writes, 1);
      await _tap(tester, find.text('Salin nomor'));
      expect(copied, 'REQ-000126');
      await _tap(tester, find.text('Ajukan lagi'));
      expect(writes, 1);
      expect(find.text('Nomor Permohonan: REQ-000126'), findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await _fill(tester);
      await _tap(tester, find.text('KIRIM PERMOHONAN'));
      expect(writes, 2);
      expect(find.text('Nomor Permohonan: REQ-000127'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS gagal tetap dapat kirim alamat manual dan alasan Lainnya', (
    tester,
  ) async {
    await _largeSurface(tester);
    TreePruningRequest? payload;
    await tester.pumpWidget(
      MaterialApp(
        home: _screen((request) async {
          payload = request;
          return 'REQ-000128';
        }, locate: () async => throw StateError('denied')),
      ),
    );
    await _fill(tester, gps: true, otherReason: true);
    await _tap(tester, find.text('KIRIM PERMOHONAN'));
    expect(payload?.latitude, isNull);
    expect(payload?.longitude, isNull);
    expect(payload?.alamatPohon, 'Jalan uji Kesambi');
    expect(payload?.alasan, 'Alasan uji lainnya');
    expect(payload?.nik, '1234567890123456');
    expect(payload?.fotoKtpBase64, base64Encode(_photo));
  });

  testWidgets(
    'Foto pengganti terlalu besar tidak menghapus foto/draft sebelumnya',
    (tester) async {
      await _largeSurface(tester);
      var picks = 0;
      TreePruningRequest? payload;
      await tester.pumpWidget(
        MaterialApp(
          home: _screen(
            (request) async {
              payload = request;
              return 'REQ-000129';
            },
            pickImage: (_) async {
              picks++;
              final bytes = picks == 3
                  ? base64Decode(base64Encode(List<int>.filled(262501, 0)))
                  : _photo;
              return XFile.fromData(bytes, mimeType: 'image/png');
            },
          ),
        ),
      );
      await _fill(tester);
      await _tap(tester, find.text('Edit lokasi & foto'));
      await _tap(tester, find.text('Ganti Foto Pohon'), settleAfter: false);
      await _tap(tester, find.text('Pilih dari Galeri'), settleBefore: false);
      expect(
        find.textContaining('Foto kosong atau terlalu besar'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Lanjut'));
      await _tap(tester, find.text('KIRIM PERMOHONAN'));
      expect(payload?.fotoPohonBase64, base64Encode(_photo));
      expect(payload?.fotoKtpBase64, base64Encode(_photo));
      expect(tester.takeException(), isNull);
    },
  );
}