import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/tree_data.dart';
import '../../utils/tree_condition_style.dart';
import 'public_ui.dart';
import '../civic_design.dart';

IconData publicConditionIcon(TreeCondition condition) => switch (condition) {
  TreeCondition.sehat => Icons.park_rounded,
  TreeCondition.sakit => Icons.park_rounded,
  TreeCondition.rawanTumbang => Icons.park_rounded,
};

class PublicIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const PublicIconTile({
    super.key,
    required this.icon,
    this.color = PublicUi.green,
    this.size = 48,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: .08), color.withValues(alpha: .18)],
      ),
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: color.withValues(alpha: .12)),
    ),
    child: Center(
      child: icon == Icons.park_rounded
          ? TreeSilhouette(color: color, size: size * .55)
          : Icon(icon, color: color, size: size * .55),
    ),
  );
}

class PublicConditionBadge extends StatelessWidget {
  final TreeCondition condition;
  const PublicConditionBadge({super.key, required this.condition});
  @override
  Widget build(BuildContext context) {
    final color = treeConditionColor(condition);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TreeSilhouette(color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                condition.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PublicUi.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One visual language for markers on the landing page and the full map.
class PublicTreePin extends StatelessWidget {
  final TreeData tree;
  final bool selected;
  final VoidCallback onTap;
  const PublicTreePin({
    super.key,
    required this.tree,
    required this.onTap,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) {
    final color = treeConditionColor(tree.condition);
    return Tooltip(
      message: '${tree.species}: ${tree.condition.label}',
      child: Semantics(
        button: true,
        selected: selected,
        label: '${tree.species}, ${tree.condition.label}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: PublicUi.duration(context, 180),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? color.withValues(alpha: .18)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: .35)
                      : Colors.transparent,
                ),
              ),
              child: CustomPaint(
                painter: _PinPainter(color),
                child: Align(
                  alignment: const Alignment(0, -.2),
                  child: TreeSilhouette(
                    color: tree.condition == TreeCondition.sakit
                        ? PublicUi.ink
                        : Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final path = Path()
      ..moveTo(24, 45)
      ..cubicTo(18, 38, 7, 30, 7, 21)
      ..cubicTo(7, -1, 41, -1, 41, 21)
      ..cubicTo(41, 30, 30, 38, 24, 45)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: .3), 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      oldDelegate.color != color;
}

class PublicTreePhoto extends StatelessWidget {
  final TreeData tree;
  final double width;
  final double height;
  const PublicTreePhoto({
    super.key,
    required this.tree,
    this.width = 72,
    this.height = 72,
  });
  @override
  Widget build(BuildContext context) {
    try {
      if (tree.photoBase64.isNotEmpty) {
        return PublicPhotoFrame(
          image: MemoryImage(base64Decode(tree.photoBase64)),
          title: tree.species,
          width: width,
          height: height,
        );
      }
    } on FormatException {
      // Invalid stored photos keep the same footprint and never break the map.
    }
    return SizedBox(width: width, height: height, child: const _MissingPhoto());
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Foto belum tersedia',
    child: Container(
      decoration: BoxDecoration(
        color: PublicUi.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.park_rounded, color: PublicUi.green, size: 28),
      ),
    ),
  );
}

/// A real photo opens locally. No upload, URL, or data mutation is involved.
class PublicPhotoFrame extends StatefulWidget {
  final ImageProvider image;
  final String title;
  final double width;
  final double height;
  const PublicPhotoFrame({
    super.key,
    required this.image,
    required this.title,
    this.width = double.infinity,
    required this.height,
  });
  @override
  State<PublicPhotoFrame> createState() => _PublicPhotoFrameState();
}

class _PublicPhotoFrameState extends State<PublicPhotoFrame> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: widget.image,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => const _MissingPhoto(),
        frameBuilder: (context, child, frame, wasSynchronous) => Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale:
                  !MediaQuery.of(context).disableAnimations &&
                      (_hovered || _focused)
                  ? 1.04
                  : 1,
              duration: PublicUi.duration(context, 180),
              curve: Curves.easeOutCubic,
              child: child,
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('photo-open-${widget.title}'),
                  onHover: (value) => setState(() => _hovered = value),
                  onFocusChange: (value) => setState(() => _focused = value),
                  onTap: () =>
                      showPublicPhoto(context, widget.image, widget.title),
                  child: Semantics(
                    button: true,
                    label: 'Perbesar foto ${widget.title}',
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: PublicUi.ink.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showPublicPhoto(
  BuildContext context,
  ImageProvider image,
  String title,
) {
  final theme = PublicUi.theme(context);
  final duration = PublicUi.duration(context, 220);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup foto',
    barrierColor: Colors.black.withValues(alpha: .88),
    transitionDuration: duration,
    pageBuilder: (_, animation, secondaryAnimation) => Theme(
      data: theme,
      child: _PhotoViewer(image: image, title: title),
    ),
    transitionBuilder: (_, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
  );
}

class _PhotoViewer extends StatefulWidget {
  final ImageProvider image;
  final String title;
  const _PhotoViewer({required this.image, required this.title});
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  final _viewport = GlobalKey();
  late final AnimationController _zoomMotion;
  Matrix4Tween? _zoomTween;

  @override
  void initState() {
    super.initState();
    // Create the ticker while this element is active, even if zoom is never used.
    _zoomMotion = AnimationController(vsync: this)..addListener(_tickZoom);
  }

  void _tickZoom() {
    final tween = _zoomTween;
    if (tween != null) {
      _transform.value = tween.transform(
        Curves.easeOutCubic.transform(_zoomMotion.value),
      );
    }
  }

  void _animateTo(Matrix4 target) {
    _zoomMotion.stop();
    if (MediaQuery.of(context).disableAnimations) {
      _transform.value = target;
      return;
    }
    _zoomTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _zoomMotion.duration = PublicUi.duration(context, 220);
    _zoomMotion.forward(from: 0);
  }

  void _zoom(double factor) {
    final box = _viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    final scale = (_transform.value.getMaxScaleOnAxis() * factor)
        .clamp(1.0, 4.0)
        .toDouble();
    final center = box.size.center(Offset.zero);
    final scene = _transform.toScene(center);
    // Preserve the subject at the viewport center and keep the image in bounds.
    final dx = (center.dx - scene.dx * scale)
        .clamp(box.size.width * (1 - scale), 0.0)
        .toDouble();
    final dy = (center.dy - scene.dy * scale)
        .clamp(box.size.height * (1 - scale), 0.0)
        .toDouble();
    _animateTo(
      Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(dx, dy, 0),
    );
  }

  @override
  void dispose() {
    _zoomMotion.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.pop(context),
    },
    child: Focus(
      autofocus: true,
      child: Material(
        key: const ValueKey('public-photo-viewer'),
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup foto',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: InteractiveViewer(
                    key: _viewport,
                    transformationController: _transform,
                    onInteractionStart: (_) => _zoomMotion.stop(),
                    minScale: 1,
                    maxScale: 4,
                    child: SizedBox.expand(
                      child: Image(
                        image: widget.image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, stack) => const Center(
                          child: Text(
                            'Foto tidak dapat dibaca.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Perkecil foto',
                      onPressed: () => _zoom(.8),
                      icon: const Icon(
                        Icons.remove_rounded,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _animateTo(Matrix4.identity()),
                      child: const Text(
                        'Ukuran awal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Perbesar foto',
                      onPressed: () => _zoom(1.25),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}