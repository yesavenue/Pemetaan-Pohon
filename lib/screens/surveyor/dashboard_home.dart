import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/tree_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/tree_condition_style.dart';
import '../../view_models/surveyor_dashboard_data.dart';
import '../../widgets/surveyor/tree_thumbnail.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  final SurveyorDashboardData data;
  final VoidCallback onOpenTrees;
  final ValueChanged<TreeData> onOpenTree;

  const DashboardHome({
    super.key,
    required this.user,
    required this.data,
    required this.onOpenTrees,
    required this.onOpenTree,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 900 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      final summary = _summary(context);
      final recent = _recentTrees();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 20),
                Expanded(child: recent),
              ],
            )
          else ...[
            summary,
            const SizedBox(height: 24),
            recent,
          ],
        ],
      );
    },
  );

  Widget _summary(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Halo, ${user.name}',
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      const SizedBox(height: 4),
      const Text('Ringkasan pendataan pohon Anda'),
      const SizedBox(height: 20),
      Material(
        color: AppColors.leaf,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenTrees,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total pohon Anda',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.trees.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.white30, height: 28),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lihat daftar pohon',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final width = stacked
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(
                width,
                'Input hari ini',
                data.mappedToday(DateTime.now()),
                Icons.today_outlined,
                AppColors.leaf,
              ),
              _stat(
                width,
                'Rawan tumbang',
                data.atRiskCount,
                Icons.warning_amber_rounded,
                AppColors.rawanTumbang,
              ),
            ],
          );
        },
      ),
    ],
  );

  Widget _recentTrees() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Pohon terbaru',
        style: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 12),
      if (data.trees.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Belum ada pohon yang dipetakan. Mulai melalui tab Input.',
            ),
          ),
        ),
      ...data.trees
          .take(5)
          .map(
            (tree) => Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpenTree(tree),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TreeThumbnail(base64: tree.photoBase64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tree.species,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${tree.namaJalan}\n${tree.kecamatan}'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: treeConditionColor(
                                  tree.condition,
                                ).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tree.condition.label,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.navy),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ],
  );

  Widget _stat(
    double width,
    String label,
    int value,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    ),
  );
}