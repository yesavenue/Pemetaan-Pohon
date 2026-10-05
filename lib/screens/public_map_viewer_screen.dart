import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../utils/cirebon_regions.dart';
import '../utils/tree_condition_style.dart';
import '../widgets/public_navbar.dart';

// Kumpulan semua kriteria filter peta publik dalam satu objek, supaya
// gampang dibawa masuk-keluar panel modal (edit di panel, baru
// diterapkan ke peta setelah tombol "Terapkan" ditekan).
class _PublicFilters {
  final String? kecamatan;
  final String? kelurahan;
  final String species; // 'Semua' atau nama jenis pohon
  final Set<TreeCondition> conditions; // kosong = tampilkan semua kondisi
  final bool newestFirst;

  const _PublicFilters({
    this.kecamatan,
    this.kelurahan,
    this.species = 'Semua',
    this.conditions = const {},
    this.newestFirst = true,
  });

  int get activeCount {
    int count = 0;
    if (kecamatan != null) count++;
    if (kelurahan != null) count++;
    if (species != 'Semua') count++;
    if (conditions.isNotEmpty) count++;
    return count;
  }

  _PublicFilters copyWith({
    String? kecamatan,
    bool clearKecamatan = false,
    String? kelurahan,
    bool clearKelurahan = false,
    String? species,
    Set<TreeCondition>? conditions,
    bool? newestFirst,
  }) {
    return _PublicFilters(
      kecamatan: clearKecamatan ? null : (kecamatan ?? this.kecamatan),
      kelurahan: clearKelurahan ? null : (kelurahan ?? this.kelurahan),
      species: species ?? this.species,
      conditions: conditions ?? this.conditions,
      newestFirst: newestFirst ?? this.newestFirst,
    );
  }
}

// Halaman ini SENGAJA tidak butuh login sama sekali — jadi halaman
// pertama saat website dibuka. Read-only: tidak ada tombol
// tambah/edit/hapus di mana pun dalam file ini.
class PublicMapViewerScreen extends StatefulWidget {
  const PublicMapViewerScreen({super.key});

  @override
  State<PublicMapViewerScreen> createState() => _PublicMapViewerScreenState();
}

