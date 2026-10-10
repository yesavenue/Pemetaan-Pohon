import 'package:flutter/material.dart';
import 'public_ui.dart';

/// Scroll-linked depth for the city photograph. No timer or idle animation.
/// Only this image repaints; page text and controls stay in their layout.
class PublicScrollImage extends StatefulWidget {
  final ImageProvider image;
  const PublicScrollImage({super.key, required this.image});

  @override
  State<PublicScrollImage> createState() => _PublicScrollImageState();
}

class _PublicScrollImageState extends State<PublicScrollImage> {
  final _offset = ValueNotifier<double>(0);
  ScrollPosition? _position;
  bool _scheduled = false;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    final position = _reducedMotion
        ? null
        : Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    if (_reducedMotion) {
      _offset.value = 0;
    } else {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _reducedMotion) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      final top = box.localToGlobal(Offset.zero).dy;
      final viewport = MediaQuery.sizeOf(context).height;
      if (top > viewport || top + box.size.height < 0) {
        return;
      }
      final progress = ((viewport - top) / (viewport + box.size.height)).clamp(
        0.0,
        1.0,
      );
      // A bounded 24px travel with overscan prevents exposed image edges.
      _offset.value = (progress.toDouble() - .5) * 24;
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _offset,
          child: Image(
            image: widget.image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, error, stack) =>
                const ColoredBox(color: PublicUi.ink),
          ),
          builder: (_, offset, child) => Transform.translate(
            key: const ValueKey('public-city-photo-motion'),
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: _reducedMotion ? 1 : 1.08,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Highlights a changed value without counting through fictitious numbers.
/// Replaces the old child immediately, including hit testing and semantics.
class PublicValueChange extends StatelessWidget {
  final Object identity;
  final Widget child;
  const PublicValueChange({
    super.key,
    required this.identity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(identity),
    tween: Tween(begin: 0, end: 1),
    duration: PublicUi.duration(context, 200),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, value, child) => Opacity(
      opacity: .65 + .35 * value,
      child: Transform.translate(
        offset: Offset(0, 5 * (1 - value)),
        child: child,
      ),
    ),
  );
}