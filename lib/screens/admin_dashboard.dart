import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../models/tree_pruning_request.dart';
import '../services/auth_service.dart';
import '../services/pruning_request_service.dart';
import '../services/tree_service.dart';
import '../utils/pruning_docx_builder.dart';
import '../utils/tree_condition_style.dart';
import '../utils/tree_excel_export.dart';
import '../utils/tree_options.dart';
import '../utils/web_download.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser adminUser;
  const AdminDashboard({super.key, required this.adminUser});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _treeService = TreeService();
  final _dataPohonKey = GlobalKey<_DataPohonSectionState>();
  int _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Daftar Surveyor', 'Data Pohon', 'Permohonan Perapihan'];

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isCreatingUser = false;

  void _showAddSurveyorDialog() {
    _nameController.clear();
    _emailController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Buat Akun Surveyor Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email Pekerjaan'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Password otomatis: Surveyor123!',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isCreatingUser ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: _isCreatingUser
                      ? null
                      : () async {
                          setDialogState(() => _isCreatingUser = true);
                          String? error = await _authService.createSurveyorByAdmin(
                            _nameController.text.trim(),
                            _emailController.text.trim(),
                            'Surveyor123!',
                          );

                          setDialogState(() => _isCreatingUser = false);

                          if (!context.mounted) return;

                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error), backgroundColor: Colors.red),
                            );
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Akun Surveyor berhasil dibuat!'),
                                  backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: _isCreatingUser
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Buat Akun'),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin: ${widget.adminUser.name} — ${_titles[_selectedIndex]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          )
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: true,
            minExtendedWidth: 200,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.none,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: Text('Surveyor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.park_outlined),
                selectedIcon: Icon(Icons.park),
                label: Text('Data Pohon'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.content_cut_outlined),
                selectedIcon: Icon(Icons.content_cut),
                label: Text('Permohonan'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _DashboardOverviewSection(authService: _authService, treeService: _treeService),
                _SurveyorSection(authService: _authService),
                _DataPohonSection(
                  key: _dataPohonKey,
                  treeService: _treeService,
                  adminUser: widget.adminUser,
                ),
                const _PruningRequestSection(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddSurveyorDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Surveyor'),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => _dataPohonKey.currentState?.showAddTreeDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Data Pohon'),
                )
              : null,
    );
  }
}

// ==================== HELPER BERSAMA ====================

Uint8List? _decodeBase64(String data) {
  if (data.isEmpty) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

String _formatDate(DateTime date) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${date.day} ${bulan[date.month - 1]} ${date.year}';
}