class _PublicMapViewerScreenState extends State<PublicMapViewerScreen> {
  final _treeService = TreeService();
  _PublicFilters _filters = const _PublicFilters();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PublicNavbar(
        currentPage: PublicPage.peta,
        extraActions: [
          Badge(
            label: Text('${_filters.activeCount}'),
            isLabelVisible: _filters.activeCount > 0,
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filter',
              onPressed: () => _openFilterSheet(context),
            ),
          ),
        ],
      ),
      drawer: const PublicNavDrawer(currentPage: PublicPage.peta),
      body: StreamBuilder<List<TreeData>>(
        stream: _treeService.streamTrees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data peta: ${snapshot.error}\n\n'
                  'Jika ini error izin akses, pastikan aturan Firestore '
                  'mengizinkan pembacaan publik pada koleksi "trees".',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allTrees = snapshot.data ?? [];
          // Publik hanya boleh melihat data yang sudah diverifikasi admin.
          final verifiedTrees = allTrees.where((t) => t.status == TreeStatus.verified).toList();

          final filtered = verifiedTrees.where((t) {
            final matchesKecamatan = _filters.kecamatan == null ||
                t.kecamatan.trim().toLowerCase() == _filters.kecamatan!.trim().toLowerCase();
            final matchesKelurahan = _filters.kelurahan == null ||
                t.kelurahan.trim().toLowerCase() == _filters.kelurahan!.trim().toLowerCase();
            final matchesSpecies = _filters.species == 'Semua' ||
                t.species.trim().toLowerCase() == _filters.species.trim().toLowerCase();
            final matchesCondition =
                _filters.conditions.isEmpty || _filters.conditions.contains(t.condition);
            return matchesKecamatan && matchesKelurahan && matchesSpecies && matchesCondition;
          }).toList()
            ..sort((a, b) => _filters.newestFirst
                ? b.timestamp.compareTo(a.timestamp)
                : a.timestamp.compareTo(b.timestamp));

          return Stack(
            children: [
              _PublicTreeMap(trees: filtered),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    '${filtered.length} pohon ditampilkan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 36, color: Colors.black38),
                        const SizedBox(height: 8),
                        Text(
                          verifiedTrees.isEmpty
                              ? 'Belum ada pohon terverifikasi untuk ditampilkan.'
                              : 'Tidak ditemukan pohon yang sesuai dengan kriteria filter yang dipilih.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (verifiedTrees.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => setState(() => _filters = const _PublicFilters()),
                            child: const Text('Reset Filter'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_PublicFilters>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _FilterSheet(initialFilters: _filters, treeService: _treeService),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
  }
}

class _FilterSheet extends StatefulWidget {
  final _PublicFilters initialFilters;
  final TreeService treeService;
  const _FilterSheet({required this.initialFilters, required this.treeService});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _PublicFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return StreamBuilder<List<TreeData>>(
          stream: widget.treeService.streamTrees(),
          builder: (context, snapshot) {
            final trees = (snapshot.data ?? [])
                .where((t) => t.status == TreeStatus.verified)
                .toList();
            final speciesOptions = trees.map((t) => t.species).toSet().toList()..sort();
            final kelurahanOptions = kelurahanFor(_draft.kecamatan);

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter Peta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _sectionLabel('Wilayah'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _draft.kecamatan,
                  decoration: const InputDecoration(labelText: 'Kecamatan', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Kecamatan')),
                    ...cirebonKecamatanList.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                  ],
                  onChanged: (v) => setState(() {
                    _draft = _draft.copyWith(
                      kecamatan: v,
                      clearKecamatan: v == null,
                      clearKelurahan: true,
                    );
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _draft.kelurahan,
                  decoration: const InputDecoration(labelText: 'Kelurahan', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Kelurahan')),
                    ...kelurahanOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                  ],
                  onChanged: _draft.kecamatan == null
                      ? null
                      : (v) => setState(() {
                            _draft = _draft.copyWith(kelurahan: v, clearKelurahan: v == null);
                          }),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Jenis Pohon'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _draft.species,
                  decoration: const InputDecoration(isDense: true),
                  items: ['Semua', ...speciesOptions]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _draft = _draft.copyWith(species: v ?? 'Semua')),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Kondisi'),
                ...TreeCondition.values.map((c) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(c.label),
                    activeColor: treeConditionColor(c),
                    value: _draft.conditions.contains(c),
                    onChanged: (checked) => setState(() {
                      final updated = {..._draft.conditions};
                      if (checked == true) {
                        updated.add(c);
                      } else {
                        updated.remove(c);
                      }
                      _draft = _draft.copyWith(conditions: updated);
                    }),
                  );
                }),
                const SizedBox(height: 12),
                _sectionLabel('Urutan'),
                RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Terbaru'),
                  value: true,
                  groupValue: _draft.newestFirst,
                  onChanged: (v) => setState(() => _draft = _draft.copyWith(newestFirst: true)),
                ),
                RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Terlama'),
                  value: false,
                  groupValue: _draft.newestFirst,
                  onChanged: (v) => setState(() => _draft = _draft.copyWith(newestFirst: false)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _draft = const _PublicFilters()),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _draft),
                        child: const Text('Terapkan'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PublicTreeMap extends StatelessWidget {
  final List<TreeData> trees;
  const _PublicTreeMap({required this.trees});

  static const _defaultCenter = LatLng(-2.5489, 118.0149);
  static const _defaultZoom = 5.0;

  @override
  Widget build(BuildContext context) {
    final center = trees.isEmpty
        ? _defaultCenter
        : LatLng(
            trees.map((t) => t.latitude).reduce((a, b) => a + b) / trees.length,
            trees.map((t) => t.longitude).reduce((a, b) => a + b) / trees.length,
          );

    final treeById = {for (final t in trees) t.id: t};

    return FlutterMap(
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
                  onTap: () => _showDetail(context, tree),
                  child: Icon(Icons.location_on, color: treeConditionColor(tree.condition), size: 32),
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
              return Container(
                decoration: BoxDecoration(
                  color: treeConditionColor(worst),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                ),
                alignment: Alignment.center,
                child: Text('${markers.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, TreeData tree) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tree.species),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_decodeBase64(tree.photoBase64) != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_decodeBase64(tree.photoBase64)!,
                          height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  _row('Jenis Pohon', tree.species),
                  _row('Kondisi', tree.condition.label),
                  if (tree.keteranganKondisi.isNotEmpty)
                    _row('Keterangan', tree.keteranganKondisi),
                  _row('Kecamatan', tree.kecamatan.isEmpty ? '-' : tree.kecamatan),
                  _row('Kelurahan', tree.kelurahan.isEmpty ? '-' : tree.kelurahan),
                  _row('Nama Jalan', tree.namaJalan.isEmpty ? '-' : tree.namaJalan),
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Uint8List? _decodeBase64(String data) {
    if (data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}