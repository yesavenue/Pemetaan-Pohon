import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SurveyLoading extends StatelessWidget {
  final String label;
  const SurveyLoading({super.key, this.label = 'Memuat hasil survei…'});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          for (var i = 0; i < 3; i++)
            Container(
              height: 96,
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDE9),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
        ],
      ),
    ),
  );
}
