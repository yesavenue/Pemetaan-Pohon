import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../utils/cirebon_regions.dart';
import '../utils/device_location.dart';
import '../utils/tree_condition_style.dart';
import '../view_models/public_map_state.dart';
import '../widgets/public_navbar.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/civic_design.dart';
import '../widgets/public/public_visuals.dart';
import '../widgets/surveyor/tree_thumbnail.dart';

class PublicMapViewerScreen extends StatefulWidget {
  final Stream<List<TreeData>>? treeStream;
  final String? initialKecamatan;
  final TreeCondition? initialCondition;
  final String? initialTreeId;
  final PublicMapState? state;
  final Widget Function(PublicMapState, ValueChanged<TreeData>)? mapBuilder;
  final Future<LatLng> Function()? locate;
  final void Function(LatLng, double)? onCameraMove;
  const PublicMapViewerScreen({
    super.key,
    this.treeStream,
    this.initialKecamatan,
    this.initialCondition,
    this.initialTreeId,
    this.state,
    this.mapBuilder,
    this.locate,
    this.onCameraMove,
  });
  @override
  State<PublicMapViewerScreen> createState() => _PublicMapViewerScreenState();
}

class _PublicMapViewerScreenState extends State<PublicMapViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PublicMapState _state;
  final _search = TextEditingController();
  final _map = MapController();
  StreamSubscription<List<TreeData>>? _subscription;
  late final AnimationController _motion;
  LatLng _from = PublicMapState.defaultCenter,
      _to = PublicMapState.defaultCenter;
  double _fromZoom = 13, _toZoom = 13;
  bool _loading = true, _failed = false, _ready = false, _locating = false;
  bool _tileError = false;
  bool _initialSelectionApplied = false;
  int _tileVersion = 0;
  String? _gpsMessage;
  String? _hoveredId;
  String? _focusedId;
  bool _detailExpanded = false;
  bool get _canMove => _ready || widget.mapBuilder != null;
  @override
  void initState() {
    super.initState();
    _state = widget.state ?? PublicMapState();
    if (widget.state == null) {
      _state.setFilters(
        PublicMapFilters(
          kecamatan: widget.initialKecamatan,
          conditions: widget.initialCondition == null
              ? const {}
              : {widget.initialCondition!},
        ),
      );
    }
    _search.text = _state.query;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_tickCamera);
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PublicMapViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeStream != widget.treeStream) _subscribe();
  }

  void _subscribe() {
    _motion.stop();
    _ready = false;
    _subscription?.cancel();
    _loading = true;
    _failed = false;
    _subscription = (widget.treeStream ?? TreeService().streamTrees()).listen(
      (trees) {
        if (!mounted) return;
        _state.setTrees(trees);
        if (!_initialSelectionApplied) {
          _initialSelectionApplied = true;
          final id = widget.initialTreeId;
          if (id != null) {
            _state.select(id);
            final selected = _state.selectedTree;
            if (selected != null && hasPublicMapCoordinates(selected)) {
              _state.center = LatLng(selected.latitude, selected.longitude);
              _state.zoom = 16;
            }
          }
        }
        setState(() {
          _loading = false;
          _failed = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (mounted) {
          _motion.stop();
          _ready = false;
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _motion.dispose();
    _map.dispose();
    _search.dispose();
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  void _tickCamera() {
    if (!_ready) return;
    final t = Curves.easeInOut.transform(_motion.value);
    _map.move(
      LatLng(
        _from.latitude + (_to.latitude - _from.latitude) * t,
        _from.longitude + (_to.longitude - _from.longitude) * t,
      ),
      _fromZoom + (_toZoom - _fromZoom) * t,
    );
  }

  void _move(LatLng target, double zoom) {
    _motion.stop();
    widget.onCameraMove?.call(target, zoom);
    if (!_ready) {
      _state.center = target;
      _state.zoom = zoom;
      return;
    }
    if (MediaQuery.of(context).disableAnimations) {
      _map.move(target, zoom);
      return;
    }
    _from = _map.camera.center;
    _fromZoom = _map.camera.zoom;
    _to = target;
    _toZoom = zoom;
    _motion.forward(from: 0);
  }

  void _select(TreeData tree) {
    if (tree.id != _state.selectedId) {
      setState(() => _detailExpanded = false);
    }
    _state.select(tree.id);
    if (_state.selectedId == tree.id && hasPublicMapCoordinates(tree)) {
      _move(LatLng(tree.latitude, tree.longitude), 17);
    }
  }

  void _resetFilters() {
    _search.clear();
    _state.resetFilters();
  }

  Future<void> _locate() async {
    if (_locating || !_canMove) return;
    setState(() {
      _locating = true;
      _gpsMessage = null;
    });
    try {
      final point = await (widget.locate ?? readDeviceLocation)();
      if (!mounted) return;
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        throw StateError('Koordinat lokasi tidak valid');
      }
      _move(point, 16);
      setState(() => _gpsMessage = 'Peta dipusatkan ke lokasi perangkat.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _gpsMessage =
              'Lokasi belum tersedia. Periksa izin lokasi/GPS lalu coba lagi. Peta tetap dapat digunakan.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<PublicMapFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Theme(
        data: PublicUi.theme(context),
        child: _FilterSheet(
          initialFilters: _state.filters,
          trees: _state.verifiedTrees,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _state.setFilters(result);
  }

  Future<void> _openList() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Theme(
      data: PublicUi.theme(context),
      child: FractionallySizedBox(
        heightFactor: .8,
        child: AnimatedBuilder(
          animation: _state,
          builder: (_, child) => Column(
            children: [
              _sheetHeader(
                sheetContext,
                'Daftar pohon (${_state.visibleTrees.length})',
              ),
              Expanded(
                child: _treeList((tree) {
                  Navigator.pop(sheetContext);
                  _select(tree);
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _sheetHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Tutup',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
  Future<void> _openDetail() {
    final theme = PublicUi.theme(context);
    final size = MediaQuery.sizeOf(context);
    final desktop =
        size.width >= 960 && MediaQuery.textScalerOf(context).scale(14) <= 18.2;
    if (desktop) {
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => Theme(
          data: theme,
          child: Dialog(
            key: const ValueKey('public-map-detail-dialog'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 680,
              height: size.height * .82,
              child: _detailContent(dialogContext),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Theme(
        data: theme,
        child: FractionallySizedBox(
          heightFactor: .85,
          child: _detailContent(sheetContext),
        ),
      ),
    );
  }

  Widget _detailContent(BuildContext routeContext) => AnimatedBuilder(
    animation: _state,
    builder: (_, child) {
      final tree = _state.selectedTree;
      if (tree == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (routeContext.mounted &&
              (ModalRoute.of(routeContext)?.isCurrent ?? false)) {
            Navigator.pop(routeContext);
          }
        });
      }
      return Column(
        children: [
          _sheetHeader(routeContext, 'Detail pohon'),
          const Divider(height: 1, color: PublicUi.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: tree == null
                  ? const Text(
                      'Pohon ini tidak lagi tersedia pada hasil saat ini.',
                    )
                  : _fullDetail(tree),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PublicScaffold(
    currentPage: PublicPage.peta,
    body: AnimatedBuilder(
      animation: _state,
      builder: (_, child) {
        if (_loading) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Memuat peta pohon',
            ),
          );
        }
        if (_failed) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Data pohon belum berhasil dimuat. Periksa koneksi lalu coba lagi.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(_subscribe),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, box) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final wide =
                box.maxWidth >= 960 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18.2 &&
                box.maxHeight >= 400;
            // Accessibility fallback gives the map and its popup enough room.
            if (largeText || box.maxHeight < 420) {
              return ListView(
                children: [
                  _header(showList: true),
                  SizedBox(height: 520, child: _mapArea(wide: false)),
                ],
              );
            }
            return Padding(
              padding: EdgeInsets.all(wide ? 12 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(wide ? 24 : 0),
                child: _mapArea(wide: wide, floatingSearch: !wide),
              ),
            );
          },
        );
      },
    ),
  );

  Widget _header({required bool showList}) => Padding(
    padding: EdgeInsets.all(showList ? 12 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showList) ...[
          const Text(
            'JELAJAHI KOTA',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: PublicUi.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Peta Pohon',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: _state.setQuery,
          decoration: InputDecoration(
            hintText: 'Cari jenis atau lokasi',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Hapus pencarian',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _search.clear();
                _state.setQuery('');
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!showList) ...[
          const Text(
            'Kondisi pohon',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in TreeCondition.values)
                FilterChip(
                  label: Text(c.label),
                  avatar: TreeSilhouette(
                    size: 18,
                    color: treeConditionColor(c),
                  ),
                  selected: _state.filters.conditions.contains(c),
                  onSelected: (_) => _state.toggleCondition(c),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _openFilters,
              icon: const Icon(Icons.tune),
              label: Text('Filter (${_state.filters.activeCount})'),
            ),
            if (showList)
              TextButton.icon(
                onPressed: _openList,
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('Daftar pohon'),
              ),
            if (_state.query.isNotEmpty || _state.filters.activeCount > 0)
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset filter'),
              ),
          ],
        ),
        Text(
          '${_state.visibleTrees.length} hasil • ${_state.mappedTrees.length} titik peta',
          key: const ValueKey('map-result-count'),
          style: const TextStyle(color: Colors.black87),
        ),
        if (_state.verifiedTrees.isEmpty)
          const Text('Belum ada pohon terverifikasi.')
        else if (_state.visibleTrees.isEmpty)
          const Text('Tidak ada pohon yang sesuai. Coba reset filter.'),
        if (_state.visibleTrees.length != _state.mappedTrees.length)
          const Text('Pohon tanpa koordinat valid tetap ada di daftar.'),
        if (_gpsMessage != null)
          Semantics(liveRegion: true, child: Text(_gpsMessage!)),
        if (_tileError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sebagian peta belum dimuat.'),
                TextButton(
                  onPressed: () => setState(() {
                    _tileError = false;
                    _tileVersion++;
                  }),
                  child: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _treeList(ValueChanged<TreeData> onSelect) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    itemCount: _state.visibleTrees.length,
    itemBuilder: (context, index) {
      final tree = _state.visibleTrees[index];
      final selected = tree.id == _state.selectedId;
      return Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: Duration(
            milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 160,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: selected ? PublicUi.mint : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hoveredId == tree.id
                ? [
                    BoxShadow(
                      color: PublicUi.ink.withValues(alpha: .1),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
            border: Border.all(
              color: selected || _focusedId == tree.id
                  ? AppColors.leaf
                  : PublicUi.border,
              width: selected || _focusedId == tree.id ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onHover: (hover) =>
                  setState(() => _hoveredId = hover ? tree.id : null),
              onFocusChange: (focus) =>
                  setState(() => _focusedId = focus ? tree.id : null),
              hoverColor: PublicUi.mint.withValues(alpha: .5),
              key: ValueKey('tree-card-${tree.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(tree),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TreeThumbnail(base64: tree.photoBase64, size: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tree.species,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address(tree),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _condition(tree),
                          if (!hasPublicMapCoordinates(tree))
                            const Text('Koordinat belum valid'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _mapArea({
    required bool wide,
    bool floatingSearch = false,
  }) => LayoutBuilder(
    builder: (context, box) {
      final selected = _state.selectedTree;
      return Stack(
        key: const ValueKey('public-map-canvas'),
        children: [
          Positioned.fill(
            child: widget.mapBuilder?.call(_state, _select) ?? _productionMap(),
          ),
          if (wide)
            Positioned(
              left: 20,
              top: 20,
              bottom: 20,
              width: 320,
              child: PublicPanel(
                key: const ValueKey('public-map-results-panel'),
                floating: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (box.maxHeight - 40) * .58,
                      ),
                      child: SingleChildScrollView(
                        child: _header(showList: false),
                      ),
                    ),
                    const Divider(height: 1, color: PublicUi.border),
                    Expanded(
                      child: _state.visibleTrees.isEmpty
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 40,
                                      color: PublicUi.muted,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Tidak ada pohon yang sesuai'),
                                    TextButton(
                                      onPressed: _resetFilters,
                                      child: const Text('Reset filter'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _treeList(_select),
                    ),
                  ],
                ),
              ),
            ),
          if (floatingSearch)
            Positioned(
              top: 12,
              left: 12,
              right: 76,
              child: PublicPanel(
                key: const ValueKey('public-map-search-panel'),
                floating: true,
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * .46),
                  child: SingleChildScrollView(child: _header(showList: true)),
                ),
              ),
            ),
          Positioned(
            top: wide ? 20 : 12,
            right: wide ? 20 : 12,
            child: Material(
              key: const ValueKey('public-map-controls'),
              color: Colors.white,
              elevation: 4,
              shadowColor: PublicUi.ink.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
              child: Flex(
                direction: wide || !floatingSearch
                    ? Axis.horizontal
                    : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Perbesar peta',
                    onPressed: !_canMove
                        ? null
                        : () => _move(
                            _state.center,
                            (_state.zoom + 1).clamp(3, 19).toDouble(),
                          ),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 4, height: 4),
                  IconButton(
                    tooltip: 'Perkecil peta',
                    onPressed: !_canMove
                        ? null
                        : () => _move(
                            _state.center,
                            (_state.zoom - 1).clamp(3, 19).toDouble(),
                          ),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 4, height: 4),
                  IconButton(
                    tooltip: 'Lokasi saya',
                    onPressed: !_canMove || _locating ? null : _locate,
                    icon: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(width: 4, height: 4),
                  IconButton(
                    tooltip: 'Reset tampilan',
                    onPressed: !_canMove
                        ? null
                        : () => _move(PublicMapState.defaultCenter, 13),
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: wide ? null : 12,
            right: wide ? 20 : 12,
            bottom: 32,
            width: wide ? 380 : null,
            child: AnimatedSwitcher(
              duration: Duration(
                milliseconds: MediaQuery.of(context).disableAnimations
                    ? 0
                    : 220,
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              // Only the new card participates in hit testing during a selection change.
              layoutBuilder: (currentChild, previousChildren) =>
                  currentChild ?? const SizedBox.shrink(),
              child: selected == null
                  ? const SizedBox.shrink(key: ValueKey('no-selection'))
                  : AnimatedContainer(
                      key: ValueKey('selected-${selected.id}'),
                      duration: PublicUi.duration(context, 220),
                      curve: Curves.easeOutCubic,
                      constraints: BoxConstraints(
                        maxHeight: wide
                            ? (box.maxHeight - 112).clamp(0, 460).toDouble()
                            : (box.maxHeight * (_detailExpanded ? .88 : .46))
                                  .clamp(0, box.maxHeight - 40)
                                  .toDouble(),
                      ),
                      child: PublicPanel(
                        floating: true,
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      !wide && _detailExpanded
                                          ? 'Detail pohon'
                                          : selected.species,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Tutup kartu pohon',
                                    onPressed: () {
                                      setState(() => _detailExpanded = false);
                                      _state.clearSelection();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                key: ValueKey(
                                  'selected-body-${selected.id}-${!wide && _detailExpanded}',
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: !wide && _detailExpanded
                                    ? _fullDetail(selected)
                                    : _selectedCard(selected),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: FilledButton.icon(
                                key: const ValueKey('public-map-detail-action'),
                                onPressed: wide
                                    ? _openDetail
                                    : () => setState(
                                        () =>
                                            _detailExpanded = !_detailExpanded,
                                      ),
                                icon: Icon(
                                  !wide && _detailExpanded
                                      ? Icons.expand_more
                                      : Icons.expand_less,
                                  size: 20,
                                ),
                                label: Text(
                                  !wide && _detailExpanded
                                      ? 'Ringkas detail'
                                      : 'Lihat detail',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );

  Widget _productionMap() => FlutterMap(
    mapController: _map,
    options: MapOptions(
      initialCenter: _state.center,
      initialZoom: _state.zoom,
      minZoom: 3,
      maxZoom: 19,
      onMapReady: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _ready = true);
      }),
      onPositionChanged: (camera, hasGesture) {
        if (hasGesture) _motion.stop();
        _state.center = camera.center;
        _state.zoom = camera.zoom;
      },
    ),
    children: [
      TileLayer(
        key: ValueKey(_tileVersion),
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.pemetaanpohon.app',
        errorTileCallback: (_, error, stack) {
          if (!_tileError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_tileError) setState(() => _tileError = true);
            });
          }
        },
      ),
      MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: 50,
          size: const Size(48, 48),
          markers: _state.mappedTrees
              .map(
                (tree) => Marker(
                  key: ValueKey(tree.id),
                  point: LatLng(tree.latitude, tree.longitude),
                  width: 48,
                  height: 48,
                  child: PublicTreePin(
                    tree: tree,
                    selected: tree.id == _state.selectedId,
                    onTap: () => _select(tree),
                  ),
                ),
              )
              .toList(),
          builder: (_, markers) => CircleAvatar(
            backgroundColor: AppColors.navy,
            child: Text(
              '${markers.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      RichAttributionWidget(
        attributions: [
          const TextSourceAttribution('OpenStreetMap contributors'),
        ],
      ),
    ],
  );

  Widget _selectedCard(TreeData tree) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PublicTreePhoto(tree: tree, width: 72, height: 88),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _address(tree),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _condition(tree),
    ],
  );
  Widget _fullDetail(TreeData tree) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PublicTreePhoto(tree: tree, width: double.infinity, height: 240),
      const SizedBox(height: 16),
      Text(
        tree.species,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      _condition(tree),
      const SizedBox(height: 12),
      Text('Jalan: ${tree.namaJalan.isEmpty ? 'Belum diisi' : tree.namaJalan}'),
      Text(
        'Kelurahan: ${tree.kelurahan.isEmpty ? 'Belum diisi' : tree.kelurahan}',
      ),
      Text(
        'Kecamatan: ${tree.kecamatan.isEmpty ? 'Belum diisi' : tree.kecamatan}',
      ),
      if (tree.ranahKewenangan.isNotEmpty)
        Text('Ranah kewenangan: ${tree.ranahKewenangan}'),
      if (tree.keteranganKondisi.isNotEmpty)
        Text('Keterangan: ${tree.keteranganKondisi}'),
      const SizedBox(height: 12),
      if (hasPublicMapCoordinates(tree))
        SelectableText('Koordinat: ${tree.latitude}, ${tree.longitude}')
      else
        const Text('Koordinat belum valid.'),
    ],
  );
  String _address(TreeData tree) {
    final parts = [
      tree.namaJalan,
      tree.kelurahan,
      tree.kecamatan,
    ].where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? 'Lokasi belum diisi' : parts.join(', ');
  }

  Widget _condition(TreeData tree) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: PublicConditionBadge(condition: tree.condition),
  );
}

class _FilterSheet extends StatefulWidget {
  final PublicMapFilters initialFilters;
  final List<TreeData> trees;
  const _FilterSheet({required this.initialFilters, required this.trees});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late PublicMapFilters _draft;

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
        final trees = widget.trees;
        final speciesOptions = {
          ...trees.map((t) => t.species),
          if (_draft.species != 'Semua') _draft.species,
        }.where((s) => s != 'Semua').toList()..sort();
        final kelurahanOptions = kelurahanFor(_draft.kecamatan);

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Filter Peta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kecamatan',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Semua Kecamatan'),
                ),
                ...cirebonKecamatanList.map(
                  (k) => DropdownMenuItem(value: k, child: Text(k)),
                ),
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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kelurahan',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Semua Kelurahan'),
                ),
                ...kelurahanOptions.map(
                  (k) => DropdownMenuItem(value: k, child: Text(k)),
                ),
              ],
              onChanged: _draft.kecamatan == null
                  ? null
                  : (v) => setState(() {
                      _draft = _draft.copyWith(
                        kelurahan: v,
                        clearKelurahan: v == null,
                      );
                    }),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Jenis Pohon'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _draft.species,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                'Semua',
                ...speciesOptions,
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(species: v ?? 'Semua'),
              ),
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
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(newestFirst: true)),
            ),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Terlama'),
              value: false,
              groupValue: _draft.newestFirst,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(newestFirst: false)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _draft = const PublicMapFilters()),
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