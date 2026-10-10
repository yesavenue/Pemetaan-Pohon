import 'package:flutter/material.dart';
import '../../utils/session_feed.dart';
import 'admin_dialog_scope.dart';
import 'admin_export_picker.dart';
import '../civic_design.dart';
import '../../utils/tree_condition_style.dart';
import '../../models/app_user.dart';
import '../../models/tree_data.dart';
import '../../models/tree_pruning_request.dart';
import '../../theme/app_theme.dart';
import '../surveyor/tree_thumbnail.dart';
import 'admin_dialogs.dart';

Widget _badge(String text, Color color) => Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    text,
    style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
  ),
);
Widget _conditionBadge(TreeCondition condition) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: treeConditionColor(condition).withValues(alpha: .1),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TreeSilhouette(color: treeConditionColor(condition), size: 20),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          condition.label,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ),
);

Widget _dataState({
  required IconData icon,
  required String title,
  required String description,
  Widget? action,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 24),
  child: Column(
    children: [
      Icon(icon, color: AppColors.navy, size: 32),
      const SizedBox(height: 12),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(description, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 12), action],
    ],
  ),
);

Widget _cell(String text, {double width = 160}) => SizedBox(
  width: width,
  child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
);
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
String _location(TreeData t) => [
  t.namaJalan,
  t.kelurahan,
  t.kecamatan,
].where((s) => s.trim().isNotEmpty).join(', ');
void _notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Header scrolls with content; cards are lazy, tables have a horizontal viewport.
class _DataFrame<T> extends StatefulWidget {
  final String title, description, empty;
  final AsyncSnapshot<List<T>> snapshot;
  final List<T> items;
  final List<Widget> controls;
  final VoidCallback retry;
  final Widget Function(T) card;
  final Widget Function(List<T>) table;
  const _DataFrame({
    required this.title,
    required this.description,
    required this.snapshot,
    required this.items,
    required this.controls,
    required this.retry,
    required this.empty,
    required this.card,
    required this.table,
  });
  @override
  State<_DataFrame<T>> createState() => _DataFrameState<T>();
}

class _DataFrameState<T> extends State<_DataFrame<T>> {
  int _page = 0;
  static const _pageSize = 25;
  String get title => widget.title;
  String get description => widget.description;
  String get empty => widget.empty;
  AsyncSnapshot<List<T>> get snapshot => widget.snapshot;
  List<T> get items => widget.items;
  List<Widget> get controls => widget.controls;
  VoidCallback get retry => widget.retry;
  Widget Function(T) get card => widget.card;
  Widget Function(List<T>) get table => widget.table;

  @override
  void didUpdateWidget(covariant _DataFrame<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != items.length ||
        Iterable<int>.generate(
          items.length,
        ).any((i) => oldWidget.items[i] != items[i])) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final ready =
          snapshot.hasData &&
          !snapshot.hasError &&
          snapshot.connectionState != ConnectionState.waiting;
      final wide =
          c.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(14) <= 19;
      final pages = (items.length / _pageSize).ceil();
      final pageItems = items.skip(_page * _pageSize).take(_pageSize).toList();
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CivicHeading(
                    eyebrow: 'PENGELOLAAN KOTA',
                    title: title,
                    description: description,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCE5E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: controls,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    _dataState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Data gagal dimuat',
                      description:
                          'Periksa koneksi dan hak akses, lalu coba kembali.',
                      action: TextButton.icon(
                        onPressed: retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    )
                  else if (!ready)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(
                            semanticsLabel: 'Memuat data',
                          ),
                          SizedBox(height: 12),
                          Text('Memuat data…'),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      '${items.length} hasil dari ${snapshot.data!.length} data.',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (wide && pages > 1)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Halaman ${_page + 1} dari $pages • maksimal $_pageSize baris',
                          ),
                          IconButton(
                            tooltip: 'Halaman sebelumnya',
                            onPressed: _page == 0
                                ? null
                                : () => setState(() => _page--),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Halaman berikutnya',
                            onPressed: _page + 1 >= pages
                                ? null
                                : () => setState(() => _page++),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    if (items.isEmpty)
                      _dataState(
                        icon: snapshot.data!.isEmpty
                            ? Icons.inventory_2_outlined
                            : Icons.search_off_rounded,
                        title: empty,
                        description: snapshot.data!.isEmpty
                            ? 'Data yang tersedia akan tampil di sini.'
                            : 'Coba kata kunci lain atau sesuaikan filter di atas.',
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (ready && items.isNotEmpty && wide)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: table(pageItems),
                  ),
                ),
              ),
            )
          else if (ready && items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card(items[i]),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      );
    },
  );
}

