import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
      child: const Center(child: Icon(Icons.park, color: AppColors.leaf)),
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
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: height ?? size, child: content),
    );
  }
}