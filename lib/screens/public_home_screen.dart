import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/public/public_motion.dart';
import '../widgets/civic_design.dart';
import '../widgets/public/public_visuals.dart';
import '../screens/public_map_viewer_screen.dart';
import '../widgets/public/public_footer.dart';
import '../utils/tree_condition_style.dart';
import '../widgets/public_navbar.dart';

class PublicHomeScreen extends StatefulWidget {
  final Stream<List<TreeData>>? treeStream;
  final Widget Function(List<TreeData>)? mapPreviewBuilder;
  const PublicHomeScreen({super.key, this.treeStream, this.mapPreviewBuilder});
  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  late Stream<List<TreeData>> _trees;
  final _scroll = ScrollController();
  final _mapSection = GlobalKey();
  TreeCondition? _previewCondition;

  void _exploreCondition(TreeCondition? condition) {
    setState(() => _previewCondition = condition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      final box = _mapSection.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      final target =
          (_scroll.offset +
                  box.localToGlobal(Offset.zero).dy -
                  PublicUi.headerHeight(context) -
                  MediaQuery.paddingOf(context).top -
                  16)
              .clamp(0.0, _scroll.position.maxScrollExtent)
              .toDouble();
      if (MediaQuery.of(context).disableAnimations) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: PublicUi.duration(context, 360),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _trees = _stream();
  }

  Stream<List<TreeData>> _stream() =>
      widget.treeStream ?? TreeService().streamTrees();
  @override
  void didUpdateWidget(covariant PublicHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeStream != widget.treeStream) _trees = _stream();
  }