void _showTreeDetailDialog(BuildContext context, TreeData tree) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(tree.species),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_decodeBase64(tree.photoBase64) != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _decodeBase64(tree.photoBase64)!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Kecamatan', value: tree.kecamatan.isEmpty ? '-' : tree.kecamatan),
                _DetailRow(label: 'Kelurahan', value: tree.kelurahan.isEmpty ? '-' : tree.kelurahan),
                _DetailRow(label: 'Nama Jalan', value: tree.namaJalan.isEmpty ? '-' : tree.namaJalan),
                _DetailRow(label: 'Jenis Pohon', value: tree.species),
                _DetailRow(label: 'Kondisi Pohon', value: tree.condition.label),
                if (tree.keteranganKondisi.isNotEmpty)
                  _DetailRow(label: 'Keterangan', value: tree.keteranganKondisi),
                _DetailRow(label: 'Surveyor', value: tree.surveyorName),
                _DetailRow(label: 'Tanggal', value: _formatDate(tree.timestamp)),
                _DetailRow(
                  label: 'Status',
                  value: tree.status == TreeStatus.verified ? 'Terverifikasi' : 'Menunggu',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ==================== DASHBOARD ====================

const _chartPalette = [
  Color(0xFF2E7D32),
  Color(0xFF8D6E63),
  Color(0xFF00897B),
  Color(0xFFF9A825),
  Color(0xFF6A1B9A),
  Color(0xFF1565C0),
  Color(0xFFAD1457),
  Color(0xFF558B2F),
];

class _DashboardOverviewSection extends StatelessWidget {
  final AuthService authService;
  final TreeService treeService;
  const _DashboardOverviewSection({required this.authService, required this.treeService});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<AppUser>>(
        stream: authService.streamSurveyors(),
        builder: (context, surveyorSnapshot) {
          final surveyors = surveyorSnapshot.data ?? [];
          final activeCount = surveyors.where((s) => s.isActive).length;

          return StreamBuilder<List<TreeData>>(
            stream: treeService.streamTrees(),
            builder: (context, treeSnapshot) {
              final trees = treeSnapshot.data ?? [];
              final pendingCount = trees.where((t) => t.status == TreeStatus.pending).length;
              // Peta cuma menampilkan pohon yang sudah diverifikasi admin.
              final verifiedTrees = trees.where((t) => t.status == TreeStatus.verified).toList();

              final speciesCount = <String, int>{};
              for (final tree in trees) {
                speciesCount[tree.species] = (speciesCount[tree.species] ?? 0) + 1;
              }

              final sehatCount = trees.where((t) => t.condition == TreeCondition.sehat).length;
              final sakitCount = trees.where((t) => t.condition == TreeCondition.sakit).length;
              final rawanCount = trees.where((t) => t.condition == TreeCondition.rawanTumbang).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(label: 'Total Surveyor', value: '${surveyors.length}'),
                      _StatCard(label: 'Surveyor Aktif', value: '$activeCount'),
                      _StatCard(label: 'Total Titik Pohon', value: '${trees.length}'),
                      _StatCard(label: 'Menunggu Verifikasi', value: '$pendingCount'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final speciesChart = _ChartCard(
                        title: 'Distribusi Jenis Pohon',
                        height: 300,
                        child: speciesCount.isEmpty
                            ? const _EmptyChartHint(text: 'Belum ada data pohon.')
                            : _SpeciesPieChart(speciesCount: speciesCount),
                      );
                      final conditionChart = _ChartCard(
                        title: 'Jumlah Pohon per Kondisi',
                        height: 300,
                        child: trees.isEmpty
                            ? const _EmptyChartHint(text: 'Belum ada data pohon.')
                            : _ConditionBarChart(sehat: sehatCount, sakit: sakitCount, rawan: rawanCount),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: speciesChart),
                            const SizedBox(width: 16),
                            Expanded(child: conditionChart),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          speciesChart,
                          const SizedBox(height: 16),
                          conditionChart,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _TreeMapCard(trees: verifiedTrees),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          SizedBox(
            height: height,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  final String text;
  const _EmptyChartHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: const TextStyle(color: Colors.black38)));
  }
}

class _SpeciesPieChart extends StatelessWidget {
  final Map<String, int> speciesCount;
  const _SpeciesPieChart({required this.speciesCount});

  @override
  Widget build(BuildContext context) {
    final entries = speciesCount.entries.toList();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (int i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _chartPalette[i % _chartPalette.length],
                    title: '${entries[i].value}',
                    radius: 70,
                    titleStyle: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _chartPalette[i % _chartPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entries[i].key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConditionBarChart extends StatelessWidget {
  final int sehat;
  final int sakit;
  final int rawan;
  const _ConditionBarChart({required this.sehat, required this.sakit, required this.rawan});

  @override
  Widget build(BuildContext context) {
    final maxY = ([sehat, sakit, rawan].reduce((a, b) => a > b ? a : b) + 2).toDouble();
    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: sehat.toDouble(), color: treeConditionColor(TreeCondition.sehat), width: 32),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: sakit.toDouble(), color: treeConditionColor(TreeCondition.sakit), width: 32),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: rawan.toDouble(), color: treeConditionColor(TreeCondition.rawanTumbang), width: 32),
          ]),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const labels = ['Sehat', 'Sakit', 'Rawan\nTumbang'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[value.toInt()],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _TreeMapCard extends StatefulWidget {
  final List<TreeData> trees;
  const _TreeMapCard({required this.trees});

  @override
  State<_TreeMapCard> createState() => _TreeMapCardState();
}

class _TreeMapCardState extends State<_TreeMapCard> {
  String _speciesFilter = 'Semua';
  TreeCondition? _conditionFilter;

  @override
  Widget build(BuildContext context) {
    final speciesInData = widget.trees.map((t) => t.species).toSet().toList()..sort();

    final filtered = widget.trees.where((t) {
      final matchesSpecies =
          _speciesFilter == 'Semua' || t.species.trim().toLowerCase() == _speciesFilter.trim().toLowerCase();
      final matchesCondition = _conditionFilter == null || t.condition == _conditionFilter;
      return matchesSpecies && matchesCondition;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Peta Sebaran Pohon (Terverifikasi)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _FilterDropdown<String>(
                  value: _speciesFilter,
                  items: ['Semua', ...speciesInData],
                  labelBuilder: (v) => v,
                  onChanged: (v) => setState(() => _speciesFilter = v ?? 'Semua'),
                ),
                _FilterDropdown<TreeCondition?>(
                  value: _conditionFilter,
                  items: [null, ...TreeCondition.values],
                  labelBuilder: (v) => v == null ? 'Semua Kondisi' : v.label,
                  onChanged: (v) => setState(() => _conditionFilter = v),
                ),
                if (_speciesFilter != 'Semua' || _conditionFilter != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _speciesFilter = 'Semua';
                      _conditionFilter = null;
                    }),
                    child: const Text('Reset Filter'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 420, child: _TreeMap(trees: filtered)),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items
              .map((item) => DropdownMenuItem<T>(value: item, child: Text(labelBuilder(item))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TreeMap extends StatelessWidget {
  final List<TreeData> trees;
  const _TreeMap({required this.trees});

  static const _defaultCenter = LatLng(-2.5489, 118.0149); // tengah Indonesia
  static const _defaultZoom = 5.0;

  @override
  Widget build(BuildContext context) {
    final center = trees.isEmpty
        ? _defaultCenter
        : LatLng(
            trees.map((t) => t.latitude).reduce((a, b) => a + b) / trees.length,
            trees.map((t) => t.longitude).reduce((a, b) => a + b) / trees.length,
          );

    // Lookup cepat untuk tahu kondisi tiap pohon di dalam satu cluster,
    // dipakai untuk mewarnai lingkaran cluster berdasarkan kondisi terparah.
    final treeById = {for (final t in trees) t.id: t};

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: trees.isEmpty ? _defaultZoom : 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pemetaanpohon.app',
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 50,
                size: const Size(42, 42),
                markers: trees.map((tree) {
                  return Marker(
                    key: ValueKey(tree.id),
                    point: LatLng(tree.latitude, tree.longitude),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _showTreeDetailDialog(context, tree),
                      child: Icon(
                        Icons.location_on,
                        color: treeConditionColor(tree.condition),
                        size: 32,
                      ),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  final conditions = markers
                      .map((m) => treeById[(m.key as ValueKey<String>).value]?.condition)
                      .whereType<TreeCondition>()
                      .toSet();
                  final worst = conditions.contains(TreeCondition.rawanTumbang)
                      ? TreeCondition.rawanTumbang
                      : conditions.contains(TreeCondition.sakit)
                          ? TreeCondition.sakit
                          : TreeCondition.sehat;
                  final color = treeConditionColor(worst);
                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${markers.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (trees.isEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Text(
                'Belum ada pohon terverifikasi untuk ditampilkan.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendDot(treeConditionColor(TreeCondition.sehat), 'Sehat'),
                const SizedBox(width: 10),
                _legendDot(treeConditionColor(TreeCondition.sakit), 'Sakit'),
                const SizedBox(width: 10),
                _legendDot(treeConditionColor(TreeCondition.rawanTumbang), 'Rawan Tumbang'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ==================== SURVEYOR ====================

class _SurveyorSection extends StatefulWidget {
  final AuthService authService;
  const _SurveyorSection({required this.authService});

  @override
  State<_SurveyorSection> createState() => _SurveyorSectionState();
}

class _SurveyorSectionState extends State<_SurveyorSection> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Cari nama atau email surveyor...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.trim().toLowerCase());
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: widget.authService.streamSurveyors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? all
                    : all.where((s) {
                        return s.name.toLowerCase().contains(_searchQuery) ||
                            s.email.toLowerCase().contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'Belum ada surveyor terdaftar. Klik "Tambah Surveyor" untuk mulai.'
                          : 'Tidak ada surveyor yang cocok dengan pencarian.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nama')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Wajib Ganti Password')),
                        DataColumn(label: Text('Aksi')),
                      ],
                      rows: filtered.map(_buildRow).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(AppUser surveyor) {
    return DataRow(
      cells: [
        DataCell(Text(surveyor.name)),
        DataCell(Text(surveyor.email)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (surveyor.isActive ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              surveyor.isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                color: surveyor.isActive ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(Text(surveyor.requiresPasswordChange ? 'Ya' : 'Tidak')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: surveyor.isActive,
                onChanged: (value) async {
                  final error = await widget.authService.setSurveyorActiveStatus(surveyor.uid, value);
                  if (error != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.lock_reset_outlined, size: 20),
                tooltip: 'Reset Password',
                onPressed: () => _showResetPasswordConfirm(surveyor),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                tooltip: 'Hapus surveyor',
                onPressed: () => _showDeleteSurveyorConfirm(surveyor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetPasswordConfirm(AppUser surveyor) {
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password Surveyor?'),
              content: Text(
                'Email berisi link reset password akan dikirim ke:\n${surveyor.email}\n\n'
                'Surveyor bisa membuat password baru sendiri lewat link tersebut.',
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          setDialogState(() => isSending = true);
                          final error = await widget.authService.sendPasswordResetEmail(surveyor.email);
                          if (!context.mounted) return;
                          setDialogState(() => isSending = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Email reset password dikirim ke ${surveyor.email}.')),
                            );
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteSurveyorConfirm(AppUser surveyor) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Surveyor?'),
          content: Text(
            'Profil "${surveyor.name}" akan dihapus dan surveyor ini tidak akan bisa lagi login. '
            'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final error = await widget.authService.deleteSurveyorProfile(surveyor.uid);
                if (!mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Surveyor dihapus.')),
                  );
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}

// ==================== DATA POHON ====================

enum _StatusFilter { semua, menunggu, terverifikasi }

class _DataPohonSection extends StatefulWidget {
  final TreeService treeService;
  final AppUser adminUser;
  const _DataPohonSection({super.key, required this.treeService, required this.adminUser});

  @override
  State<_DataPohonSection> createState() => _DataPohonSectionState();
}

class _DataPohonSectionState extends State<_DataPohonSection> {
  String _searchQuery = '';
  _StatusFilter _statusFilter = _StatusFilter.semua;
  String _speciesFilter = 'Semua';
  TreeCondition? _conditionFilter;
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari jenis pohon, surveyor, kecamatan, atau jalan...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim().toLowerCase());
                  },
                ),
              ),
              const SizedBox(width: 12),
              _StatusFilterChips(
                selected: _statusFilter,
                onSelected: (filter) => setState(() => _statusFilter = filter),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<TreeData>>(
            stream: widget.treeService.streamTrees(),
            builder: (context, snapshot) {
              final speciesInData =
                  (snapshot.data ?? []).map((t) => t.species).toSet().toList()..sort();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FilterDropdown<String>(
                    value: _speciesFilter,
                    items: ['Semua', ...speciesInData],
                    labelBuilder: (v) => v,
                    onChanged: (v) => setState(() => _speciesFilter = v ?? 'Semua'),
                  ),
                  _FilterDropdown<TreeCondition?>(
                    value: _conditionFilter,
                    items: [null, ...TreeCondition.values],
                    labelBuilder: (v) => v == null ? 'Semua Kondisi' : v.label,
                    onChanged: (v) => setState(() => _conditionFilter = v),
                  ),
                  _FilterDropdown<bool>(
                    value: _newestFirst,
                    items: const [true, false],
                    labelBuilder: (v) => v ? 'Terbaru' : 'Terlama',
                    onChanged: (v) => setState(() => _newestFirst = v ?? true),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<TreeData>>(
              stream: widget.treeService.streamTrees(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                final filtered = all.where((tree) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      tree.species.toLowerCase().contains(_searchQuery) ||
                      tree.surveyorName.toLowerCase().contains(_searchQuery) ||
                      tree.kecamatan.toLowerCase().contains(_searchQuery) ||
                      tree.namaJalan.toLowerCase().contains(_searchQuery);
                  final matchesStatus = switch (_statusFilter) {
                    _StatusFilter.semua => true,
                    _StatusFilter.menunggu => tree.status == TreeStatus.pending,
                    _StatusFilter.terverifikasi => tree.status == TreeStatus.verified,
                  };
                  final matchesSpecies = _speciesFilter == 'Semua' ||
                      tree.species.trim().toLowerCase() == _speciesFilter.trim().toLowerCase();
                  final matchesCondition = _conditionFilter == null || tree.condition == _conditionFilter;
                  return matchesSearch && matchesStatus && matchesSpecies && matchesCondition;
                }).toList()
                  ..sort((a, b) => _newestFirst
                      ? b.timestamp.compareTo(a.timestamp)
                      : a.timestamp.compareTo(b.timestamp));

                final tableOrEmpty = filtered.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty
                              ? 'Belum ada data pohon yang masuk dari surveyor.'
                              : 'Tidak ada data yang cocok dengan pencarian/filter.',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Foto')),
                              DataColumn(label: Text('Jenis Pohon')),
                              DataColumn(label: Text('Kondisi')),
                              DataColumn(label: Text('Kecamatan')),
                              DataColumn(label: Text('Surveyor')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: filtered.map((tree) => _buildRow(tree)).toList(),
                          ),
                        ),
                      );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: all.isEmpty ? null : () => _showExportDialog(all, filtered),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Export Excel'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: tableOrEmpty),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(List<TreeData> allTrees, List<TreeData> filteredTrees) {
    String scope = 'filtered'; // 'all' | 'filtered' | 'pilih'
    final selectedIds = <String>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Data ke Excel'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Semua Data (${allTrees.length})'),
                        value: 'all',
                        groupValue: scope,
                        onChanged: (v) => setDialogState(() => scope = v!),
                      ),
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Sesuai Filter Saat Ini (${filteredTrees.length})'),
                        value: 'filtered',
                        groupValue: scope,
                        onChanged: (v) => setDialogState(() => scope = v!),
                      ),
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pilih Data Tertentu'),
                        value: 'pilih',
                        groupValue: scope,
                        onChanged: (v) => setDialogState(() => scope = v!),
                      ),
                      if (scope == 'pilih') ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${selectedIds.length} dipilih', style: const TextStyle(fontSize: 12)),
                            TextButton(
                              onPressed: () => setDialogState(() {
                                if (selectedIds.length == filteredTrees.length) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds
                                    ..clear()
                                    ..addAll(filteredTrees.map((t) => t.id));
                                }
                              }),
                              child: Text(
                                selectedIds.length == filteredTrees.length ? 'Batal Semua' : 'Pilih Semua',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            itemCount: filteredTrees.length,
                            itemBuilder: (context, i) {
                              final t = filteredTrees[i];
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  t.species,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('${t.species} • ${t.kecamatan}', style: const TextStyle(fontSize: 11)),
                                value: selectedIds.contains(t.id),
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    selectedIds.add(t.id);
                                  } else {
                                    selectedIds.remove(t.id);
                                  }
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final dataToExport = switch (scope) {
                      'all' => allTrees,
                      'pilih' => filteredTrees.where((t) => selectedIds.contains(t.id)).toList(),
                      _ => filteredTrees,
                    };
                    if (dataToExport.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
                      );
                      return;
                    }
                    final bytes = buildTreeExcelBytes(dataToExport);
                    final filename =
                        'data_pohon_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx';
                    downloadBytesAsFile(
                      bytes,
                      filename,
                      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${dataToExport.length} data berhasil diekspor.')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DataRow _buildRow(TreeData tree) {
    final isVerified = tree.status == TreeStatus.verified;
    final conditionColor = treeConditionColor(tree.condition);
    return DataRow(
      cells: [
        DataCell(
          GestureDetector(
            onTap: () => _showTreeDetailDialog(context, tree),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _decodeBase64(tree.photoBase64) == null
                  ? Container(
                      width: 44,
                      height: 44,
                      color: Colors.black12,
                      child: const Icon(Icons.image_not_supported_outlined, size: 18, color: Colors.black38),
                    )
                  : Image.memory(
                      _decodeBase64(tree.photoBase64)!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 44,
                        height: 44,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined, size: 18, color: Colors.black38),
                      ),
                    ),
            ),
          ),
        ),
        DataCell(Text(tree.species)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: conditionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tree.condition.label,
              style: TextStyle(color: conditionColor, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        DataCell(Text(tree.kecamatan.isEmpty ? '-' : tree.kecamatan)),
        DataCell(Text(tree.surveyorName)),
        DataCell(Text(_formatDate(tree.timestamp))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isVerified ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isVerified ? 'Terverifikasi' : 'Menunggu',
              style: TextStyle(
                color: isVerified ? Colors.green[800] : Colors.orange[800],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: isVerified,
                onChanged: (value) async {
                  final newStatus = value ? TreeStatus.verified : TreeStatus.pending;
                  final error = await widget.treeService.setTreeStatus(tree.id, newStatus);
                  if (error != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit data',
                onPressed: () => _showEditDialog(tree),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                tooltip: 'Hapus data',
                onPressed: () => _showDeleteConfirm(tree),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Untuk data legacy / titik yang tidak sempat disurvei via HP.
  // Foto & GPS otomatis sengaja tidak disertakan di sini (admin tidak
  // di lapangan) — koordinat diisi manual. Status langsung "verified"
  // karena yang menambahkan adalah admin sendiri.
  void showAddTreeDialog() {
    final kelurahanController = TextEditingController();
    final namaJalanController = TextEditingController();
    final customSpeciesController = TextEditingController();
    final customKecamatanController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final keteranganController = TextEditingController();

    String? selectedSpecies;
    String? selectedKecamatan;
    TreeCondition condition = TreeCondition.sehat;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsKeterangan =
                condition == TreeCondition.sakit || condition == TreeCondition.rawanTumbang;
            return AlertDialog(
              title: const Text('Tambah Data Pohon (Manual)'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedSpecies,
                        decoration: const InputDecoration(labelText: 'Jenis Pohon'),
                        hint: const Text('Pilih jenis pohon'),
                        items: speciesOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setDialogState(() => selectedSpecies = v),
                      ),
                      if (selectedSpecies == 'Lainnya') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customSpeciesController,
                          decoration: const InputDecoration(labelText: 'Sebutkan jenis pohon'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TreeCondition>(
                        value: condition,
                        decoration: const InputDecoration(labelText: 'Kondisi Pohon'),
                        items: TreeCondition.values
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => condition = v ?? condition),
                      ),
                      if (needsKeterangan) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: keteranganController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Keterangan Kondisi *'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedKecamatan,
                        decoration: const InputDecoration(labelText: 'Kecamatan'),
                        hint: const Text('Pilih kecamatan'),
                        items: kecamatanOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (v) => setDialogState(() => selectedKecamatan = v),
                      ),
                      if (selectedKecamatan == 'Lainnya') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customKecamatanController,
                          decoration: const InputDecoration(labelText: 'Sebutkan kecamatan'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: kelurahanController,
                        decoration: const InputDecoration(labelText: 'Kelurahan (opsional)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: namaJalanController,
                        decoration: const InputDecoration(labelText: 'Nama Jalan'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: 'Latitude'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: 'Longitude'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final effectiveSpecies = selectedSpecies == 'Lainnya'
                              ? customSpeciesController.text.trim()
                              : (selectedSpecies ?? '');
                          final effectiveKecamatan = selectedKecamatan == 'Lainnya'
                              ? customKecamatanController.text.trim()
                              : (selectedKecamatan ?? '');
                          final lat = double.tryParse(latController.text.trim());
                          final lng = double.tryParse(lngController.text.trim());

                          if (effectiveSpecies.isEmpty ||
                              effectiveKecamatan.isEmpty ||
                              namaJalanController.text.trim().isEmpty ||
                              lat == null ||
                              lng == null ||
                              (needsKeterangan && keteranganController.text.trim().isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lengkapi semua field wajib (termasuk Latitude/Longitude yang valid).'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          final tree = TreeData(
                            id: '',
                            latitude: lat,
                            longitude: lng,
                            photoBase64: '',
                            surveyorId: widget.adminUser.uid,
                            surveyorName: 'Admin: ${widget.adminUser.name}',
                            species: effectiveSpecies,
                            kecamatan: effectiveKecamatan,
                            kelurahan: kelurahanController.text.trim(),
                            namaJalan: namaJalanController.text.trim(),
                            condition: condition,
                            keteranganKondisi: needsKeterangan ? keteranganController.text.trim() : '',
                            timestamp: DateTime.now(),
                            status: TreeStatus.verified,
                          );

                          final error = await widget.treeService.createTree(tree);
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);

                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data pohon ditambahkan.'), backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(TreeData tree) {
    final kelurahanController = TextEditingController(text: tree.kelurahan);
    final namaJalanController = TextEditingController(text: tree.namaJalan);
    final customSpeciesController = TextEditingController(
      text: speciesOptions.contains(tree.species) ? '' : tree.species,
    );
    final customKecamatanController = TextEditingController(
      text: kecamatanOptions.contains(tree.kecamatan) ? '' : tree.kecamatan,
    );
    final keteranganController = TextEditingController(text: tree.keteranganKondisi);

    String selectedSpecies = speciesOptions.contains(tree.species) ? tree.species : 'Lainnya';
    String selectedKecamatan =
        kecamatanOptions.contains(tree.kecamatan) ? tree.kecamatan : 'Lainnya';
    TreeCondition condition = tree.condition;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Data Pohon'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedSpecies,
                        decoration: const InputDecoration(labelText: 'Jenis Pohon'),
                        items: speciesOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedSpecies = v ?? selectedSpecies),
                      ),
                      if (selectedSpecies == 'Lainnya') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customSpeciesController,
                          decoration: const InputDecoration(labelText: 'Sebutkan jenis pohon'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TreeCondition>(
                        value: condition,
                        decoration: const InputDecoration(labelText: 'Kondisi Pohon'),
                        items: TreeCondition.values
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => condition = v ?? condition),
                      ),
                      if (condition == TreeCondition.sakit || condition == TreeCondition.rawanTumbang) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: keteranganController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Keterangan Kondisi *'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedKecamatan,
                        decoration: const InputDecoration(labelText: 'Kecamatan'),
                        items: kecamatanOptions
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedKecamatan = v ?? selectedKecamatan),
                      ),
                      if (selectedKecamatan == 'Lainnya') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customKecamatanController,
                          decoration: const InputDecoration(labelText: 'Sebutkan kecamatan'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: kelurahanController,
                        decoration: const InputDecoration(labelText: 'Kelurahan'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: namaJalanController,
                        decoration: const InputDecoration(labelText: 'Nama Jalan'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final needsKeterangan = condition == TreeCondition.sakit ||
                              condition == TreeCondition.rawanTumbang;
                          if (needsKeterangan && keteranganController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Keterangan kondisi wajib diisi untuk pohon yang sakit atau rawan tumbang.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final effectiveSpecies = selectedSpecies == 'Lainnya'
                              ? customSpeciesController.text.trim()
                              : selectedSpecies;
                          final effectiveKecamatan = selectedKecamatan == 'Lainnya'
                              ? customKecamatanController.text.trim()
                              : selectedKecamatan;

                          final updated = tree.copyWith(
                            species: effectiveSpecies.isEmpty ? tree.species : effectiveSpecies,
                            kecamatan: effectiveKecamatan.isEmpty ? tree.kecamatan : effectiveKecamatan,
                            kelurahan: kelurahanController.text.trim(),
                            namaJalan: namaJalanController.text.trim(),
                            condition: condition,
                            keteranganKondisi: needsKeterangan ? keteranganController.text.trim() : '',
                          );

                          final error = await widget.treeService.updateTree(updated);
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);

                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data pohon diperbarui.'), backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirm(TreeData tree) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Data Pohon?'),
          content: Text(
            'Data "${tree.species}" akan dihapus permanen. '
            'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final error = await widget.treeService.deleteTree(tree.id);
                if (!mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data pohon dihapus.')),
                  );
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  final _StatusFilter selected;
  final ValueChanged<_StatusFilter> onSelected;

  const _StatusFilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Semua'),
          selected: selected == _StatusFilter.semua,
          onSelected: (_) => onSelected(_StatusFilter.semua),
        ),
        ChoiceChip(
          label: const Text('Menunggu'),
          selected: selected == _StatusFilter.menunggu,
          onSelected: (_) => onSelected(_StatusFilter.menunggu),
        ),
        ChoiceChip(
          label: const Text('Terverifikasi'),
          selected: selected == _StatusFilter.terverifikasi,
          onSelected: (_) => onSelected(_StatusFilter.terverifikasi),
        ),
      ],
    );
  }
}

// ==================== PERMOHONAN PERAPIHAN POHON ====================

enum _PruningFilter { semua, menunggu, diverifikasi, diproses, selesai, ditolak }

class _PruningRequestSection extends StatefulWidget {
  const _PruningRequestSection();

  @override
  State<_PruningRequestSection> createState() => _PruningRequestSectionState();
}

class _PruningRequestSectionState extends State<_PruningRequestSection> {
  final _service = PruningRequestService();
  _PruningFilter _filter = _PruningFilter.semua;

  String _formatDateShort(DateTime date) {
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  Color _statusColor(PruningStatus status) {
    switch (status) {
      case PruningStatus.menunggu:
        return Colors.orange;
      case PruningStatus.diverifikasi:
        return Colors.blue;
      case PruningStatus.diproses:
        return Colors.purple;
      case PruningStatus.selesai:
        return Colors.green;
      case PruningStatus.ditolak:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _PruningFilter.values)
                ChoiceChip(
                  label: Text(switch (f) {
                    _PruningFilter.semua => 'Semua',
                    _PruningFilter.menunggu => 'Menunggu',
                    _PruningFilter.diverifikasi => 'Diverifikasi',
                    _PruningFilter.diproses => 'Diproses',
                    _PruningFilter.selesai => 'Selesai',
                    _PruningFilter.ditolak => 'Ditolak',
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<TreePruningRequest>>(
              stream: _service.streamRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                final filtered = _filter == _PruningFilter.semua
                    ? all
                    : all.where((r) {
                        return switch (_filter) {
                          _PruningFilter.menunggu => r.status == PruningStatus.menunggu,
                          _PruningFilter.diverifikasi => r.status == PruningStatus.diverifikasi,
                          _PruningFilter.diproses => r.status == PruningStatus.diproses,
                          _PruningFilter.selesai => r.status == PruningStatus.selesai,
                          _PruningFilter.ditolak => r.status == PruningStatus.ditolak,
                          _PruningFilter.semua => true,
                        };
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'Belum ada permohonan perapihan pohon yang masuk.'
                          : 'Tidak ada permohonan dengan status ini.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('No. Permohonan')),
                        DataColumn(label: Text('Nama Pemohon')),
                        DataColumn(label: Text('Lokasi Pohon')),
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Aksi')),
                      ],
                      rows: filtered.map((r) {
                        final color = _statusColor(r.status);
                        return DataRow(cells: [
                          DataCell(Text(r.requestNumber)),
                          DataCell(Text(r.namaPemohon)),
                          DataCell(SizedBox(
                            width: 220,
                            child: Text(r.alamatPohon, overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text(_formatDateShort(r.createdAt))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                r.status.label,
                                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            TextButton(
                              onPressed: () => _showDetailDialog(r),
                              child: const Text('Detail'),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(TreePruningRequest request) {
    PruningStatus selectedStatus = request.status;
    final alasanPenolakanController = TextEditingController(text: request.alasanPenolakan);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(request.requestNumber),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATA PEMOHON', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      _DetailRow(label: 'Nama', value: request.namaPemohon),
                      _DetailRow(label: 'Alamat', value: request.alamatPemohon),
                      _DetailRow(label: 'No HP', value: request.nomorHp),
                      _DetailRow(label: 'Email', value: request.emailPemohon),
                      _DetailRow(label: 'NIK', value: request.nik),
                      const SizedBox(height: 12),
                      const Text('DATA POHON', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      _DetailRow(label: 'Alamat Pohon', value: request.alamatPohon),
                      _DetailRow(label: 'Kecamatan', value: request.kecamatan.isEmpty ? '-' : request.kecamatan),
                      _DetailRow(label: 'Kelurahan', value: request.kelurahan.isEmpty ? '-' : request.kelurahan),
                      _DetailRow(label: 'Alasan', value: request.alasan),
                      _DetailRow(
                        label: 'Lokasi GPS',
                        value: request.hasLocation
                            ? '${request.latitude!.toStringAsFixed(5)}, ${request.longitude!.toStringAsFixed(5)}'
                            : 'Tidak tersedia (diisi manual via alamat)',
                      ),
                      const SizedBox(height: 12),
                      const Text('FOTO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _RequestPhoto(
                              label: 'Foto Pohon',
                              base64: request.fotoPohonBase64,
                              downloadFileBaseName: 'FotoPohon_${request.requestNumber}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RequestPhoto(
                              label: 'Foto KTP',
                              base64: request.fotoKtpBase64,
                              downloadFileBaseName: 'FotoKTP_${request.requestNumber}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<PruningStatus>(
                        value: selectedStatus,
                        decoration: const InputDecoration(isDense: true),
                        items: PruningStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                      ),
                      if (selectedStatus == PruningStatus.ditolak) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: alasanPenolakanController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Alasan Penolakan', isDense: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    final bytes = buildSuratPermohonanDocx(request);
                    final filename = 'Surat_Permohonan_${request.requestNumber}.docx';
                    downloadBytesAsFile(
                      bytes,
                      filename,
                      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Export Word'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final error = await _service.updateStatus(
                            request.id,
                            selectedStatus,
                            alasanPenolakan: selectedStatus == PruningStatus.ditolak
                                ? alasanPenolakanController.text.trim()
                                : '',
                          );
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Status permohonan diperbarui.')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RequestPhoto extends StatelessWidget {
  final String label;
  final String base64;
  final String downloadFileBaseName;
  const _RequestPhoto({required this.label, required this.base64, required this.downloadFileBaseName});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBase64(base64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: bytes == null
              ? Container(
                  height: 100,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38),
                )
              : Image.memory(bytes, height: 100, width: double.infinity, fit: BoxFit.cover),
        ),
        if (bytes != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final format = guessImageFormat(bytes);
                downloadBytesAsFile(
                  bytes,
                  '$downloadFileBaseName.${format.extension}',
                  mimeType: format.mimeType,
                );
              },
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Download', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
        ],
      ],
    );
  }
}