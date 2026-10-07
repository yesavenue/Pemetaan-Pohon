import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/tree_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/device_location.dart';
import '../../utils/tree_condition_style.dart';
import '../../widgets/surveyor/tree_thumbnail.dart';

/// State UI selama sesi dashboard; tidak disimpan ke Firebase atau disk.
/// Daftar dan peta memakai instance terpisah milik shell surveyor.
class TreeBrowserMemory {
  String searchText = '';
  TreeCondition? condition;
  String? selectedId;
  double scrollOffset = 0;
  LatLng? mapCenter;
  double? mapZoom;
}

class TreeBrowser extends StatefulWidget {
  final List<TreeData> trees;
  final bool mapMode;
  final String? initialTreeId;
  final TreeBrowserMemory? memory;
  final ValueChanged<TreeData> onOpenTree;

  const TreeBrowser({
    super.key,
    required this.trees,
    required this.onOpenTree,
    this.mapMode = false,
    this.initialTreeId,
    this.memory,
  });

  @override
  State<TreeBrowser> createState() => _TreeBrowserState();
}

class _TreeBrowserState extends State<TreeBrowser> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  late final ScrollController _listController;
  TreeCondition? _condition;
  String _search = '';
  String? _selectedId;
  LatLng? _userLocation;
  bool _ready = false;
  bool _locating = false;
  bool _tileError = false;
  int _tileVersion = 0;

  @override
  void initState() {
    super.initState();
    final memory = widget.memory;
    _searchController.text = memory?.searchText ?? '';
    _search = _searchController.text.trim().toLowerCase();
    _condition = memory?.condition;
    _selectedId = widget.initialTreeId ?? memory?.selectedId;
    _listController = ScrollController(
      initialScrollOffset: memory?.scrollOffset ?? 0,
    );
  }

  @override
  void deactivate() {
    // Ambil posisi sebelum descendant melepas controller saat pindah tab.
    final memory = widget.memory;
    if (memory != null) {
      memory.searchText = _searchController.text;
      memory.condition = _condition;
      memory.selectedId = _selectedId;
      if (_listController.hasClients) {
        memory.scrollOffset = _listController.offset;
      }
      if (widget.mapMode && _ready) {
        memory.mapCenter = _mapController.camera.center;
        memory.mapZoom = _mapController.camera.zoom;
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool _hasCoordinates(TreeData tree) =>
      tree.latitude.isFinite &&
      tree.longitude.isFinite &&
      tree.latitude >= -90 &&
      tree.latitude <= 90 &&
      tree.longitude >= -180 &&
      tree.longitude <= 180;

  void _zoom(double delta) {
    if (!_ready) {
      return;
    }
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(3.0, 19.0).toDouble(),
    );
  }

  Future<void> _locate() async {
    if (_locating || !_ready) {
      return;
    }
    setState(() => _locating = true);
    try {
      final point = await readDeviceLocation();
      if (!mounted) {
        return;
      }
      setState(() => _userLocation = point);
      if (_ready) {
        _mapController.move(point, 17);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _markTileError() {
    if (_tileError) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) {
        setState(() => _tileError = true);
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    if (_listController.hasClients) _listController.jumpTo(0);
    widget.memory?.scrollOffset = 0;
    setState(() {
      _search = '';
      _condition = null;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.mapMode && constraints.maxHeight < 420) {
        return SingleChildScrollView(
          child: SizedBox(height: 600, child: _content()),
        );
      }
      return _content();
    },
  );

  Widget _content() {
    final filtered = widget.trees
        .where(
          (tree) =>
              (_condition == null || tree.condition == _condition) &&
              '${tree.species} ${tree.namaJalan} ${tree.kecamatan} ${tree.kelurahan}'
                  .toLowerCase()
                  .contains(_search),
        )
        .toList();
    final selected = filtered
        .where((tree) => tree.id == _selectedId)
        .firstOrNull;
    final validPoints = filtered.where(_hasCoordinates).toList();
    final initial = widget.trees
        .where(
          (tree) => tree.id == widget.initialTreeId && _hasCoordinates(tree),
        )
        .firstOrNull;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama pohon, lokasi...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _chip('Semua', null),
              ...TreeCondition.values.map(
                (condition) => _chip(condition.label, condition),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.mapMode
                  ? '${validPoints.length} pohon di peta'
                  : '${filtered.length} pohon ditemukan',
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
          ),
        ),
        if (widget.mapMode && _tileError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sebagian peta gagal dimuat.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tileError = false;
                    _tileVersion++;
                  }),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.mapMode
              ? _map(validPoints, initial)
              : filtered.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _listController,
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, index) => Card(child: _row(filtered[index])),
                ),
        ),
        if (widget.mapMode && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tidak ada pohon yang sesuai.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_search.isNotEmpty || _condition != null)
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset Filter'),
                  ),
              ],
            ),
          ),
        if (widget.mapMode && selected != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Card(child: _row(selected)),
            ),
          ),
      ],
    );
  }

  Widget _map(List<TreeData> trees, TreeData? initial) => Stack(
    children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              widget.memory?.mapCenter ??
              (initial == null
                  ? const LatLng(-6.7183, 108.5522)
                  : LatLng(initial.latitude, initial.longitude)),
          initialZoom: widget.memory?.mapZoom ?? (initial == null ? 13 : 17),
          minZoom: 3,
          maxZoom: 19,
          onMapReady: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _ready = true);
              }
            });
          },
          onTap: (_, point) => setState(() => _selectedId = null),
        ),
        children: [
          TileLayer(
            key: ValueKey(_tileVersion),
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pemetaanpohon.app',
            errorTileCallback: (_, error, stack) => _markTileError(),
          ),
          MarkerLayer(
            markers: [
              ...trees.map(
                (tree) => Marker(
                  point: LatLng(tree.latitude, tree.longitude),
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: '${tree.species}, ${tree.condition.label}',
                    icon: Icon(
                      Icons.location_on,
                      size: 36,
                      color: treeConditionColor(tree.condition),
                    ),
                    onPressed: () => setState(() => _selectedId = tree.id),
                  ),
                ),
              ),
              if (_userLocation != null)
                Marker(
                  point: _userLocation!,
                  width: 24,
                  height: 24,
                  child: const Tooltip(
                    message: 'Lokasi Anda',
                    child: Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          RichAttributionWidget(
            attributions: [
              const TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      Positioned(
        right: 12,
        top: 12,
        bottom: 24,
        child: SingleChildScrollView(
          child: Card(
            child: Column(
              children: [
                IconButton(
                  tooltip: 'Perbesar',
                  onPressed: _ready ? () => _zoom(1) : null,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Perkecil',
                  onPressed: _ready ? () => _zoom(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Kembali ke Cirebon',
                  onPressed: _ready
                      ? () => _mapController.move(
                          const LatLng(-6.7183, 108.5522),
                          13,
                        )
                      : null,
                  icon: const Icon(Icons.center_focus_strong),
                ),
                IconButton(
                  tooltip: 'Lokasi saya',
                  onPressed: _ready && !_locating ? _locate : null,
                  icon: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 40, color: Colors.blueGrey),
          const SizedBox(height: 12),
          const Text('Tidak ada pohon yang sesuai.'),
          if (_search.isNotEmpty || _condition != null)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset Filter'),
            ),
        ],
      ),
    ),
  );

  Widget _chip(String label, TreeCondition? condition) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _condition == condition,
      selectedColor: AppColors.leaf.withValues(alpha: .15),
      onSelected: (_) => setState(() {
        _condition = condition;
        _selectedId = null;
      }),
    ),
  );

  Widget _row(TreeData tree) => InkWell(
    onTap: () => widget.onOpenTree(tree),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TreeThumbnail(base64: tree.photoBase64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tree.species,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '${tree.namaJalan}, ${tree.kecamatan}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tree.condition.label,
                  style: TextStyle(color: treeConditionColor(tree.condition)),
                ),
                if (!widget.mapMode)
                  Text(
                    '${tree.timestamp.toLocal().day}/${tree.timestamp.toLocal().month}/${tree.timestamp.toLocal().year}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}