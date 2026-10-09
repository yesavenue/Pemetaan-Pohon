import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Short, one-shot entrances. Does not replace the child's state on rebuild.
class CivicEntrance extends StatelessWidget {
  final Widget child;
  const CivicEntrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(
      milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 280,
    ),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
  );
}

/// Content-sized editorial heading shared by the three roles.
class CivicHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget? action;
  const CivicHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => CivicEntrance(
    child: Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 24 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyDark, AppColors.navy, Color(0xFF1A584D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const TreeSilhouette(size: 22, color: Color(0xFFD6B45A)),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFFD6B45A),
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 26 : 32,
              height: 1.18,
              letterSpacing: -.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFDCE8E6),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

/// A canopy and visible trunk, rather than a leaf or warning symbol.
class TreeSilhouette extends StatelessWidget {
  final Color color;
  final double size;
  const TreeSilhouette({super.key, required this.color, this.size = 24});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TreePainter(color)),
    ),
  );
}

class _TreePainter extends CustomPainter {
  final Color color;
  const _TreePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 17, 4, 13),
        const Radius.circular(1.5),
      ),
      paint,
    );
    final canopy = Path()
      ..moveTo(9, 23)
      ..cubicTo(-1, 23, 0, 12, 7, 11)
      ..cubicTo(4, 1, 19, -3, 23, 7)
      ..cubicTo(33, 6, 35, 21, 25, 23)
      ..close();
    canvas.drawPath(canopy, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) =>
      oldDelegate.color != color;
}