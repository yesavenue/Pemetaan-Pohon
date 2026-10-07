import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../utils/branding.dart';
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
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(),
                  const SizedBox(height: 24),
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Summary(trees: trees),
                          const SizedBox(height: 32),
                          const Text(
                            'Jelajahi sebaran pohon',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Lokasi dan kondisi berdasarkan data pohon terverifikasi.',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => navigateToPublicPage(
                                context,
                                PublicPage.peta,
                                PublicPage.beranda,
                              ),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Buka peta lengkap'),
                            ),
                          ),
                          if (trees.isEmpty)
                            const _Message(
                              text:
                                  'Belum ada pohon terverifikasi untuk ditampilkan.',
                            ),
                          if (trees.isNotEmpty)
                            widget.mapPreviewBuilder?.call(trees) ??
                                _MapPreview(trees: trees),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const _Guide(),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFFE1F3E9),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menemukan pohon yang perlu dirapikan?',
                            style: TextStyle(
                              fontSize: 22,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ajukan permohonan perapihan tanpa perlu login.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => navigateToPublicPage(
                              context,
                              PublicPage.permohonan,
                              PublicPage.beranda,
                            ),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Ajukan Permohonan'),
                          ),
                        ],
                      ),
                    ),
                  ),
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
          ),
        ),
        Container(
          color: AppColors.navy,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                appSystemName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                appInstansiUnit,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '$appContactEmail · $appContactPhone',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 800 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RUANG HIJAU KOTA CIREBON',
            style: TextStyle(
              color: AppColors.leaf,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kenali pohonnya.',
            style: TextStyle(
              fontSize: wide ? 42 : 30,
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Jaga kotanya.',
            style: TextStyle(
              fontSize: wide ? 42 : 30,
              color: AppColors.leaf,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Jelajahi sebaran pohon dan ajukan permohonan perapihan di Kota Cirebon.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
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
                icon: const Icon(Icons.description_outlined),
                label: const Text('Ajukan Permohonan'),
              ),
            ],
          ),
        ],
      );
      final photo = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.asset(
            'assets/image/hero_cirebon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => Container(
              color: const Color(0xFFE1F3E9),
              child: const Center(
                child: Icon(Icons.park, size: 72, color: AppColors.leaf),
              ),
            ),
          ),
        ),
      );
      final content = wide
          ? Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 32),
                Expanded(child: photo),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 24), photo],
            );
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(
          milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 200,
        ),
        child: content,
        builder: (_, value, child) => Opacity(opacity: value, child: child),
      );
    },
  );
}

class _Summary extends StatelessWidget {
  final List<TreeData> trees;
  const _Summary({required this.trees});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 700 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      final values = [
        ('Pohon terpetakan', trees.length, Icons.park_outlined),
        (
          'Sehat',
          trees.where((t) => t.condition == TreeCondition.sehat).length,
          Icons.check_circle_outline,
        ),
        (
          'Rawan Tumbang',
          trees.where((t) => t.condition == TreeCondition.rawanTumbang).length,
          Icons.warning_amber,
        ),
      ];
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in values)
            SizedBox(
              width: wide
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(item.$3, color: AppColors.leaf, size: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1),
                            Text(
                              '${item.$2}',
                              key: ValueKey('summary-${item.$1}'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
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
}

class _Guide extends StatelessWidget {
  const _Guide();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bagaimana mengajukan permohonan?',
            style: TextStyle(
              fontSize: 22,
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in [
            (1, 'Isi data', 'Lengkapi data pemohon dan lokasi pohon.'),
            (
              2,
              'Tambahkan foto',
              'Lampirkan foto pohon dan KTP untuk verifikasi oleh admin.',
            ),
            (
              3,
              'Kirim permohonan',
              'Periksa isian dan simpan nomor setelah pengiriman berhasil.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE1F3E9),
                    child: Text(
                      '${item.$1}',
                      style: const TextStyle(color: AppColors.leaf),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(item.$3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
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

class _MapPreview extends StatefulWidget {
  final List<TreeData> trees;
  const _MapPreview({required this.trees});
  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  bool _tileError = false;
  int _version = 0;
  @override
  Widget build(BuildContext context) {
    final points = widget.trees
        .where(
          (t) =>
              t.latitude.isFinite &&
              t.longitude.isFinite &&
              t.latitude >= -90 &&
              t.latitude <= 90 &&
              t.longitude >= -180 &&
              t.longitude <= 180,
        )
        .toList();
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
            height: 320,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-6.7183, 108.5522),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  key: ValueKey(_version),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pemetaanpohon.app',
                  errorTileCallback: (_, error, stack) {
                    if (!_tileError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
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
                            point: LatLng(t.latitude, t.longitude),
                            width: 32,
                            height: 32,
                            child: Tooltip(
                              message: '${t.species}: ${t.condition.label}',
                              child: Icon(
                                Icons.location_on,
                                color: treeConditionColor(t.condition),
                                size: 30,
                              ),
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
            ),
          ),
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
                  Icon(Icons.circle, size: 12, color: treeConditionColor(c)),
                  const SizedBox(width: 6),
                  Text(c.label),
                ],
              ),
          ],
        ),
      ],
    );
  }
}