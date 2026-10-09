import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/models/app_user.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/models/tree_pruning_request.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_dialogs.dart';
import 'package:pemetaan_pohon/widgets/admin/admin_sections.dart';

final admin = AppUser(
  uid: 'admin',
  email: 'admin@example.com',
  role: UserRole.admin,
  name: 'Admin Uji',
);
final user = AppUser(
  uid: 's1',
  email: 'nama.panjang@example.com',
  role: UserRole.surveyor,
  name: 'Surveyor dengan nama panjang untuk tampilan ponsel',
);
TreeData tree(String id, {TreeStatus status = TreeStatus.pending}) => TreeData(
  id: id,
  latitude: -6.7,
  longitude: 108.5,
  photoBase64: 'broken',
  surveyorId: 's1',
  surveyorName: user.name,
  species: id == '1' ? 'Mahoni' : 'Mangga',
  kecamatan: 'Kesambi',
  kelurahan: 'Kesambi',
  namaJalan: 'Jalan panjang untuk uji',
  condition: TreeCondition.sehat,
  timestamp: DateTime(2026, 10, int.parse(id)),
  status: status,
  qrGenerated: true,
);
const photo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
TreePruningRequest request({PruningStatus status = PruningStatus.menunggu}) =>
    TreePruningRequest(
      id: 'r1',
      requestNumber: 'REQ-000001',
      namaPemohon: 'Pemohon Uji',
      alamatPemohon: 'Alamat pemohon',
      nomorHp: '081234567890',
      emailPemohon: 'pemohon@example.com',
      nik: '1234567890123456',
      alamatPohon: 'Jalan pohon dengan nama panjang',
      kecamatan: 'Kesambi',
      kelurahan: 'Kesambi',
      alasan: 'Pohon rimbun',
      fotoPohonBase64: photo,
      fotoKtpBase64: photo,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: status,
    );
