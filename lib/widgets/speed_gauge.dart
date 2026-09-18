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
    this.size = 288,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxSpeedKmh > 0 ? (speedKmh / maxSpeedKmh).clamp(0.0, 1.0) : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size * .9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * .9),
            painter: _DotArcPainter(
              fraction: fraction,
              leftColor: const Color(0xFF35A982),
              rightColor: const Color(0xFF2C9FCC),
              unfilledColor: scheme.outlineVariant.withValues(alpha: .28),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedKmh.toStringAsFixed(0),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: size * .31,
                      height: 1,
                      color: scheme.onSurface,
                    ),
              ),
              Text(
                'KM/H',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.1,
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
  final Color leftColor;
  final Color rightColor;
  final Color unfilledColor;

  static const _dotsPerSide = 11;
  static const _dotRadius = 5.2;
  // Screen-angle convention here: 0 rad = right, angle increases
  // clockwise (since canvas y grows downward), so 90 deg = bottom,
  // 180 deg = left, 270 deg = top. The left arc sweeps from just past
  // bottom up to just past top on the left side; the right arc is its
  // mirror image (reflected across the vertical axis: angle -> 180 - angle).
  static const _arcStartDeg = 92.0;
  static const _arcEndDeg = 258.0;

  _DotArcPainter({
    required this.fraction,
    required this.leftColor,
    required this.rightColor,
    required this.unfilledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Match the paint centre to Stack's centre so the number is literally
    // framed by the live speed dots, with no dots clipped at either edge.
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .44;
    final filledCount = (fraction * _dotsPerSide).round();

    for (var i = 0; i < _dotsPerSide; i++) {
      final t = i / (_dotsPerSide - 1);
      final leftDeg = _arcStartDeg + t * (_arcEndDeg - _arcStartDeg);
      final rightDeg = 180 - leftDeg;
      final isFilled = i < filledCount;
      for (final (deg, color) in [(leftDeg, leftColor), (rightDeg, rightColor)]) {
        final paint = Paint()..color = isFilled ? color : unfilledColor;
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
      oldDelegate.leftColor != leftColor ||
      oldDelegate.rightColor != rightColor ||
      oldDelegate.unfilledColor != unfilledColor;
}
