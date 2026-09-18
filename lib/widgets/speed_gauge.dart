import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A dot-arc speed gauge — two symmetric crescents of dots flanking
/// the big speed number, filling outward from the bottom as speed
/// increases relative to the bike's real top speed. This is a
/// functional speed indicator, not decoration: the number of lit
/// dots on each side is literally speedKmh / maxSpeedKmh.
class SpeedGauge extends StatelessWidget {
  final double speedKmh;
  final double maxSpeedKmh;
  final double size;

  const SpeedGauge({
    super.key,
    required this.speedKmh,
    required this.maxSpeedKmh,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxSpeedKmh > 0 ? (speedKmh / maxSpeedKmh).clamp(0.0, 1.0) : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size * 0.82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * 0.82),
            painter: _DotArcPainter(
              fraction: fraction,
              filledColor: scheme.primary,
              unfilledColor: scheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedKmh.toStringAsFixed(0),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 72,
                      height: 1,
                      color: scheme.onSurface,
                    ),
              ),
              Text(
                'km/h',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotArcPainter extends CustomPainter {
  final double fraction; // 0..1 of max speed
  final Color filledColor;
  final Color unfilledColor;

  static const _dotsPerSide = 9;
  static const _dotRadius = 4.0;
  // Screen-angle convention here: 0 rad = right, angle increases
  // clockwise (since canvas y grows downward), so 90 deg = bottom,
  // 180 deg = left, 270 deg = top. The left arc sweeps from just past
  // bottom up to just past top on the left side; the right arc is its
  // mirror image (reflected across the vertical axis: angle -> 180 - angle).
  static const _arcStartDeg = 100.0;
  static const _arcEndDeg = 255.0;

  _DotArcPainter({
    required this.fraction,
    required this.filledColor,
    required this.unfilledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width / 2 - _dotRadius - 2;
    final filledCount = (fraction * _dotsPerSide).round();

    for (var i = 0; i < _dotsPerSide; i++) {
      final t = i / (_dotsPerSide - 1);
      final leftDeg = _arcStartDeg + t * (_arcEndDeg - _arcStartDeg);
      final rightDeg = 180 - leftDeg;
      final isFilled = i < filledCount;
      final paint = Paint()..color = isFilled ? filledColor : unfilledColor;

      for (final deg in [leftDeg, rightDeg]) {
        final rad = deg * math.pi / 180;
        final point = Offset(
          center.dx + radius * math.cos(rad),
          center.dy + radius * math.sin(rad),
        );
        canvas.drawCircle(point, _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotArcPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.filledColor != filledColor;
}
