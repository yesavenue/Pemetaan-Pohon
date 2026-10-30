import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/public/public_home_interactions.dart';
import '../widgets/public/public_motion.dart';
import '../widgets/public/public_visuals.dart';
import '../screens/public_map_viewer_screen.dart';
import '../widgets/public/public_footer.dart';
import '../utils/tree_condition_style.dart';
import '../widgets/public_navbar.dart';
import 'public_tracking_screen.dart';

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
  final _guideSection = GlobalKey();

  void _openGuide() {
    final target = _guideSection.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
      duration: PublicUi.duration(context, 400), curve: Curves.easeInOutCubic, alignment: 0);
    }
  }
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
      widget.treeStream ?? TreeService().streamPublicTrees();
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
      underHeader: true,
      children: [
        _Hero(controller: _scroll),
        PublicContainer(child: PublicReveal(child: PublicQuickActions(
          onMap: () {
            if (_mapSection.currentContext == null) {
              navigateToPublicPage(context, PublicPage.peta, PublicPage.beranda);
            } else {
              _exploreCondition(null);
            }
          }, onGuide: _openGuide,
          onStatistics: () => navigateToPublicPage(context, PublicPage.statistik, PublicPage.beranda),
        ))),
        PublicContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<List<TreeData>>(
                stream: _trees,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Message(
                      text: 'Data pohon belum berhasil dimuat. Periksa koneksi lalu coba lagi.',
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
                      const Text('Pohon yang sudah terpetakan',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: PublicUi.ink)),
                      const SizedBox(height: 8),
                      const Text('Ringkasan data terverifikasi. Pilih kondisi untuk melihat sebarannya.',
                        style: TextStyle(color: PublicUi.muted)),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _Summary(
                          trees: trees,
                          selected: _previewCondition,
                          onSelect: _exploreCondition,
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (box.maxWidth >= 1000 && MediaQuery.textScalerOf(context).scale(14) <= 18.2)
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Expanded(flex: 3, child: text), const SizedBox(width: 32),
                                    Expanded(flex: 7, child: map),
                                  ])
                                else ...[text, const SizedBox(height: 20), map],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              PublicReveal(child: PublicApplicationGuide(key: _guideSection,
                onApply: () => navigateToPublicPage(context, PublicPage.permohonan, PublicPage.beranda),
                onTrack: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicTrackingScreen())),
              )),
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

class _Hero extends StatefulWidget {
  final ScrollController controller;
  const _Hero({required this.controller});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final wide = box.maxWidth >= 900 && MediaQuery.textScalerOf(context).scale(14) <= 18.2;
    final reduced = MediaQuery.of(context).disableAnimations;
    final minimumHeight = (MediaQuery.sizeOf(context).height * .9).clamp(620.0, 820.0).toDouble();
    return AnimatedBuilder(animation: widget.controller, builder: (context, _) {
      final offset = widget.controller.hasClients ? widget.controller.offset : 0.0;
      // Keep controls readable while a visitor is typing or navigating by keyboard.
      final progress = _focused ? 0.0 : publicHeroProgress(offset);
      final hidden = progress >= 1;
      return Stack(children: [
        Positioned.fill(child: PublicHeroBackdrop(controller: widget.controller)),
        Positioned.fill(child: DecoratedBox(key: const ValueKey('hero-clearing-overlay'),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: .48 * (1 - progress)),
              Colors.black.withValues(alpha: .62 * (1 - progress)),
              Colors.black.withValues(alpha: .32 * (1 - progress))])))),
        Container(constraints: BoxConstraints(minHeight: minimumHeight), width: double.infinity,
          padding: EdgeInsets.fromLTRB(24,
            PublicUi.headerHeight(context) + MediaQuery.paddingOf(context).top + (wide ? 82 : 48), 24, 64),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
            child: IgnorePointer(ignoring: hidden,
              child: ExcludeFocus(excluding: hidden,
                child: ExcludeSemantics(excluding: hidden,
                  child: Focus(onFocusChange: (value) { if (mounted) setState(() => _focused = value); },
                    child: Opacity(key: const ValueKey('hero-content-opacity'), opacity: 1 - progress,
                      child: Transform.translate(offset: Offset(0, reduced ? 0 : -18 * progress),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          PublicGlitchTitle(fontSize: wide ? 48 : 32, exitProgress: progress),
                          const SizedBox(height: 28),
                          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: PublicUi.ink),
                              onPressed: () => navigateToPublicPage(context, PublicPage.peta, PublicPage.beranda),
                              icon: const Icon(Icons.map_outlined), label: const Text('Jelajahi Peta')),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: PublicUi.green, foregroundColor: Colors.white),
                              onPressed: () => navigateToPublicPage(context, PublicPage.permohonan, PublicPage.beranda),
                              icon: const Icon(Icons.edit_note), label: const Text('Ajukan Permohonan')),
                          ]),
                          const SizedBox(height: 22),
                          const _HeroTrackingField(),
                        ]))))))))),
        ),
      ]);
    });
  });
}

class _HeroTrackingField extends StatefulWidget {
  const _HeroTrackingField();
  @override
  State<_HeroTrackingField> createState() => _HeroTrackingFieldState();
}
class _HeroTrackingFieldState extends State<_HeroTrackingField> {
  final _code = TextEditingController();
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  void _open() => Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PublicTrackingScreen(initialCode: _code.text.trim().toLowerCase())));
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(children: [
          Expanded(child: TextField(key: const ValueKey('hero-tracking-code'), controller: _code,
            autocorrect: false, enableSuggestions: false, textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(color: PublicUi.ink),
            decoration: const InputDecoration(labelText: 'Lacak Permohonan', hintText: 'Masukkan kode akses',
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              filled: false, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            onSubmitted: (_) => _open())),
          IconButton(key: const ValueKey('hero-track-request'), tooltip: 'Periksa status permohonan',
            onPressed: _open, icon: const Icon(Icons.search, color: PublicUi.green)),
        ])),
    ),
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
                height: overlay ? 420 : 320,
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
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom & ~InteractiveFlag.rotate),
                            ),
                            children: [
                              TileLayer(
                                key: ValueKey(_version),
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
