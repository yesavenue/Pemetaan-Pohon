import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../civic_design.dart';

class TreeThumbnail extends StatefulWidget {
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
  State<TreeThumbnail> createState() => _TreeThumbnailState();
}

class _TreeThumbnailState extends State<TreeThumbnail> {
  MemoryImage? _image;
  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant TreeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) {
      _decode();
    }
  }

  void _decode() {
    _image = null;
    try {
      if (widget.base64.isNotEmpty) {
        _image = MemoryImage(base64Decode(widget.base64));
      }
    } on FormatException {
      /* Use placeholder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      color: AppColors.leaf.withValues(alpha: .1),
      child: const Center(
        child: TreeSilhouette(color: AppColors.leaf, size: 28),
      ),
    );
    final image = _image;
    final content = image == null
        ? placeholder()
        : Image(
            image: ResizeImage.resizeIfNeeded(
              (widget.size * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 1600),
              null,
              image,
            ),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, error, stack) => placeholder(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: widget.size,
        height: widget.height ?? widget.size,
        child: content,
      ),
    );
  }
}