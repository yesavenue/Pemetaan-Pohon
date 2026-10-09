import 'package:flutter/material.dart';
import '../widgets/civic_design.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../utils/cirebon_regions.dart';
import '../utils/tree_condition_style.dart';
import '../view_models/public_statistics.dart';
import '../widgets/public_navbar.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/public/public_motion.dart';
import '../widgets/public/public_visuals.dart';
import '../widgets/public/public_footer.dart';
import '../widgets/public/public_bar_chart.dart';
import 'public_map_viewer_screen.dart';

class PublicStatistikScreen extends StatefulWidget {
  final Stream<List<TreeData>>? treeStream;
  final Widget Function(String?)? mapPageBuilder;
  const PublicStatistikScreen({
    super.key,
    this.treeStream,
    this.mapPageBuilder,
  });
  @override
  State<PublicStatistikScreen> createState() => _PublicStatistikScreenState();
}

class _PublicStatistikScreenState extends State<PublicStatistikScreen> {
  late Stream<List<TreeData>> _stream;
  String? _kecamatan;
  bool _table = false;
  @override
  void initState() {
    super.initState();
    _stream = _newStream();
  }

  Stream<List<TreeData>> _newStream() =>
      widget.treeStream ?? TreeService().streamTrees();
  @override
  void didUpdateWidget(covariant PublicStatistikScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeStream != widget.treeStream) _stream = _newStream();
  }

  @override
  Widget build(BuildContext context) => PublicScaffold(
    currentPage: PublicPage.statistik,
    body: PublicPageScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    const heading = CivicHeading(
                      eyebrow: 'DATA RUANG HIJAU',
                      title: 'Statistik pohon Kota Cirebon',
                      description:
                          'Ringkasan kondisi dan sebaran dari data pohon yang sudah terverifikasi.',
                    );
                    final toolbar = Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: box.maxWidth < 480 ? box.maxWidth : 240,
                          child: DropdownButtonFormField<String?>(
                            itemHeight: null,
                            value: _kecamatan,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Wilayah statistik',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Semua Kecamatan'),
                              ),
                              for (final k in cirebonKecamatanList)
                                DropdownMenuItem(value: k, child: Text(k)),
                            ],
                            onChanged: (value) =>
                                setState(() => _kecamatan = value),
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _table = !_table),
                              icon: Icon(
                                _table
                                    ? Icons.bar_chart
                                    : Icons.table_rows_outlined,
                              ),
                              label: Text(
                                _table ? 'Lihat grafik' : 'Lihat tabel data',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          widget.mapPageBuilder?.call(
                                            _kecamatan,
                                          ) ??
                                          PublicMapViewerScreen(
                                            initialKecamatan: _kecamatan,
                                          ),
                                    ),
                                  ),
                              icon: const Icon(Icons.map_outlined),
                              label: Text(
                                _kecamatan == null
                                    ? 'Lihat di peta'
                                    : 'Peta $_kecamatan',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, const SizedBox(height: 24), toolbar],
                    );
                  },
                ),
                const SizedBox(height: 32),
                StreamBuilder<List<TreeData>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _section(
                        'Data belum berhasil dimuat',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Periksa koneksi lalu coba lagi.'),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _stream = _newStream()),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Memuat statistik',
                        ),
                      );
                    }
                    final stats = PublicStatistics.fromTrees(
                      snapshot.data!,
                      kecamatan: _kecamatan,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summary(stats),
                        const SizedBox(height: 24),
                        if (stats.total == 0)
                          _section(
                            'Belum ada data',
                            Text(
                              _kecamatan == null
                                  ? 'Belum ada pohon terverifikasi.'
                                  : 'Belum ada pohon terverifikasi di $_kecamatan.',
                            ),
                          ),
                        if (stats.total > 0 && _table) ...[
                          _section(
                            'Kondisi — tabel data',
                            _tableRows(
                              stats.conditions.entries.map(
                                (e) => MapEntry(e.key.label, e.value),
                              ),
                            ),
                          ),
                          _section(
                            'Jenis — seluruh data',
                            _tableRows(stats.species.entries),
                          ),
                          _section(
                            'Kecamatan — tabel data',
                            _tableRows(stats.districts.entries),
                          ),
                        ] else if (stats.total > 0) ...[
                          LayoutBuilder(
                            builder: (context, box) {
                              final condition = _section(
                                'Kondisi pohon',
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 250,
                                  ),
                                  child: _donut(stats),
                                ),
                              );
                              final species = _section(
                                'Jenis terbanyak',
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 250,
                                  ),
                                  child: _bars(
                                    stats.topSpecies(),
                                    PublicUi.green,
                                  ),
                                ),
                              );
                              if (box.maxWidth >= 900 &&
                                  MediaQuery.textScalerOf(context).scale(14) <=
                                      21) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: condition),
                                    const SizedBox(width: 16),
                                    Expanded(child: species),
                                  ],
                                );
                              }
                              return Column(children: [condition, species]);
                            },
                          ),
                          _section(
                            'Sebaran per kecamatan',
                            PublicBarChart(
                              entries: stats.districts.entries.toList(),
                              color: PublicUi.green,
                              vertical: true,
                            ),
                          ),
                        ],
                        const Text(
                          'Kondisi rawan tumbang merupakan catatan pada data pohon, bukan prediksi risiko otomatis.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const PublicFooter(currentPage: PublicPage.statistik),
      ],
    ),
  );

  Widget _summary(PublicStatistics stats) => LayoutBuilder(
    builder: (context, box) {
      final values = [
        ('Total pohon', stats.total, PublicUi.green, Icons.park_rounded),
        for (final c in TreeCondition.values)
          (
            c.label,
            stats.conditions[c]!,
            treeConditionColor(c),
            publicConditionIcon(c),
          ),
      ];
      final columns = MediaQuery.textScalerOf(context).scale(14) > 21
          ? 1
          : box.maxWidth >= 900
          ? 4
          : box.maxWidth >= 500
          ? 2
          : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in values)
            SizedBox(
              width: (box.maxWidth - 16 * (columns - 1)) / columns,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      PublicIconTile(icon: item.$4, color: item.$3),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PublicValueChange(
                              identity: (_kecamatan, item.$1, item.$2),
                              child: Text(
                                '${item.$2}',
                                key: ValueKey('stat-${item.$1}'),
                                style: const TextStyle(
                                  fontSize: 32,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.$1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _section(String title, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 24),
    child: Padding(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
  Widget _donut(PublicStatistics stats) => LayoutBuilder(
    builder: (context, box) {
      final chartSize = box.maxWidth.clamp(0.0, 210.0).toDouble();
      final chart = SizedBox(
        width: chartSize,
        height: chartSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: stats.total == 0
                  ? Container(
                      width: chartSize * .9,
                      height: chartSize * .9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: PublicUi.border, width: 26),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        centerSpaceRadius: chartSize / 3,
                        sectionsSpace: 3,
                        sections: [
                          for (final c in TreeCondition.values)
                            if (stats.conditions[c]! > 0)
                              PieChartSectionData(
                                value: stats.conditions[c]!.toDouble(),
                                color: treeConditionColor(c),
                                radius: chartSize * .124,
                                showTitle: false,
                              ),
                        ],
                      ),
                      duration: PublicUi.duration(context, 400),
                    ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stats.total}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'pohon',
                  style: TextStyle(fontSize: 14, color: PublicUi.muted),
                ),
              ],
            ),
          ],
        ),
      );
      final legend = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in TreeCondition.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  TreeSilhouette(color: treeConditionColor(c), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${c.label}: ${stats.conditions[c]} pohon (${stats.total == 0 ? '0' : (100 * stats.conditions[c]! / stats.total).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
      return Column(
        children: [
          if (box.maxWidth >= 500 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18.2)
            Row(
              children: [
                chart,
                const SizedBox(width: 24),
                Expanded(child: legend),
              ],
            )
          else ...[
            Center(child: chart),
            const SizedBox(height: 16),
            legend,
          ],
          const SizedBox(height: 16),
          Text(
            'Berdasarkan ${stats.total} pohon terverifikasi',
            style: const TextStyle(fontSize: 14, color: PublicUi.muted),
          ),
        ],
      );
    },
  );
  Widget _bars(Iterable<MapEntry<String, int>> values, Color color) =>
      PublicBarChart(entries: values.toList(), color: color);

  Widget _tableRows(Iterable<MapEntry<String, int>> rows) {
    if (rows.isEmpty) return const Text('Belum ada data.');
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(row.key)),
                const SizedBox(width: 16),
                Text('${row.value} pohon'),
              ],
            ),
          ),
      ],
    );
  }
}