Widget _card(List<Widget> children) => Card(
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Colors.black12),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);

class AdminSurveyorPane extends StatefulWidget {
  final Stream<List<AppUser>> Function() load;
  final Future<String?> Function(String, bool) setActive;
  final Future<String?> Function(String) resetPassword, deleteProfile;
  final ValueChanged<bool>? onBusy;
  const AdminSurveyorPane({
    super.key,
    required this.load,
    required this.setActive,
    required this.resetPassword,
    required this.deleteProfile,
    this.onBusy,
  });
  @override
  State<AdminSurveyorPane> createState() => _AdminSurveyorPaneState();
}

class _AdminSurveyorPaneState extends State<AdminSurveyorPane> {
  late Stream<List<AppUser>> _stream;
  final _search = TextEditingController();
  bool? _active;
  @override
  void initState() {
    super.initState();
    _stream = widget.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirm(
    String title,
    String text,
    AdminWrite action, {
    bool destructive = false,
  }) async {
    final result = await openAdminAction(
      context,
      AdminActionDialog(
        title: title,
        submitLabel: destructive ? 'Hapus' : 'Lanjutkan',
        content: (_, __) => Text(text),
        operation: action,
        destructive: destructive,
        onBusy: widget.onBusy,
      ),
    );
    if (mounted && result == true) {
      _notice(
        context,
        'Tindakan surveyor berhasil. Daftar mengikuti pembaruan data.',
      );
    }
  }

  Widget _actions(AppUser u) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: () => _confirm(
          u.isActive ? 'Nonaktifkan surveyor?' : 'Aktifkan surveyor?',
          'Ubah status akun ${u.name}? Akun nonaktif tidak dapat mengakses aplikasi.',
          () => widget.setActive(u.uid, !u.isActive),
        ),
        child: Text(u.isActive ? 'Nonaktifkan' : 'Aktifkan'),
      ),
      TextButton(
        onPressed: () => _confirm(
          'Reset password surveyor?',
          'Kirim link reset password ke ${u.email}?',
          () => widget.resetPassword(u.email),
        ),
        child: const Text('Reset Password'),
      ),
      TextButton(
        onPressed: () => _confirm(
          'Hapus profil surveyor?',
          'Hapus profil ${u.name} secara permanen dan hentikan akses aplikasinya? Tindakan ini tidak dapat dibatalkan.',
          () => widget.deleteProfile(u.uid),
          destructive: true,
        ),
        child: const Text('Hapus'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: _stream,
    builder: (context, s) {
      final q = _search.text.trim().toLowerCase();
      final filtered =
          (s.data ?? [])
              .where(
                (u) =>
                    u.role == UserRole.surveyor &&
                    (_active == null || u.isActive == _active) &&
                    (q.isEmpty ||
                        u.name.toLowerCase().contains(q) ||
                        u.email.toLowerCase().contains(q)),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return _DataFrame<AppUser>(
        title: 'Kelola surveyor',
        description: 'Cari akun, atur status dan kirim link reset password.',
        snapshot: s,
        items: filtered,
        controls: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari nama atau email surveyor',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in <bool?>[null, true, false])
                ChoiceChip(
                  label: Text(
                    value == null
                        ? 'Semua'
                        : value
                        ? 'Aktif'
                        : 'Nonaktif',
                  ),
                  selected: _active == value,
                  onSelected: (_) => setState(() => _active = value),
                ),
            ],
          ),
        ],
        retry: () => setState(() => _stream = widget.load()),
        empty: (s.data ?? []).isEmpty
            ? 'Belum ada surveyor terdaftar.'
            : 'Tidak ada surveyor sesuai pencarian/filter.',
        card: (u) => _card([
          Text(
            u.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(u.email),
          const SizedBox(height: 12),
          _badge(
            u.isActive ? 'Aktif' : 'Nonaktif',
            u.isActive ? AppColors.leaf : Colors.red.shade800,
          ),
          Text(
            'Wajib ganti password: ${u.requiresPasswordChange ? 'Ya' : 'Tidak'}',
          ),
          const SizedBox(height: 12),
          _actions(u),
        ]),
        table: (items) => DataTable(
          dataRowMinHeight: 72,
          dataRowMaxHeight: 150,
          columns: const [
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ganti password')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: [
            for (final u in items)
              DataRow(
                cells: [
                  DataCell(_cell(u.name)),
                  DataCell(_cell(u.email, width: 220)),
                  DataCell(Text(u.isActive ? 'Aktif' : 'Nonaktif')),
                  DataCell(Text(u.requiresPasswordChange ? 'Wajib' : 'Tidak')),
                  DataCell(SizedBox(width: 430, child: _actions(u))),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class AdminTreesPane extends StatefulWidget {
  final AppUser admin;
  final Stream<List<TreeData>> Function() load;
  final Future<String?> Function(TreeData) create, update;
  final Future<String?> Function(String, TreeStatus) setStatus;
  final Future<String?> Function(String) delete;
  final Future<void> Function(List<TreeData>) export;
  final Future<void> Function(List<TreeData>, String)? exportReport;
  final ValueChanged<bool>? onBusy;
  const AdminTreesPane({
    super.key,
    required this.admin,
    required this.load,
    required this.create,
    required this.update,
    required this.setStatus,
    required this.delete,
    required this.export,
    this.exportReport,
    this.onBusy,
  });
  @override
  State<AdminTreesPane> createState() => AdminTreesPaneState();
}

class AdminTreesPaneState extends State<AdminTreesPane> {
  late Stream<List<TreeData>> _stream;
  late final SessionFeed<List<TreeData>> _feed;
  final _search = TextEditingController();
  TreeStatus? _status;
  TreeCondition? _condition;
  String? _species;
  bool _newest = true;
  @override
  void initState() {
    super.initState();
    _feed = SessionFeed(widget.load);
    _stream = _feed.watch();
  }

  @override
  void dispose() {
    _feed.dispose();
    _search.dispose();
    super.dispose();
  }

  void showPendingTrees() => setState(() {
    _status = TreeStatus.pending;
    _condition = null;
    _species = null;
    _search.clear();
    _newest = false;
  });
  Future<void> showAddTreeDialog() async {
    final ok = await showTreeEditor(
      context,
      admin: widget.admin,
      save: widget.create,
      onBusy: widget.onBusy,
    );
    if (mounted && ok == true) _notice(context, 'Data pohon ditambahkan.');
  }

  Future<void> _edit(TreeData t) async {
    final ok = await showTreeEditor(
      context,
      admin: widget.admin,
      tree: t,
      save: widget.update,
      onBusy: widget.onBusy,
    );
    if (mounted && ok == true) _notice(context, 'Data pohon diperbarui.');
  }

  Future<void> showTreeReview(TreeData tree) async {
    if (!canOpenAdminDialog(context)) {
      return;
    }
    final updates = _feed.watch();
    final ok = await showOwnedAdminDialog<bool>(
      context,
      dismissible: false,
      builder: (_) => StreamBuilder<List<TreeData>>(
        stream: updates,
        initialData: _feed.latest,
        builder: (context, snapshot) {
          TreeData? current;
          for (final row in snapshot.data ?? <TreeData>[]) {
            if (row.id == tree.id) {
              current = row;
              break;
            }
          }
          final row = current;
          final ready = !snapshot.hasError && snapshot.hasData;
          return AdminActionDialog(
            title: row == null ? 'Tinjau pohon' : 'Tinjau ${row.species}',
            submitLabel: row?.status == TreeStatus.verified
                ? 'Batalkan verifikasi'
                : 'Verifikasi',
            canSubmit: ready && row != null,
            onBusy: widget.onBusy,
            content: (_, __) => row == null || !ready
                ? Text(
                    snapshot.hasError
                        ? 'Data terbaru gagal dimuat. Tutup dialog dan coba muat ulang daftar.'
                        : ready
                        ? 'Pohon ini sudah dihapus atau tidak lagi tersedia.'
                        : 'Memuat data terbaru…',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      adminTreeReview(row),
                      const SizedBox(height: 12),
                      Text(
                        row.status == TreeStatus.pending
                            ? 'Verifikasi akan menampilkan pohon ini pada peta publik.'
                            : 'Pembatalan verifikasi akan menyembunyikan pohon ini dari peta publik.',
                      ),
                    ],
                  ),
            validate: () {
              final latest = _feed.latest;
              if (latest == null) {
                return 'Data terbaru belum tersedia.';
              }
              TreeData? found;
              for (final item in latest) {
                if (item.id == tree.id) {
                  found = item;
                  break;
                }
              }
              if (found == null) {
                return 'Pohon sudah tidak tersedia.';
              }
              if (!identical(found, row)) {
                return 'Data berubah. Tinjau informasi terbaru sebelum melanjutkan.';
              }
              return null;
            },
            operation: () => widget.setStatus(
              tree.id,
              row!.status == TreeStatus.pending
                  ? TreeStatus.verified
                  : TreeStatus.pending,
            ),
          );
        },
      ),
    );
    if (mounted && ok == true) {
      _notice(context, 'Status pohon diperbarui.');
    }
  }

  Future<void> _confirm(TreeData t, bool delete) async {
    if (!delete) {
      await showTreeReview(t);
      return;
    }
    final ok = await openAdminAction(
      context,
      AdminActionDialog(
        title: 'Hapus data pohon?',
        submitLabel: 'Hapus',
        destructive: true,
        onBusy: widget.onBusy,
        content: (_, __) => Text(
          'Hapus ${t.species} secara permanen? Tindakan ini tidak dapat dibatalkan.',
        ),
        operation: () => widget.delete(t.id),
      ),
    );
    if (mounted && ok == true) {
      _notice(context, 'Data pohon dihapus.');
    }
  }

  Widget _actions(TreeData t) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        onPressed: () => showTreeReview(t),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Tinjau'),
      ),
      PopupMenuButton<String>(
        tooltip: 'Aksi lain untuk ${t.species}',
        onSelected: (value) {
          if (value == 'edit') {
            _edit(t);
          } else if (value == 'delete') {
            _confirm(t, true);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    ],
  );
  Future<void> _export(List<TreeData> all, List<TreeData> filtered) async {
    var scope = 'filtered';
    final selected = <String>{};
    await openAdminAction(
      context,
      AdminActionDialog(
        title: 'Export data ke Excel',
        submitLabel: 'Export',
        onBusy: widget.onBusy,
        content: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in ['all', 'filtered', 'pilih'])
              Semantics(
                selected: scope == option,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option == 'all'
                        ? 'Semua Data (${all.length})'
                        : option == 'filtered'
                        ? 'Sesuai Filter Saat Ini (${filtered.length})'
                        : 'Pilih Data Tertentu',
                  ),
                  leading: Icon(
                    scope == option
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => setState(() => scope = option),
                ),
              ),
            if (scope == 'pilih')
              AdminExportPicker(
                items: filtered,
                selected: selected,
                onChanged: () => setState(() {}),
              ),
          ],
        ),
        validate: () =>
            (scope == 'all'
                    ? all
                    : scope == 'filtered'
                    ? filtered
                    : filtered.where((t) => selected.contains(t.id)))
                .isEmpty
            ? 'Pilih setidaknya satu data untuk diekspor.'
            : null,
        operation: () async {
          final rows = scope == 'all'
              ? all
              : scope == 'filtered'
              ? filtered
              : filtered.where((t) => selected.contains(t.id)).toList();
          final filters = [
            if (_search.text.trim().isNotEmpty)
              'Pencarian: ${_search.text.trim()}',
            if (_status != null)
              'Status: ${_status == TreeStatus.verified ? "Terverifikasi" : "Menunggu"}',
            if (_condition != null) 'Kondisi: ${_condition!.label}',
            if (_species != null) 'Jenis: $_species',
          ];
          final description = scope == 'all'
              ? 'Semua data'
              : '${scope == "pilih" ? "Pilihan manual" : "Hasil filter"}'
                    '${filters.isEmpty ? " (tanpa filter aktif)" : " • ${filters.join("; ")}"}';
          if (widget.exportReport != null) {
            await widget.exportReport!(rows, description);
          } else {
            await widget.export(rows);
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TreeData>>(
    stream: _stream,
    builder: (context, s) {
      final all = s.data ?? <TreeData>[];
      final q = _search.text.trim().toLowerCase();
      final kinds = all.map((t) => t.species).toSet()
        ..addAll(_species == null ? [] : [_species!]);
      final sortedKinds = kinds.toList()..sort();
      final items =
          all
              .where(
                (t) =>
                    (_status == null || t.status == _status) &&
                    (_condition == null || t.condition == _condition) &&
                    (_species == null || t.species == _species) &&
                    (q.isEmpty ||
                        [
                          t.species,
                          t.surveyorName,
                          t.kecamatan,
                          t.kelurahan,
                          t.namaJalan,
                        ].any((v) => v.toLowerCase().contains(q))),
              )
              .toList()
            ..sort((a, b) {
              final cmp = _newest
                  ? b.timestamp.compareTo(a.timestamp)
                  : a.timestamp.compareTo(b.timestamp);
              return cmp != 0 ? cmp : a.id.compareTo(b.id);
            });
      return _DataFrame<TreeData>(
        title: 'Data pohon',
        description:
            'Seluruh status admin. Verifikasi menentukan pohon yang tampil pada peta publik.',
        snapshot: s,
        items: items,
        controls: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari jenis, surveyor, wilayah atau jalan',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in <TreeStatus?>[null, ...TreeStatus.values])
                ChoiceChip(
                  label: Text(
                    status == null
                        ? 'Semua'
                        : status == TreeStatus.pending
                        ? 'Menunggu'
                        : 'Terverifikasi',
                  ),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = box.maxWidth >= 720 * scale ? 3 : 1;
              final width = (box.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  SizedBox(
                    width: width,
                    child: adminSelect<String?>(
                      'Jenis',
                      _species,
                      [null, ...sortedKinds],
                      (v) => v ?? 'Semua jenis',
                      (v) => setState(() => _species = v),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: adminSelect<TreeCondition?>(
                      'Kondisi',
                      _condition,
                      [null, ...TreeCondition.values],
                      (v) => v?.label ?? 'Semua kondisi',
                      (v) => setState(() => _condition = v),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: adminSelect(
                      'Urutan',
                      _newest,
                      [true, false],
                      (v) => v ? 'Terbaru' : 'Terlama',
                      (v) => setState(() => _newest = v ?? true),
                    ),
                  ),
                ],
              );
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _status = null;
                  _condition = null;
                  _species = null;
                  _search.clear();
                  _newest = true;
                }),
                child: const Text('Reset filter'),
              ),
              OutlinedButton.icon(
                onPressed: s.hasError || !s.hasData || all.isEmpty
                    ? null
                    : () => _export(List.of(all), List.of(items)),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export Excel'),
              ),
            ],
          ),
        ],
        retry: () {
          _feed.reload();
          setState(() => _stream = _feed.watch());
        },
        empty: all.isEmpty
            ? 'Belum ada data pohon.'
            : 'Tidak ada pohon sesuai pencarian/filter.',
        card: (t) => _card([
          TreeThumbnail(base64: t.photoBase64, size: 600, height: 140),
          const SizedBox(height: 12),
          Text(
            t.species,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(_location(t)),
          Text('Surveyor: ${t.surveyorName} • ${_date(t.timestamp)}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _conditionBadge(t.condition),
              _badge(
                t.status == TreeStatus.verified ? 'Terverifikasi' : 'Menunggu',
                t.status == TreeStatus.verified
                    ? AppColors.leaf
                    : AppColors.navy,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kewenangan: ${t.ranahKewenangan.isEmpty ? 'Belum diketahui' : t.ranahKewenangan}',
          ),
          const SizedBox(height: 12),
          _actions(t),
        ]),
        table: (items) => DataTable(
          dataRowMinHeight: 80,
          dataRowMaxHeight: 160,
          columns: const [
            DataColumn(label: Text('Pohon')),
            DataColumn(label: Text('Lokasi')),
            DataColumn(label: Text('Kondisi')),
            DataColumn(label: Text('Kewenangan')),
            DataColumn(label: Text('Surveyor')),
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: [
            for (final t in items)
              DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        TreeThumbnail(base64: t.photoBase64, size: 48),
                        const SizedBox(width: 8),
                        _cell(t.species),
                      ],
                    ),
                  ),
                  DataCell(_cell(_location(t))),
                  DataCell(_conditionBadge(t.condition)),
                  DataCell(
                    _cell(
                      t.ranahKewenangan.isEmpty
                          ? 'Belum diketahui'
                          : t.ranahKewenangan,
                    ),
                  ),
                  DataCell(_cell(t.surveyorName)),
                  DataCell(Text(_date(t.timestamp))),
                  DataCell(
                    Text(
                      t.status == TreeStatus.verified
                          ? 'Terverifikasi'
                          : 'Menunggu',
                    ),
                  ),
                  DataCell(SizedBox(width: 190, child: _actions(t))),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class AdminRequestsPane extends StatefulWidget {
  final Stream<List<TreePruningRequest>> Function() load;
  final RequestStatusWrite update;
  final Future<void> Function(TreePruningRequest) exportWord;
  final void Function(TreePruningRequest, bool) downloadPhoto;
  final ValueChanged<bool>? onBusy;
  const AdminRequestsPane({
    super.key,
    required this.load,
    required this.update,
    required this.exportWord,
    required this.downloadPhoto,
    this.onBusy,
  });
  @override
  State<AdminRequestsPane> createState() => AdminRequestsPaneState();
}

class AdminRequestsPaneState extends State<AdminRequestsPane> {
  late Stream<List<TreePruningRequest>> _stream;
  PruningStatus? _status;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _stream = widget.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void showWaitingRequests() => setState(() {
    _status = PruningStatus.menunggu;
    _search.clear();
  });
  Future<void> showRequest(TreePruningRequest r) async {
    final ok = await showAdminRequestDetail(
      context,
      r,
      update: widget.update,
      exportWord: widget.exportWord,
      downloadPhoto: widget.downloadPhoto,
      onBusy: widget.onBusy,
    );
    if (mounted && ok == true) {
      _notice(context, 'Status permohonan diperbarui.');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TreePruningRequest>>(
    stream: _stream,
    builder: (context, s) {
      final q = _search.text.trim().toLowerCase();
      final items =
          (s.data ?? [])
              .where(
                (r) =>
                    (_status == null || r.status == _status) &&
                    (q.isEmpty ||
                        [
                          r.requestNumber,
                          r.namaPemohon,
                          r.alamatPohon,
                          r.kecamatan,
                          r.kelurahan,
                        ].any((v) => v.toLowerCase().contains(q))),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _DataFrame<TreePruningRequest>(
        title: 'Permohonan perapihan',
        description:
            'Tinjau detail dan foto, perbarui status, lalu ekspor dokumen.',
        snapshot: s,
        items: items,
        controls: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari nomor atau lokasi permohonan',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in <PruningStatus?>[
                null,
                ...PruningStatus.values,
              ])
                ChoiceChip(
                  label: Text(status?.label ?? 'Semua'),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
        ],
        retry: () => setState(() => _stream = widget.load()),
        empty: (s.data ?? []).isEmpty
            ? 'Belum ada permohonan masuk.'
            : 'Tidak ada permohonan sesuai pencarian/filter.',
        card: (r) => _card([
          Text(
            r.requestNumber,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text('Pemohon: ${r.namaPemohon}'),
          Text('${r.alamatPohon}, ${r.kelurahan}, ${r.kecamatan}'),
          Text('Diajukan ${_date(r.createdAt)}'),
          const SizedBox(height: 12),
          _badge(
            r.status.label,
            r.status == PruningStatus.ditolak
                ? Colors.red.shade800
                : AppColors.navy,
          ),
          TextButton(
            onPressed: () => showRequest(r),
            child: const Text('Tinjau'),
          ),
        ]),
        table: (items) => DataTable(
          dataRowMinHeight: 72,
          dataRowMaxHeight: 130,
          columns: const [
            DataColumn(label: Text('Nomor')),
            DataColumn(label: Text('Pemohon')),
            DataColumn(label: Text('Lokasi pohon')),
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: [
            for (final r in items)
              DataRow(
                cells: [
                  DataCell(_cell(r.requestNumber)),
                  DataCell(_cell(r.namaPemohon)),
                  DataCell(
                    _cell('${r.alamatPohon}, ${r.kecamatan}', width: 320),
                  ),
                  DataCell(Text(_date(r.createdAt))),
                  DataCell(Text(r.status.label)),
                  DataCell(
                    TextButton(
                      onPressed: () => showRequest(r),
                      child: const Text('Tinjau'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}