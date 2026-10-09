import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../civic_design.dart';

class TreeThumbnail extends StatelessWidget {
  final String base64;
  final double size;
  final double? height;
  const TreeThumbnail({
    super.key,
    required this.base64,
    this.size = 64,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      color: AppColors.leaf.withValues(alpha: .1),
      child: const Center(
        child: TreeSilhouette(color: AppColors.leaf, size: 28),
      ),
    );
    Widget content;
    try {
      content = base64.isEmpty
          ? placeholder()
          : Image.memory(
              base64Decode(base64),
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => placeholder(),
            );
    } on FormatException {
      content = placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: size, height: height ?? size, child: content),
    );
  }
}
