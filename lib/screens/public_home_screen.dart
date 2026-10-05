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

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PublicNavbar(currentPage: PublicPage.beranda),
      drawer: const PublicNavDrawer(currentPage: PublicPage.beranda),
      body: StreamBuilder<List<TreeData>>(
        stream: TreeService().streamTrees(),
        builder: (context, snapshot) {
          final trees =
              (snapshot.data ?? []).where((t) => t.status == TreeStatus.verified).toList();
          final total = trees.length;
          final sehat = trees.where((t) => t.condition == TreeCondition.sehat).length;
          final sakit = trees.where((t) => t.condition == TreeCondition.sakit).length;
          final rawan = trees.where((t) => t.condition == TreeCondition.rawanTumbang).length;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroSection(),
              _StatsStrip(total: total, sehat: sehat, sakit: sakit, rawan: rawan),
              const _AboutSection(),
              const _FeatureSection(),
              _MapPreviewSection(trees: trees),
              const _CtaSection(),
              const _Footer(),
            ],
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Stack(
      children: [
        SizedBox(
          height: isWide ? 420 : 480,
          width: double.infinity,
          child: Image.asset('assets/image/hero_cirebon.png', fit: BoxFit.cover),
        ),
        Container(
          height: isWide ? 420 : 480,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xE60B3554), Color(0x800B3554), Color(0x330B3554)],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'RUANG HIJAU, KOTA LEBIH BAIK',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pemetaan Pohon\nKota Cirebon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWide ? 44 : 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const Text(
                    'Platform informasi dan pemetaan pohon untuk mendukung pengelolaan '
                    'ruang hijau serta meningkatkan kepedulian masyarakat terhadap '
                    'lingkungan Kota Cirebon.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.leaf),
                      onPressed: () => navigateToPublicPage(
                          context, PublicPage.peta, PublicPage.beranda),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Jelajahi Peta'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () => navigateToPublicPage(
                          context, PublicPage.permohonan, PublicPage.beranda),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Ajukan Permohonan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final int total, sehat, sakit, rawan;
  const _StatsStrip({required this.total, required this.sehat, required this.sakit, required this.rawan});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(icon: Icons.park, color: AppColors.navy, label: 'Total Pohon', value: total),
              _StatCard(icon: Icons.check_circle, color: AppColors.sehat, label: 'Sehat', value: sehat),
              _StatCard(icon: Icons.warning_amber_rounded, color: AppColors.sakit, label: 'Sakit', value: sakit),
              _StatCard(
                  icon: Icons.error_outline, color: AppColors.rawanTumbang, label: 'Rawan Tumbang', value: rawan),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  const _StatCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tentang Pemetaan Pohon',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 12),
            Text(
              'Sistem ini digunakan untuk mendata, memetakan, dan memantau kondisi pohon '
              'di wilayah Kota Cirebon secara digital. Petugas survei mencatat lokasi, jenis, '
              'dan kondisi kesehatan tiap pohon dari lapangan, yang kemudian diverifikasi oleh '
              'admin sebelum ditampilkan kepada masyarakat melalui $appSystemName.',
              style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.map_outlined, 'Peta Interaktif', 'Jelajahi peta interaktif untuk melihat lokasi, jenis, dan kondisi pohon di Kota Cirebon.', PublicPage.peta),
      (Icons.bar_chart_outlined, 'Data Pohon', 'Lihat sebaran dan statistik pohon secara real-time.', PublicPage.statistik),
      (Icons.content_cut_outlined, 'Permohonan Perapihan', 'Laporkan pohon yang perlu dirapikan kepada DPRKP Kota Cirebon.', PublicPage.permohonan),
      (Icons.eco_outlined, 'Informasi Lingkungan', 'Untuk masyarakat yang lebih peduli lingkungan Kota Cirebon.', PublicPage.tentang),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: features.map((f) {
          return SizedBox(
            width: 260,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => navigateToPublicPage(context, f.$4, PublicPage.beranda),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(f.$1, color: AppColors.leaf, size: 30),
                      const SizedBox(height: 12),
                      Text(f.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(f.$3, style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4)),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Text('Lihat', style: TextStyle(color: AppColors.leaf, fontWeight: FontWeight.w600, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: AppColors.leaf),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MapPreviewSection extends StatelessWidget {
  final List<TreeData> trees;
  const _MapPreviewSection({required this.trees});

  @override
  Widget build(BuildContext context) {
    final center = trees.isEmpty
        ? const LatLng(-6.7063, 108.5571)
        : LatLng(
            trees.map((t) => t.latitude).reduce((a, b) => a + b) / trees.length,
            trees.map((t) => t.longitude).reduce((a, b) => a + b) / trees.length,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sebaran Pohon',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 320,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: trees.isEmpty ? 12 : 13),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pemetaanpohon.app',
                      ),
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 50,
                          size: const Size(40, 40),
                          markers: trees
                              .map((t) => Marker(
                                    point: LatLng(t.latitude, t.longitude),
                                    width: 30,
                                    height: 30,
                                    child: Icon(Icons.location_on, color: treeConditionColor(t.condition), size: 26),
                                  ))
                              .toList(),
                          builder: (context, markers) => CircleAvatar(
                            backgroundColor: AppColors.navy,
                            child: Text('${markers.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: () => navigateToPublicPage(context, PublicPage.peta, PublicPage.beranda),
                      icon: const Icon(Icons.open_in_full, size: 16),
                      label: const Text('Lihat Peta Lengkap'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  const _CtaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Menemukan pohon yang perlu dirapikan?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.leaf),
            onPressed: () => navigateToPublicPage(context, PublicPage.permohonan, PublicPage.beranda),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ajukan Permohonan'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navyDark,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        children: [
          const Text(appSystemName,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(appInstansiUnit, style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Text('$appContactEmail · $appContactPhone',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}