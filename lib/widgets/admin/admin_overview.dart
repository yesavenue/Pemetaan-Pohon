import 'package:flutter/material.dart';
import '../civic_design.dart';
import '../../models/app_user.dart';
import '../../models/tree_data.dart';
import '../../models/tree_pruning_request.dart';
import '../../theme/app_theme.dart';
import '../../utils/tree_condition_style.dart';
import '../../view_models/admin_summary.dart';
import '../surveyor/tree_thumbnail.dart';

class AdminOverview extends StatefulWidget {
  final String adminName;
  final Stream<List<AppUser>> Function() loadSurveyors;
  final Stream<List<TreeData>> Function() loadTrees;
  final Stream<List<TreePruningRequest>> Function() loadRequests;
  final VoidCallback onAddSurveyor, onAddTree, onAllTrees, onAllRequests;
  final ValueChanged<TreeData> onReviewTree;
  final ValueChanged<TreePruningRequest> onReviewRequest;
  final Widget Function(BuildContext, List<TreeData>) mapBuilder;
  const AdminOverview({
    super.key,
    required this.adminName,
    required this.loadSurveyors,
    required this.loadTrees,
    required this.loadRequests,
    required this.onAddSurveyor,
    required this.onAddTree,
    required this.onAllTrees,
    required this.onAllRequests,
    required this.onReviewTree,
    required this.onReviewRequest,
    required this.mapBuilder,
  });
  @override
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> {
  late Stream<List<AppUser>> _surveyors;
  late Stream<List<TreeData>> _trees;
  late Stream<List<TreePruningRequest>> _requests;
  bool _requestTab = false, _allSpecies = false;
  @override
  void initState() {
    super.initState();
    _surveyors = widget.loadSurveyors();
    _trees = widget.loadTrees();
    _requests = widget.loadRequests();
  }

  bool _ready<T>(AsyncSnapshot<List<T>> s) =>
      !s.hasError && s.hasData && s.connectionState != ConnectionState.waiting;
  String? _value<T>(AsyncSnapshot<List<T>> s, int Function(List<T>) count) =>
      _ready(s) ? '${count(s.data!)}' : null;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: _surveyors,
    builder: (context, users) => StreamBuilder<List<TreeData>>(
      stream: _trees,
      builder: (context, trees) => StreamBuilder<List<TreePruningRequest>>(
        stream: _requests,
        builder: (context, requests) {
          final summary = AdminSummary(
            trees: _ready(trees) ? trees.data! : [],
            surveyors: _ready(users) ? users.data! : [],
            requests: _ready(requests) ? requests.data! : [],
          );
          return SingleChildScrollView(
            key: const PageStorageKey('admin-overview-scroll'),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CivicHeading(
                      eyebrow: 'RUANG KERJA ADMIN',
                      title: 'Selamat datang, ${widget.adminName}',
                      description:
                          'Pantau pendataan pohon dan tindak lanjuti permohonan warga Kota Cirebon.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: widget.onAddSurveyor,
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Tambah Surveyor'),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onAddTree,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Tambah Pohon'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, c) {
                        final scale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final columns = c.maxWidth >= 1000 * scale
                            ? 4
                            : c.maxWidth >= 300 * scale
                            ? 2
                            : 1;
                        final width =
                            (c.maxWidth - (columns - 1) * 12) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metric(
                              width,
                              'Total pohon',
                              _value(trees, (items) => items.length),
                              trees.hasError,
                              'Seluruh status admin',
                              Icons.park_outlined,
                            ),
                            _metric(
                              width,
                              'Surveyor aktif',
                              _value(users, (_) => summary.activeSurveyors),
                              users.hasError,
                              'Akun surveyor aktif',
                              Icons.groups_outlined,
                            ),
                            _metric(
                              width,
                              'Pohon menunggu',
                              _value(trees, (_) => summary.pendingTrees.length),
                              trees.hasError,
                              'Perlu verifikasi',
                              Icons.fact_check_outlined,
                            ),
                            _metric(
                              width,
                              'Permohonan menunggu',
                              _value(
                                requests,
                                (_) => summary.waitingRequests.length,
                              ),
                              requests.hasError,
                              'Status Menunggu',
                              Icons.content_cut_outlined,
                            ),
                          ],
                        );
                      },
                    ),
                    if (users.hasError || !_ready(users))
                      _state(
                        users,
                        'surveyor',
                        () =>
                            setState(() => _surveyors = widget.loadSurveyors()),
                      ),
                    const SizedBox(height: 24),
                    _panel('Perlu ditindaklanjuti', [
                      const Text(
                        'Antrean berstatus menunggu, yang paling lama ditampilkan lebih dahulu. Tinjau detail sebelum mengambil keputusan.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(
                              'Pohon${_ready(trees) ? ' (${summary.pendingTrees.length})' : ''}',
                            ),
                            selected: !_requestTab,
                            onSelected: (_) =>
                                setState(() => _requestTab = false),
                          ),
                          ChoiceChip(
                            label: Text(
                              'Permohonan${_ready(requests) ? ' (${summary.waitingRequests.length})' : ''}',
                            ),
                            selected: _requestTab,
                            onSelected: (_) =>
                                setState(() => _requestTab = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_requestTab) ...[
                        if (!_ready(trees))
                          _state(
                            trees,
                            'pohon',
                            () => setState(() => _trees = widget.loadTrees()),
                          )
                        else if (summary.pendingTrees.isEmpty)
                          const Text('Tidak ada pohon menunggu verifikasi.')
                        else
                          _treeQueue(summary.pendingTrees),
                        if (_ready(trees))
                          TextButton(
                            onPressed: widget.onAllTrees,
                            child: const Text('Lihat semua pohon menunggu'),
                          ),
                      ] else ...[
                        if (!_ready(requests))
                          _state(
                            requests,
                            'permohonan',
                            () => setState(
                              () => _requests = widget.loadRequests(),
                            ),
                          )
                        else if (summary.waitingRequests.isEmpty)
                          const Text('Tidak ada permohonan menunggu.')
                        else
                          _requestQueue(summary.waitingRequests),
                        if (_ready(requests))
                          TextButton(
                            onPressed: widget.onAllRequests,
                            child: const Text(
                              'Lihat semua permohonan menunggu',
                            ),
                          ),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    if (!_ready(trees))
                      _panel('Sebaran dan kondisi pohon', [
                        _state(
                          trees,
                          'pohon',
                          () => setState(() => _trees = widget.loadTrees()),
                        ),
                      ])
                    else ...[
                      LayoutBuilder(
                        builder: (context, c) {
                          final conditions = _panel('Kondisi seluruh pohon', [
                            Text(
                              'Lingkup: ${summary.trees.length} pohon, seluruh status admin.',
                            ),
                            for (final condition in TreeCondition.values)
                              _bar(
                                condition.label,
                                summary.conditionCount(condition),
                                summary.trees.length,
                                treeConditionColor(condition),
                              ),
                          ]);
                          final map = _panel('Sebaran pohon terverifikasi', [
                            Text(
                              '${summary.verifiedTrees.length} pohon terverifikasi • ${summary.mapTrees.length} titik dengan koordinat valid.',
                            ),
                            const SizedBox(height: 12),
                            if (summary.mapTrees.isEmpty)
                              const Text(
                                'Belum ada titik terverifikasi dengan koordinat valid.',
                              )
                            else
                              widget.mapBuilder(context, summary.mapTrees),
                          ]);
                          if (c.maxWidth >= 900 &&
                              MediaQuery.textScalerOf(context).scale(14) <=
                                  19) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: map),
                                const SizedBox(width: 16),
                                Expanded(child: conditions),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              map,
                              const SizedBox(height: 16),
                              conditions,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _panel('Distribusi jenis pohon', [
                        const Text(
                          'Seluruh status admin. Jumlah setiap jenis tersedia dalam teks.',
                        ),
                        if (summary.trees.isEmpty)
                          const Text('Belum ada data pohon.')
                        else ...[
                          for (final item
                              in (_allSpecies
                                  ? summary.speciesCounts
                                  : summary.speciesCounts.take(5)))
                            _bar(
                              item.key,
                              item.value,
                              summary.trees.length,
                              AppColors.leaf,
                            ),
                          if (!_allSpecies && summary.speciesCounts.length > 5)
                            _bar(
                              'Jenis lainnya',
                              summary.speciesCounts
                                  .skip(5)
                                  .fold<int>(0, (sum, e) => sum + e.value),
                              summary.trees.length,
                              AppColors.navy,
                            ),
                          if (summary.speciesCounts.length > 5)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _allSpecies = !_allSpecies),
                              child: Text(
                                _allSpecies
                                    ? 'Ringkas jenis'
                                    : 'Lihat semua jenis',
                              ),
                            ),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _metric(
    double width,
    String label,
    String? value,
    bool error,
    String scope,
    IconData icon,
  ) => SizedBox(
    width: width,
    child: Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDCE5E0)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon == Icons.park_outlined)
              const TreeSilhouette(color: AppColors.leaf)
            else
              Icon(icon, color: AppColors.leaf),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value ?? (error ? 'Tidak tersedia' : 'Memuat…'),
              key: ValueKey('admin-metric-$label'),
              style: TextStyle(
                fontSize: value == null ? 16 : 30,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            Text(scope),
          ],
        ),
      ),
    ),
  );

  Widget _state<T>(
    AsyncSnapshot<List<T>> s,
    String label,
    VoidCallback retry,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.hasError
                ? 'Data $label gagal dimuat. Periksa koneksi lalu coba lagi.'
                : 'Memuat data $label…',
          ),
          if (s.hasError)
            TextButton(onPressed: retry, child: Text('Coba lagi $label')),
        ],
      ),
    ),
  );
  Widget _panel(String title, List<Widget> children) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFDCE5E0)),
    ),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _bar(String label, int count, int total, Color color) => Builder(
    builder: (context) => Semantics(
      label: '$label: $count dari $total pohon',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$label: $count',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Color(0xFFDCE5E0)),
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: total == 0 ? 0 : count / total,
                      ),
                      duration: Duration(
                        milliseconds: MediaQuery.of(context).disableAnimations
                            ? 0
                            : 360,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (_, fraction, child) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '0',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
                Text(
                  '$total pohon',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  bool _table(BuildContext context, double width) =>
      width >= 1050 && MediaQuery.textScalerOf(context).scale(14) <= 19;
  String _location(String road, String kel, String kec) =>
      [road, kel, kec].where((v) => v.trim().isNotEmpty).join(', ');
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _treeQueue(List<TreeData> all) => LayoutBuilder(
    builder: (context, c) {
      final items = all.take(5).toList();
      if (_table(context, c.maxWidth)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Menampilkan ${items.length} dari ${all.length} pohon menunggu.',
            ),
            DataTable(
              dataRowMinHeight: 64,
              dataRowMaxHeight: 100,
              columns: const [
                DataColumn(label: Text('Pohon')),
                DataColumn(label: Text('Lokasi')),
                DataColumn(label: Text('Surveyor')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: [
                for (final t in items)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Row(
                            children: [
                              TreeThumbnail(base64: t.photoBase64, size: 40),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.species,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            _location(t.namaJalan, t.kelurahan, t.kecamatan),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            t.surveyorName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const DataCell(Text('Menunggu')),
                      DataCell(
                        TextButton(
                          key: ValueKey('review-tree-${t.id}'),
                          onPressed: () => widget.onReviewTree(t),
                          child: const Text('Tinjau'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Menampilkan ${items.length} dari ${all.length} pohon menunggu.',
          ),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TreeThumbnail(base64: t.photoBase64, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    t.species,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(_location(t.namaJalan, t.kelurahan, t.kecamatan)),
                  Text('Surveyor: ${t.surveyorName}'),
                  const Text('Menunggu verifikasi'),
                  TextButton(
                    key: ValueKey('review-tree-${t.id}'),
                    onPressed: () => widget.onReviewTree(t),
                    child: const Text('Tinjau'),
                  ),
                  const Divider(),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _requestQueue(List<TreePruningRequest> all) => LayoutBuilder(
    builder: (context, c) {
      final items = all.take(5).toList();
      if (_table(context, c.maxWidth)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Menampilkan ${items.length} dari ${all.length} permohonan menunggu.',
            ),
            DataTable(
              dataRowMinHeight: 64,
              dataRowMaxHeight: 100,
              columns: const [
                DataColumn(label: Text('Nomor')),
                DataColumn(label: Text('Lokasi')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: [
                for (final r in items)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(
                            r.requestNumber,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: Text(
                            _location(r.alamatPohon, r.kelurahan, r.kecamatan),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_date(r.createdAt))),
                      const DataCell(Text('Menunggu')),
                      DataCell(
                        TextButton(
                          key: ValueKey('review-request-${r.id}'),
                          onPressed: () => widget.onReviewRequest(r),
                          child: const Text('Tinjau'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Menampilkan ${items.length} dari ${all.length} permohonan menunggu.',
          ),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.requestNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(_location(r.alamatPohon, r.kelurahan, r.kecamatan)),
                  Text('Menunggu • ${_date(r.createdAt)}'),
                  TextButton(
                    key: ValueKey('review-request-${r.id}'),
                    onPressed: () => widget.onReviewRequest(r),
                    child: const Text('Tinjau'),
                  ),
                  const Divider(),
                ],
              ),
            ),
        ],
      );
    },
  );
}