Widget app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  await reveal(tester, field(label));
  await tester.enterText(field(label), value);
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> mobile(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

AdminTreesPane treesPane({
  Stream<List<TreeData>> Function()? load,
  Future<void> Function(List<TreeData>)? export,
  Future<String?> Function(String, TreeStatus)? status,
  Future<String?> Function(TreeData)? update,
}) => AdminTreesPane(
  admin: admin,
  load:
      load ??
      () => Stream.value([tree('1'), tree('2', status: TreeStatus.verified)]),
  create: (_) async => null,
  update: update ?? (_) async => null,
  setStatus: status ?? (_, __) async => null,
  delete: (_) async => null,
  export: export ?? (_) async {},
);

void main() {
  late bool oldPolicy;
  setUp(() {
    oldPolicy = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = oldPolicy;
  });

  testWidgets(
    'Surveyor ponsel 200%: search/filter, batal hapus dan reset hanya satu kali',
    (tester) async {
      await mobile(tester);
      var loads = 0, deletes = 0, resets = 0;
      final pending = Completer<String?>();
      await tester.pumpWidget(
        app(
          AdminSurveyorPane(
            load: () {
              loads++;
              return Stream.value([user]);
            },
            setActive: (_, __) async => null,
            deleteProfile: (_) async {
              deletes++;
              return null;
            },
            resetPassword: (_) {
              resets++;
              return pending.future;
            },
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'Cari nama atau email surveyor', 'tidak cocok');
      expect(
        find.text('Tidak ada surveyor sesuai pencarian/filter.'),
        findsOneWidget,
      );
      await enter(tester, 'Cari nama atau email surveyor', 'nama.panjang');
      await tap(tester, find.widgetWithText(ChoiceChip, 'Nonaktif'));
      expect(
        find.text('Tidak ada surveyor sesuai pencarian/filter.'),
        findsOneWidget,
      );
      await tap(tester, find.widgetWithText(ChoiceChip, 'Aktif'));
      await tap(tester, find.text('Hapus'));
      await tap(tester, find.text('Batal'));
      expect(deletes, 0);
      await tap(tester, find.text('Reset Password'));
      final callback = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('admin-dialog-submit')),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(resets, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AdminActionDialog), findsOneWidget);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(AdminActionDialog), findsNothing);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pohon desktop: export filter/semua/pilihan memakai cakupan yang tepat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final exports = <List<String>>[];
      await tester.pumpWidget(
        app(
          treesPane(
            export: (items) async {
              exports.add(items.map((t) => t.id).toList());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, 'Menunggu'));
      await tap(tester, find.text('Export Excel'));
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(exports.single, ['1']);
      await tester.pump(const Duration(seconds: 4));
      await tap(tester, find.text('Export Excel'));
      await tap(tester, find.text('Semua Data (2)'));
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(exports.last.toSet(), {'1', '2'});
      await tap(tester, find.text('Export Excel'));
      await tap(tester, find.text('Pilih Data Tertentu'));
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(exports.length, 2);
      expect(
        find.text('Pilih setidaknya satu data untuk diekspor.'),
        findsOneWidget,
      );
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(exports.last, ['1']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pohon ponsel 200%: verifikasi ganda dicegah, failure/retry dan filter mengikuti stream',
    (tester) async {
      await mobile(tester);
      final stream = StreamController<List<TreeData>>();
      addTearDown(stream.close);
      var writes = 0;
      final pending = Completer<String?>();
      await tester.pumpWidget(
        app(
          treesPane(
            load: () => stream.stream,
            status: (id, status) {
              expect(id, '1');
              expect(status, TreeStatus.verified);
              writes++;
              return writes == 1 ? pending.future : Future.value(null);
            },
          ),
          scale: 2,
        ),
      );
      stream.add([tree('1')]);
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(ChoiceChip, 'Menunggu'));
      await tap(tester, find.text('Verifikasi'));
      final callback = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('admin-dialog-submit')),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(writes, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AdminActionDialog), findsOneWidget);
      pending.complete('Gagal uji');
      await tester.pumpAndSettle();
      expect(find.text('Gagal uji'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(writes, 2);
      stream.add([tree('1', status: TreeStatus.verified)]);
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada pohon sesuai pencarian/filter.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Tambah pohon memvalidasi koordinat/keterangan dan payload tetap existing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TreeData? created;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTreeEditor(
                context,
                admin: admin,
                save: (t) async {
                  created = t;
                  return null;
                },
              ),
              child: const Text('Tambah'),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Tambah'));
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .onChanged!('Mahoni');
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<TreeCondition>>(
            find.byType(DropdownButtonFormField<TreeCondition>),
          )
          .onChanged!(TreeCondition.sakit);
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).last,
          )
          .onChanged!('Kesambi');
      await tester.pump();
      await enter(tester, 'Nama Jalan *', 'Jalan uji');
      await enter(tester, 'Latitude *', 'NaN');
      await enter(tester, 'Longitude *', '108.5');
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(created, isNull);
      expect(find.textContaining('Keterangan kondisi wajib'), findsOneWidget);
      await enter(tester, 'Keterangan Kondisi *', 'Daun rusak');
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(created, isNull);
      expect(find.textContaining('Isi koordinat valid'), findsOneWidget);
      await enter(tester, 'Latitude *', '-6.7');
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(created?.surveyorId, admin.uid);
      expect(created?.surveyorName, 'Admin: Admin Uji');
      expect(created?.status, TreeStatus.verified);
      expect(created?.photoBase64, '');
      expect(created?.qrGenerated, false);
      expect(created?.keteranganKondisi, 'Daun rusak');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Edit pohon mempertahankan ID/foto/koordinat/surveyor/tanggal/status/QR',
    (tester) async {
      final original = tree('1');
      TreeData? updated;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTreeEditor(
                context,
                admin: admin,
                tree: original,
                save: (t) async {
                  updated = t;
                  return null;
                },
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Edit'));
      await enter(tester, 'Nama Jalan', 'Jalan baru');
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(updated?.namaJalan, 'Jalan baru');
      expect(updated?.id, original.id);
      expect(updated?.photoBase64, original.photoBase64);
      expect(updated?.latitude, original.latitude);
      expect(updated?.longitude, original.longitude);
      expect(updated?.surveyorId, original.surveyorId);
      expect(updated?.surveyorName, original.surveyorName);
      expect(updated?.timestamp, original.timestamp);
      expect(updated?.status, original.status);
      expect(updated?.qrGenerated, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Permohonan ponsel 200%: privasi daftar, penolakan wajib, foto/export dan retry status',
    (tester) async {
      await mobile(tester);
      var writes = 0, words = 0, photos = 0;
      final pending = Completer<String?>();
      String? reason;
      await tester.pumpWidget(
        app(
          AdminRequestsPane(
            load: () => Stream.value([request()]),
            update: (id, status, note) {
              expect(id, 'r1');
              expect(status, PruningStatus.ditolak);
              reason = note;
              writes++;
              return writes == 1 ? pending.future : Future.value(null);
            },
            exportWord: (_) async {
              words++;
            },
            downloadPhoto: (_, __) {
              photos++;
            },
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1234567890123456'), findsNothing);
      await tap(tester, find.text('Tinjau'));
      expect(find.text('1234567890123456'), findsOneWidget);
      await tap(tester, find.text('Download Foto pohon'));
      await tap(tester, find.text('Download Foto KTP'));
      expect(photos, 2);
      await tap(tester, find.text('Export Word'));
      expect(words, 1);
      tester
          .widget<DropdownButtonFormField<PruningStatus>>(
            find.byType(DropdownButtonFormField<PruningStatus>),
          )
          .onChanged!(PruningStatus.ditolak);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(writes, 0);
      expect(
        find.text('Isi alasan penolakan sebelum menyimpan.'),
        findsOneWidget,
      );
      await enter(
        tester,
        'Alasan Penolakan *',
        'Lokasi bukan kewenangan dinas',
      );
      final callback = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('admin-dialog-submit')),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(writes, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AdminActionDialog), findsOneWidget);
      pending.complete('Status gagal uji');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Alasan Penolakan *')).controller!.text,
        'Lokasi bukan kewenangan dinas',
      );
      await tap(tester, find.byKey(const ValueKey('admin-dialog-submit')));
      expect(writes, 2);
      expect(reason, 'Lokasi bukan kewenangan dinas');
      expect(find.text('1234567890123456'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Stream error/retry dan jenis yang hilang tidak membuat dropdown assert',
    (tester) async {
      final first = StreamController<List<TreeData>>(),
          second = StreamController<List<TreeData>>();
      addTearDown(first.close);
      addTearDown(second.close);
      var loads = 0;
      await tester.pumpWidget(
        app(treesPane(load: () => ++loads == 1 ? first.stream : second.stream)),
      );
      // No stream event yet: the indeterminate loader intentionally keeps ticking.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Memuat data…'), findsOneWidget);
      first.addError(StateError('private backend details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('private backend'), findsNothing);
      final retry = find.text('Coba lagi');
      await reveal(tester, retry);
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry.hitTestable());
      await tester.pump();
      expect(loads, 2);
      expect(second.hasListener, true);
      second.add([tree('1')]);
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byType(DropdownButtonFormField<String?>),
          )
          .onChanged!('Mahoni');
      await tester.pumpAndSettle();
      second.add([tree('2')]);
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada pohon sesuai pencarian/filter.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Reset filter'));
      expect(find.text('1 hasil dari 1 data.'), findsOneWidget);
      expect(loads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}