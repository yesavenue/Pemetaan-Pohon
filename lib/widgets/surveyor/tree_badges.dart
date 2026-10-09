import 'package:flutter/material.dart';
import '../../models/tree_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/tree_condition_style.dart';
import '../civic_design.dart';

class TreeBadges extends StatelessWidget {
  final TreeData tree;
  const TreeBadges({super.key, required this.tree});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      _badge(
        tree.condition.label,
        treeConditionColor(tree.condition),
        TreeSilhouette(color: treeConditionColor(tree.condition), size: 18),
      ),
      _badge(
        tree.status == TreeStatus.verified
            ? 'Terverifikasi'
            : 'Menunggu verifikasi',
        AppColors.navy,
        Icon(
          tree.status == TreeStatus.verified
              ? Icons.verified_outlined
              : Icons.schedule_rounded,
          size: 16,
          color: AppColors.navy,
        ),
      ),
    ],
  );
  Widget _badge(String label, Color color, Widget icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
