import 'package:flutter/material.dart';

import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../utils/cirebon_regions.dart';
import '../utils/tree_condition_style.dart';

class PublicStatistikScreen extends StatelessWidget {
  const PublicStatistikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Pohon')),
      body: StreamBuilder<List<TreeData>>(
        stream: TreeService().streamTrees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          }

          // Statistik publik hanya menghitung data yang sudah diverifikasi,
          // konsisten dengan apa yang ditampilkan di peta publik.
          final trees = (snapshot.data ?? []).where((t) => t.status == TreeStatus.verified).toList();

          final sehatCount = trees.where((t) => t.condition == TreeCondition.sehat).length;
          final sakitCount = trees.where((t) => t.condition == TreeCondition.sakit).length;
          final rawanCount = trees.where((t) => t.condition == TreeCondition.rawanTumbang).length;

          final speciesCount = <String, int>{};
          for (final t in trees) {
            speciesCount[t.species] = (speciesCount[t.species] ?? 0) + 1;
          }
          final speciesSorted = Map.fromEntries(
            speciesCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
          );

          final conditionData = <String, int>{
            TreeCondition.sehat.label: sehatCount,
            TreeCondition.sakit.label: sakitCount,
            TreeCondition.rawanTumbang.label: rawanCount,
          };
          final conditionColorByLabel = <String, Color>{
            TreeCondition.sehat.label: treeConditionColor(TreeCondition.sehat),
            TreeCondition.sakit.label: treeConditionColor(TreeCondition.sakit),
            TreeCondition.rawanTumbang.label: treeConditionColor(TreeCondition.rawanTumbang),
          };

          final kecamatanCount = <String, int>{for (final k in cirebonKecamatanList) k: 0};
          for (final t in trees) {
            if (kecamatanCount.containsKey(t.kecamatan)) {
              kecamatanCount[t.kecamatan] = kecamatanCount[t.kecamatan]! + 1;
            }
          }
          final kecamatanSorted = Map.fromEntries(
            kecamatanCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Total Pohon', value: trees.length, color: AppColors.navy),
                  _StatCard(
                      label: 'Pohon Sehat',
                      value: sehatCount,
                      color: treeConditionColor(TreeCondition.sehat)),
                  _StatCard(
                      label: 'Pohon Sakit',
                      value: sakitCount,
                      color: treeConditionColor(TreeCondition.sakit)),
                  _StatCard(
                      label: 'Rawan Tumbang',
                      value: rawanCount,
                      color: treeConditionColor(TreeCondition.rawanTumbang)),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Distribusi Jenis Pohon',
                child: _HorizontalBarChart(data: speciesSorted, defaultColor: AppColors.navy),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Distribusi Kondisi Pohon',
                child: _HorizontalBarChart(
                  data: conditionData,
                  colorForKey: (k) => conditionColorByLabel[k] ?? AppColors.navy,
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Distribusi per Kecamatan',
                child: _HorizontalBarChart(data: kecamatanSorted, defaultColor: AppColors.leaf),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// Grafik batang horizontal sederhana: label - bar - angka. Dibuat manual
// (bukan pakai fl_chart) supaya persis mengikuti tata letak yang diminta
// dan tidak perlu widget chart tegak yang diputar paksa jadi horizontal.
class _HorizontalBarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color defaultColor;
  final Color Function(String key)? colorForKey;

  const _HorizontalBarChart({
    required this.data,
    this.defaultColor = AppColors.navy,
    this.colorForKey,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Belum ada data.', style: TextStyle(color: Colors.black38)),
      );
    }

    final maxValue = data.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: data.entries.map((e) {
        final ratio = maxValue == 0 ? 0.0 : e.value / maxValue;
        final color = colorForKey?.call(e.key) ?? defaultColor;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(e.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.03, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text('${e.value}',
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}