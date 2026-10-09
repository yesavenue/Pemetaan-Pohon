import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../widgets/civic_design.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/tree_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/device_location.dart';
import '../../utils/map_point_groups.dart';
import '../../widgets/surveyor/tree_badges.dart';
import '../../utils/cirebon_boundary.dart';
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
  final VoidCallback? onAddTree;

  const TreeBrowser({
    super.key,
    required this.trees,
    required this.onOpenTree,
    this.onAddTree,
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
  final _mapScaffoldKey = GlobalKey<ScaffoldState>();
  double _panelFraction = .44;
  Timer? _edgeTimer;
  Timer? _closeTimer;
  bool _hoverOpened = false;
  late final ScrollController _listController;
  TreeCondition? _condition;
  String _search = '';
  String? _selectedId;
  LatLng? _userLocation;
  bool _ready = false;
  double _zoomLevel = 13;
  bool _locating = false;
  bool _tileError = false;
  int _tileVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.mouseTracker.addListener(_onPointerChanged);
    final memory = widget.memory;
    _searchController.text = memory?.searchText ?? '';
    _search = _searchController.text.trim().toLowerCase();
    _condition = memory?.condition;
    _selectedId = widget.initialTreeId ?? memory?.selectedId;
    _zoomLevel = memory?.mapZoom ?? (widget.initialTreeId == null ? 13 : 17);
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

  void _onPointerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.mouseTracker.removeListener(_onPointerChanged);
    _edgeTimer?.cancel();
    _closeTimer?.cancel();
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
    if (_listController.hasClients) {
      _listController.jumpTo(0);
    }
    widget.memory?.scrollOffset = 0;
    setState(() {
      _search = '';
      _condition = null;
    });
  }

  @override
  Widget build(BuildContext context) => _content();

  Widget _content() {
    final filtered = widget.trees
        .where(
          (tree) =>
              (_condition == null || tree.condition == _condition) &&
              '${tree.species} ${tree.namaJalan} ${tree.kecamatan} ${tree.kelurahan} ${tree.ranahKewenangan}'
                  .toLowerCase()
                  .contains(_search),
        )
        .toList();
    final selected = filtered
        .where((tree) => tree.id == _selectedId)
        .firstOrNull;
    final points = filtered.where(_hasCoordinates).toList();
    final initial = widget.trees
        .where(
          (tree) => tree.id == widget.initialTreeId && _hasCoordinates(tree),
        )
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            widget.mapMode &&
            constraints.maxWidth >= 1000 &&
            constraints.maxHeight >= 420 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        if (widget.mapMode) {
          return _mapWorkspace(
            constraints,
            filtered,
            points,
            initial,
            selected,
            wide,
          );
        }
        final results = filtered.isEmpty
            ? _emptyState()
            : ListView.separated(
                controller: _listController,
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final tree = filtered[index];
                  return Material(
                    color: tree.id == _selectedId
                        ? AppColors.leaf.withValues(alpha: .08)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: tree.id == _selectedId
                            ? AppColors.leaf
                            : const Color(0xFFE3EAE7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _row(tree, selectOnMap: widget.mapMode),
                  );
                },
              );
        return ColoredBox(
          color: const Color(0xFFF3F6F5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Inventaris pohon Anda',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari pohon, lokasi, kewenangan…',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('Semua', null),
                      ...TreeCondition.values.map((c) => _chip(c.label, c)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${filtered.length} pohon ditemukan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                Expanded(child: results),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectTree(TreeData tree) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedId = tree.id);
  }

  void _focusTree(TreeData tree) {
    if (_ready && _hasCoordinates(tree)) {
      _mapController.move(LatLng(tree.latitude, tree.longitude), 17);
    }
  }

  void _openResults({bool hover = false}) {
    _edgeTimer?.cancel();
    _closeTimer?.cancel();
    if (_mapScaffoldKey.currentState?.isDrawerOpen ?? false) {
      return;
    }
    _hoverOpened = hover;
    FocusScope.of(context).unfocus();
    _mapScaffoldKey.currentState?.openDrawer();
  }

  Widget _mapWorkspace(
    BoxConstraints box,
    List<TreeData> filtered,
    List<TreeData> points,
    TreeData? initial,
    TreeData? selected,
    bool wide,
  ) {
    final compact = box.maxWidth < 600 || box.maxHeight < 420;

    return Scaffold(
      key: _mapScaffoldKey,
      drawerEnableOpenDragGesture: false,
      onDrawerChanged: (open) {
        if (!open) {
          _hoverOpened = false;
          _edgeTimer?.cancel();
          _closeTimer?.cancel();
        }
      },
      drawer: MouseRegion(
        onEnter: (_) => _closeTimer?.cancel(),
        onExit: (_) {
          if (_hoverOpened) {
            _closeTimer?.cancel();
            _closeTimer = Timer(const Duration(milliseconds: 350), () {
              if (mounted && _hoverOpened) {
                _mapScaffoldKey.currentState?.closeDrawer();
              }
            });
          }
        },
        child: Drawer(
          width: (box.maxWidth * .92).clamp(0.0, 360.0).toDouble(),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hasil survei Anda',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup daftar',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _mapScaffoldKey.currentState?.closeDrawer(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${filtered.length} hasil sesuai pencarian'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? SingleChildScrollView(child: _emptyState())
                      : ListView.builder(
                          controller: _listController,
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) =>
                              _resultCard(filtered[index]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _map(points, initial)),
          Positioned(
            top: 8,
            left: 8,
            right: 72,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (box.maxWidth < 600 ||
                                !WidgetsBinding
                                    .instance
                                    .mouseTracker
                                    .mouseIsConnected)
                              IconButton(
                                tooltip: 'Buka hasil survei',
                                onPressed: _openResults,
                                icon: const Icon(
                                  Icons.format_list_bulleted_rounded,
                                ),
                              ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: compact
                                      ? 'Cari pohon…'
                                      : 'Cari pohon, lokasi, kewenangan…',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (value) => setState(
                                  () => _search = value.trim().toLowerCase(),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Filter kondisi',
                              onPressed: _showFilters,
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ],
                        ),
                        if (!compact)
                          Text(
                            '${points.length} titik • ${_condition?.label ?? 'Semua kondisi'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.navy,
                            ),
                          ),
                        if (_tileError)
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Peta gagal dimuat',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Muat ulang',
                                icon: const Icon(Icons.refresh),
                                onPressed: () => setState(() {
                                  _tileError = false;
                                  _tileVersion++;
                                }),
                              ),
                            ],
                          ),
                        const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: MouseRegion(
              onEnter: (event) {
                if (event.kind != PointerDeviceKind.mouse) {
                  return;
                }
                _edgeTimer?.cancel();
                _edgeTimer = Timer(const Duration(milliseconds: 280), () {
                  if (mounted) {
                    _openResults(hover: true);
                  }
                });
              },
              onExit: (_) => _edgeTimer?.cancel(),
              child: const SizedBox.expand(),
            ),
          ),
          if (points.isEmpty && selected == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: box.maxHeight * .45,
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: _emptyState(
                        invalidCoordinates: filtered.isNotEmpty,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (selected != null && wide)
            Positioned(
              top: 110,
              right: 64,
              bottom: 12,
              width: 330,
              child: _selectionPanel(selected, box.maxHeight, desktop: true),
            ),
          if (selected != null && !wide)
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: (box.maxHeight * _panelFraction)
                    .clamp(
                      box.maxHeight < 160 ? box.maxHeight : 96.0,
                      box.maxHeight,
                    )
                    .toDouble(),
                child: _selectionPanel(selected, box.maxHeight, desktop: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(TreeData tree) => Card(
    clipBehavior: Clip.antiAlias,
    color: tree.id == _selectedId ? const Color(0xFFE6F2EB) : Colors.white,
    child: InkWell(
      onTap: () {
        _selectTree(tree);
        _mapScaffoldKey.currentState?.closeDrawer();
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (_, constraints) => TreeThumbnail(
                base64: tree.photoBase64,
                size: constraints.maxWidth,
                height: 120,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tree.species,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${tree.namaJalan}, ${tree.kecamatan}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            TreeBadges(tree: tree),
            const SizedBox(height: 8),
            Text(
              tree.ranahKewenangan.isEmpty
                  ? 'Kewenangan belum diketahui'
                  : tree.ranahKewenangan,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _selectionPanel(
    TreeData tree,
    double availableHeight, {
    required bool desktop,
  }) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final headerHeight = (52 + (scale - 1) * 22).clamp(52.0, 84.0).toDouble();
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: desktop
                ? null
                : (details) => setState(() {
                    _panelFraction =
                        (_panelFraction - details.delta.dy / availableHeight)
                            .clamp(.3, .86)
                            .toDouble();
                  }),
            child: SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: tree.species,
                        child: Text(
                          tree.species,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    if (!desktop)
                      IconButton(
                        tooltip: 'Perluas atau ringkas panel',
                        onPressed: () => setState(
                          () =>
                              _panelFraction = _panelFraction > .6 ? .44 : .86,
                        ),
                        icon: const Icon(Icons.unfold_more_rounded),
                      ),
                    IconButton(
                      tooltip: 'Tutup pilihan',
                      onPressed: () => setState(() => _selectedId = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              key: ValueKey('detail-${tree.id}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                TreeBadges(tree: tree),
                const SizedBox(height: 12),
                Text('${tree.namaJalan}, ${tree.kecamatan}'),
                const SizedBox(height: 8),
                Text(
                  'Kewenangan: ${tree.ranahKewenangan.isEmpty ? 'Belum diketahui' : tree.ranahKewenangan}',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => widget.onOpenTree(tree),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Buka detail'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _hasCoordinates(tree)
                      ? () => _focusTree(tree)
                      : null,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Fokuskan lokasi'),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (_, constraints) => TreeThumbnail(
                    base64: tree.photoBase64,
                    size: constraints.maxWidth,
                    height: 160,
                  ),
                ),
                const SizedBox(height: 12),
                Text(tree.keteranganKondisi),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Filter pohon',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final condition in <TreeCondition?>[
                  null,
                  ...TreeCondition.values,
                ])
                  ListTile(
                    leading: condition == null
                        ? const Icon(Icons.layers_outlined)
                        : TreeSilhouette(
                            color: treeConditionColor(condition),
                            size: 24,
                          ),
                    title: Text(condition?.label ?? 'Semua kondisi'),
                    trailing: _condition == condition
                        ? const Icon(Icons.check, color: AppColors.leaf)
                        : null,
                    onTap: () {
                      setState(() {
                        _condition = condition;
                        _selectedId = null;
                      });
                      Navigator.pop(sheetContext);
                    },
                  ),
                TextButton(
                  onPressed: () {
                    _resetFilters();
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Hapus pencarian dan filter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cluster(List<TreeData> members) => Tooltip(
    message: '${members.length} pohon berdekatan',
    child: FilledButton(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        backgroundColor: AppColors.navy,
      ),
      onPressed: () async {
        if (!_ready) {
          return;
        }
        if (_zoomLevel < 18) {
          _mapController.move(
            LatLng(members.first.latitude, members.first.longitude),
            (_zoomLevel + 2).clamp(3, 19).toDouble(),
          );
          return;
        }
        final chosen = await showModalBottomSheet<TreeData>(
          context: context,
          builder: (_) => SafeArea(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Pohon berdekatan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final tree in members)
                  ListTile(
                    title: Text(tree.species),
                    subtitle: Text(
                      '${tree.condition.label} • ${tree.namaJalan}',
                    ),
                    onTap: () => Navigator.pop(context, tree),
                  ),
              ],
            ),
          ),
        );
        if (chosen != null && mounted) {
          _selectTree(chosen);
        }
      },
      child: Text(
        '${members.length}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

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
          onPositionChanged: (camera, _) {
            if (camera.zoom.floor() != _zoomLevel.floor()) {
              setState(() => _zoomLevel = camera.zoom);
            }
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
          PolygonLayer(
            polygons: [
              Polygon(
                points: cirebonBoundaryPolygon
                    .map((p) => LatLng(p[1], p[0]))
                    .toList(),
                color: AppColors.leaf.withValues(alpha: .06),
                borderColor: AppColors.leaf.withValues(alpha: .5),
                borderStrokeWidth: 2,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              ...groupMapPoints([
                for (final tree in trees)
                  (latitude: tree.latitude, longitude: tree.longitude),
              ], _zoomLevel).map((indices) {
                final tree = trees[indices.first];
                if (indices.length > 1) {
                  return Marker(
                    point: LatLng(tree.latitude, tree.longitude),
                    width: 52,
                    height: 52,
                    child: _cluster([for (final i in indices) trees[i]]),
                  );
                }
                return Marker(
                  point: LatLng(tree.latitude, tree.longitude),
                  width: 56,
                  height: 56,
                  child: Semantics(
                    button: true,
                    selected: tree.id == _selectedId,
                    label: '${tree.species}, ${tree.condition.label}',
                    child: Tooltip(
                      message: '${tree.species} • ${tree.condition.label}',
                      child: IconButton(
                        iconSize: 56,
                        padding: EdgeInsets.zero,
                        onPressed: () => _selectTree(tree),
                        icon: AnimatedContainer(
                          duration: Duration(
                            milliseconds:
                                MediaQuery.of(context).disableAnimations
                                ? 0
                                : 180,
                          ),
                          margin: EdgeInsets.all(
                            tree.id == _selectedId ? 2 : 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tree.id == _selectedId
                                  ? AppColors.navy
                                  : treeConditionColor(tree.condition),
                              width: tree.id == _selectedId ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(7),
                          child: TreeSilhouette(
                            color: treeConditionColor(tree.condition),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
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

  Widget _emptyState({bool invalidCoordinates = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TreeSilhouette(color: AppColors.leaf, size: 32),
          const SizedBox(height: 12),
          Text(
            invalidCoordinates
                ? 'Koordinat perlu diperiksa'
                : widget.trees.isEmpty
                ? 'Mulai survei pertama Anda'
                : 'Tidak ada hasil yang cocok',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            invalidCoordinates
                ? 'Buka data pohon untuk memeriksa lokasinya.'
                : widget.trees.isEmpty
                ? 'Pohon yang Anda input akan muncul di sini.'
                : 'Coba kata pencarian atau kondisi lainnya.',
            textAlign: TextAlign.center,
          ),
          if (_search.isNotEmpty || _condition != null)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset filter'),
            ),
          if (widget.trees.isEmpty && widget.onAddTree != null)
            FilledButton.icon(
              onPressed: widget.onAddTree,
              icon: const Icon(Icons.add),
              label: const Text('Input pohon'),
            ),
        ],
      ),
    ),
  );

  Widget _chip(String label, TreeCondition? condition) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      avatar: condition == null
          ? const Icon(Icons.layers_outlined, size: 18)
          : TreeSilhouette(color: treeConditionColor(condition), size: 18),
      label: Text(
        '$label · ${condition == null ? widget.trees.length : widget.trees.where((tree) => tree.condition == condition).length}',
      ),
      selected: _condition == condition,
      selectedColor: AppColors.leaf.withValues(alpha: .15),
      onSelected: (_) => setState(() {
        _condition = condition;
        _selectedId = null;
      }),
    ),
  );

  Widget _row(TreeData tree, {bool selectOnMap = false}) => InkWell(
    onTap: () => selectOnMap ? _selectTree(tree) : widget.onOpenTree(tree),
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
                const SizedBox(height: 8),
                TreeBadges(tree: tree),
                const SizedBox(height: 6),
                if (tree.ranahKewenangan.trim().isNotEmpty)
                  Text(
                    tree.ranahKewenangan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
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
          if (!selectOnMap)
            const Tooltip(
              message: 'Buka detail pohon',
              child: Icon(Icons.arrow_forward_rounded, color: AppColors.leaf),
            )
          else
            Icon(
              tree.id == _selectedId
                  ? Icons.radio_button_checked
                  : Icons.chevron_right,
              color: AppColors.leaf,
            ),
        ],
      ),
    ),
  );
}