  @override
  Widget build(BuildContext context) => PublicScaffold(
    currentPage: PublicPage.beranda,
    body: PublicPageScroll(
      controller: _scroll,
      children: [
        PublicContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PublicReveal(milliseconds: 320, child: _Hero()),
              StreamBuilder<List<TreeData>>(
                stream: _trees,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Message(
                      text:
                          'Data pohon belum berhasil dimuat. Periksa koneksi lalu coba lagi.',
                      onRetry: () => setState(() => _trees = _stream()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Memuat data pohon…'),
                        ],
                      ),
                    );
                  }
                  final trees = snapshot.data!
                      .where((t) => t.status == TreeStatus.verified)
                      .toList();
                  final previewTrees = trees
                      .where(
                        (tree) =>
                            _previewCondition == null ||
                            tree.condition == _previewCondition,
                      )
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, box) {
                          final overlap =
                              PublicUi.desktop(context, box.maxWidth)
                              ? 24.0
                              : 0.0;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: overlap),
                            child: Transform.translate(
                              offset: Offset(0, -overlap),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: overlap == 0 ? 16 : 0,
                                ),
                                child: _Summary(
                                  trees: trees,
                                  selected: _previewCondition,
                                  onSelect: _exploreCondition,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      LayoutBuilder(
                        key: _mapSection,
                        builder: (context, box) {
                          final text = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EKSPLORASI KOTA',
                                style: TextStyle(
                                  color: PublicUi.green,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Jelajahi sebaran pohon',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Lokasi dan kondisi berdasarkan data pohon terverifikasi.',
                                style: TextStyle(color: PublicUi.muted),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  'Pratinjau: ${_previewCondition?.label ?? 'Semua kondisi'} • ${previewTrees.length} pohon',
                                  key: const ValueKey('home-preview-scope'),
                                  style: const TextStyle(
                                    color: PublicUi.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_previewCondition != null)
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _previewCondition = null),
                                  icon: const Icon(
                                    Icons.filter_alt_off_outlined,
                                  ),
                                  label: const Text('Tampilkan semua kondisi'),
                                ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PublicMapViewerScreen(
                                          initialCondition: _previewCondition,
                                        ),
                                      ),
                                    ),
                                icon: const Icon(Icons.arrow_outward),
                                label: const Text('Buka peta lengkap'),
                              ),
                            ],
                          );
                          final map = ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: previewTrees.isEmpty
                                ? _Message(
                                    text: _previewCondition == null
                                        ? 'Belum ada pohon terverifikasi untuk ditampilkan.'
                                        : 'Belum ada pohon ${_previewCondition!.label.toLowerCase()} terverifikasi untuk ditampilkan.',
                                  )
                                : widget.mapPreviewBuilder?.call(
                                        previewTrees,
                                      ) ??
                                      PublicHomeMapPreview(
                                        trees: previewTrees,
                                        initialCondition: _previewCondition,
                                      ),
                          );
                          return PublicReveal(
                            child:
                                box.maxWidth >= 900 &&
                                    MediaQuery.textScalerOf(
                                          context,
                                        ).scale(14) <=
                                        18.2
                                ? Row(
                                    children: [
                                      Expanded(flex: 35, child: text),
                                      const SizedBox(width: 32),
                                      Expanded(flex: 65, child: map),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      text,
                                      const SizedBox(height: 24),
                                      map,
                                    ],
                                  ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 64),
              const PublicReveal(child: _Guide()),
              const SizedBox(height: 40),
              CivicHeading(
                eyebrow: 'BERPARTISIPASI',
                title: 'Menemukan pohon yang perlu dirapikan?',
                description: 'Ajukan permohonan perapihan tanpa perlu login.',
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: PublicUi.ink,
                  ),
                  onPressed: () => navigateToPublicPage(
                    context,
                    PublicPage.permohonan,
                    PublicPage.beranda,
                  ),
                  icon: const Icon(Icons.arrow_outward),
                  label: const Text('Ajukan Permohonan'),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => navigateToPublicPage(
                    context,
                    PublicPage.tentang,
                    PublicPage.beranda,
                  ),
                  child: const Text('Tentang pemetaan pohon →'),
                ),
              ),
            ],
          ),
        ),
        const PublicFooter(currentPage: PublicPage.beranda),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 900 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18.2;
      final actions = [
        FilledButton.icon(
          onPressed: () => navigateToPublicPage(
            context,
            PublicPage.peta,
            PublicPage.beranda,
          ),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Jelajahi Peta'),
        ),
        OutlinedButton.icon(
          onPressed: () => navigateToPublicPage(
            context,
            PublicPage.permohonan,
            PublicPage.beranda,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Ajukan Permohonan'),
        ),
      ];
      return ClipRRect(
        borderRadius: BorderRadius.circular(wide ? 24 : 20),
        child: Stack(
          children: [
            Positioned.fill(
              child: const PublicScrollImage(
                image: AssetImage('assets/image/hero_cirebon.png'),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PublicUi.ink.withValues(alpha: .96),
                      PublicUi.ink.withValues(alpha: wide ? .32 : .7),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: wide ? 460 : 480),
              child: Padding(
                padding: wide
                    ? const EdgeInsets.all(48)
                    : const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RUANG HIJAU KOTA CIREBON',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Kenali pohonnya.',
                          style: TextStyle(
                            fontSize: wide ? 52 : 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Jaga kotanya.',
                          style: TextStyle(
                            fontSize: wide ? 52 : 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2,
                            height: 1.1,
                            color: const Color(0xFFBFE2CE),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Jelajahi pohon di Kota Cirebon dan ikut merawat ruang hijau di sekitar kita.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (wide)
                          Wrap(spacing: 12, runSpacing: 12, children: actions)
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              actions[0],
                              const SizedBox(height: 12),
                              actions[1],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: PublicUi.ink.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  tooltip: 'Perbesar foto kota',
                  onPressed: () => showPublicPhoto(
                    context,
                    const AssetImage('assets/image/hero_cirebon.png'),
                    'Ruang hijau Kota Cirebon',
                  ),
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Summary extends StatelessWidget {
  final List<TreeData> trees;
  final TreeCondition? selected;
  final ValueChanged<TreeCondition?> onSelect;
  const _Summary({
    required this.trees,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = box.maxWidth >= 1000 * scale
          ? 4
          : box.maxWidth >= 540 * scale
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final condition in <TreeCondition?>[
            null,
            ...TreeCondition.values,
          ])
            SizedBox(width: width, child: _item(context, condition)),
        ],
      );
    },
  );

  Widget _item(BuildContext context, TreeCondition? condition) {
    final label = condition?.label ?? 'Pohon terpetakan';
    final count = condition == null
        ? trees.length
        : trees.where((t) => t.condition == condition).length;
    final color = condition == null
        ? PublicUi.green
        : treeConditionColor(condition);
    final active = selected == condition;
    return Semantics(
      selected: active,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('home-condition-${condition?.name ?? 'all'}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => onSelect(condition),
          child: AnimatedContainer(
            duration: PublicUi.duration(context, 180),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: .08) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? color : PublicUi.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                PublicIconTile(icon: Icons.park_rounded, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PublicValueChange(
                        identity: (label, count),
                        child: Text(
                          '$count',
                          key: ValueKey('summary-$label'),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      Text(label, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text(
                        'Lihat di peta ↓',
                        style: TextStyle(fontSize: 12, color: PublicUi.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Bagaimana mengajukan permohonan?',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, box) {
          final items = [
            for (final entry in [
              (1, 'Isi permohonan', 'Lengkapi data pemohon dengan benar.'),
              (
                2,
                'Lengkapi lokasi & foto',
                'Tambahkan alamat, wilayah, foto pohon dan KTP untuk verifikasi admin.',
              ),
              (
                3,
                'Periksa dan kirim',
                'Tinjau isian, kirim, lalu simpan nomor permohonan.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: PublicUi.mint,
                      foregroundColor: PublicUi.green,
                      child: Text('${entry.$1}'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      entry.$2,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.$3,
                      style: const TextStyle(color: PublicUi.muted),
                    ),
                  ],
                ),
              ),
          ];
          return box.maxWidth >= 850 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18.2
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 32),
                      Expanded(child: items[i]),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: items,
                );
        },
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(liveRegion: true, child: Text(text)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    ),
  );
}

class PublicHomeMapPreview extends StatefulWidget {
  final List<TreeData> trees;
  final TreeCondition? initialCondition;
  final Widget Function(List<TreeData>, ValueChanged<TreeData>)? mapBuilder;
  const PublicHomeMapPreview({
    super.key,
    required this.trees,
    this.mapBuilder,
    this.initialCondition,
  });
  @override
  State<PublicHomeMapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<PublicHomeMapPreview> {
  bool _tileError = false;
  int _version = 0;
  String? _selectedId;

  @override
  void didUpdateWidget(covariant PublicHomeMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.trees.any(
      (tree) => tree.id == _selectedId && tree.status == TreeStatus.verified,
    )) {
      _selectedId = null;
    }
  }

  Widget _selection(TreeData tree) => PublicPanel(
    floating: true,
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublicTreePhoto(tree: tree, width: 64, height: 80),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tree.species,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (tree.namaJalan.isNotEmpty || tree.kecamatan.isNotEmpty)
                    Text(
                      [
                        tree.namaJalan,
                        tree.kecamatan,
                      ].where((s) => s.isNotEmpty).join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PublicUi.muted,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tutup pilihan pohon',
              onPressed: () => setState(() => _selectedId = null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PublicConditionBadge(condition: tree.condition),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => PublicMapViewerScreen(
                initialTreeId: tree.id,
                initialCondition: widget.initialCondition,
              ),
            ),
          ),
          icon: const Icon(Icons.arrow_outward_rounded, size: 18),
          label: const Text('Buka peta lengkap'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final points = widget.trees
        .where(
          (t) =>
              t.status == TreeStatus.verified &&
              t.latitude.isFinite &&
              t.longitude.isFinite &&
              t.latitude >= -90 &&
              t.latitude <= 90 &&
              t.longitude >= -180 &&
              t.longitude <= 180,
        )
        .toList();
    final selected = points.where((tree) => tree.id == _selectedId).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlay =
            constraints.maxWidth >= 600 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18.2;
        final selection = AnimatedSwitcher(
          duration: PublicUi.duration(context, 220),
          layoutBuilder: (current, previous) =>
              current ?? const SizedBox.shrink(),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: selected == null
              ? const SizedBox.shrink()
              : KeyedSubtree(
                  key: ValueKey('home-selected-${selected.id}'),
                  child: _selection(selected),
                ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tileError)
              _Message(
                text: 'Sebagian peta belum berhasil dimuat.',
                onRetry: () => setState(() {
                  _tileError = false;
                  _version++;
                }),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: overlay ? 380 : 300,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child:
                          widget.mapBuilder?.call(
                            points,
                            (tree) => setState(() => _selectedId = tree.id),
                          ) ??
                          FlutterMap(
                            options: MapOptions(
                              onTap: (_, point) =>
                                  setState(() => _selectedId = null),
                              initialCenter: LatLng(-6.7183, 108.5522),
                              initialZoom: 13,
                            ),
                            children: [
                              TileLayer(
                                key: ValueKey(_version),
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.pemetaanpohon.app',
                                errorTileCallback: (_, error, stack) {
                                  if (!_tileError) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted && !_tileError) {
                                            setState(() => _tileError = true);
                                          }
                                        });
                                  }
                                },
                              ),
                              MarkerClusterLayerWidget(
                                options: MarkerClusterLayerOptions(
                                  maxClusterRadius: 50,
                                  size: const Size(40, 40),
                                  markers: points
                                      .map(
                                        (t) => Marker(
                                          point: LatLng(
                                            t.latitude,
                                            t.longitude,
                                          ),
                                          width: 48,
                                          height: 48,
                                          child: PublicTreePin(
                                            tree: t,
                                            selected: t.id == _selectedId,
                                            onTap: () => setState(
                                              () => _selectedId = t.id,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  builder: (_, markers) => CircleAvatar(
                                    backgroundColor: AppColors.navy,
                                    child: Text(
                                      '${markers.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              RichAttributionWidget(
                                attributions: [
                                  const TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                            ],
                          ),
                    ),
                    if (overlay)
                      Positioned(
                        right: 16,
                        bottom: 32,
                        width: 280,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 316),
                          child: SingleChildScrollView(child: selection),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!overlay && selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: selection,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final c in TreeCondition.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: treeConditionColor(c),
                      ),
                      const SizedBox(width: 6),
                      Text(c.label),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}