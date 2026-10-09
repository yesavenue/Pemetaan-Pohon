import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'public_ui.dart';

/// Integer 1/2/5 scale. Zero is a real baseline, never a progress track.
({int step, int max}) publicChartScale(int largest) {
  if (largest <= 1) return (step: 1, max: 1);
  final target = largest / 4;
  final unit = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
  final ratio = target / unit;
  final multiplier = ratio <= 1
      ? 1
      : ratio <= 2
      ? 2
      : ratio <= 5
      ? 5
      : 10;
  final step = math.max(1, (unit * multiplier).ceil());
  return (step: step, max: (largest / step).ceil() * step);
}

class PublicBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;
  final bool vertical;
  const PublicBarChart({
    super.key,
    required this.entries,
    required this.color,
    this.vertical = false,
  });
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('Belum ada data.');
    final scale = publicChartScale(
      entries.fold(0, (int m, e) => math.max(m, e.value)),
    );
    return LayoutBuilder(
      builder: (context, box) =>
          vertical &&
              box.maxWidth >= 850 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18.2
          ? _columns(context, scale)
          : _rows(context, scale),
    );
  }

  Widget _bar(
    BuildContext context,
    int value,
    int max, {
    required bool vertical,
  }) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value / max),
    duration: PublicUi.duration(context, 400),
    curve: Curves.easeOutCubic,
    builder: (_, fraction, child) => Align(
      alignment: vertical ? Alignment.bottomCenter : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: vertical ? null : fraction,
        heightFactor: vertical ? fraction : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SizedBox(
            width: vertical ? 40 : null,
            height: vertical ? null : 18,
          ),
        ),
      ),
    ),
  );
  Widget _rows(BuildContext context, ({int step, int max}) scale) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${e.key}: ${e.value} pohon',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 24,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _Grid(scale.max ~/ scale.step),
                      ),
                    ),
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: _bar(
                          context,
                          e.value,
                          scale.max,
                          vertical: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var n = 0; n <= scale.max; n += scale.step)
            Text(
              '$n',
              style: const TextStyle(fontSize: 12, color: PublicUi.muted),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Jumlah pohon',
        style: TextStyle(fontSize: 12, color: PublicUi.muted),
      ),
    ],
  );
  Widget _columns(BuildContext context, ({int step, int max}) scale) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SizedBox(
          width: 40,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var n = scale.max; n >= 0; n -= scale.step)
                Text(
                  '$n',
                  style: const TextStyle(fontSize: 12, color: PublicUi.muted),
                ),
            ],
          ),
        ),
      ),
      Expanded(
        child: Column(
          children: [
            SizedBox(
              height: 224,
              child: Stack(
                children: [
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _Grid(scale.max ~/ scale.step, horizontal: true),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        for (final e in entries)
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: ExcludeSemantics(
                                    child: _bar(
                                      context,
                                      e.value,
                                      scale.max,
                                      vertical: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 200 * e.value / scale.max + 4,
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    '${e.value}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  Expanded(
                    child: Semantics(
                      label: '${e.key}: ${e.value} pohon',
                      child: Text(
                        e.key,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _Grid extends CustomPainter {
  final int intervals;
  final bool horizontal;
  _Grid(this.intervals, {this.horizontal = false});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PublicUi.border
      ..strokeWidth = 1;
    for (var i = 0; i <= intervals; i++) {
      final t = i / intervals;
      canvas.drawLine(
        horizontal ? Offset(0, size.height * t) : Offset(size.width * t, 0),
        horizontal
            ? Offset(size.width, size.height * t)
            : Offset(size.width * t, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Grid old) =>
      old.intervals != intervals || old.horizontal != horizontal;
}