import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Two concentric dot tracks frame the speed like the reference. They advance
/// from left to right as speed approaches the 60 km/h display ceiling.
class SpeedGauge extends StatelessWidget {
  final double speedKmh;
  final double maxSpeedKmh;
  final double size;

  const SpeedGauge({
    super.key,
    required this.speedKmh,
    this.maxSpeedKmh = 60,
    this.size = 288,
  });

  @override
  Widget build(BuildContext context) {
    final speed = speedKmh.clamp(0, maxSpeedKmh).toDouble();
    final mode = speed <= 40 ? 'ECO' : speed <= 45 ? 'CITY' : 'SPORT';
    final modeColor = speed <= 40
        ? const Color(0xFF35A982)
        : speed <= 45
            ? const Color(0xFF2C9FCC)
            : speed <= 55
                ? const Color(0xFFF1A33B)
                : const Color(0xFFE35B54);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * .86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size * .86),
                painter: _TwoTrackDotArchPainter(
                  fraction: speed / maxSpeedKmh,
                  unfilledColor: scheme.outlineVariant.withValues(alpha: .28),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speedKmh.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: size * .31,
                          height: 1,
                          letterSpacing: -2,
                        ),
                  ),
                  Text(
                    'KM/H',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: modeColor.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$mode MODE',
            style: TextStyle(
              color: modeColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TwoTrackDotArchPainter extends CustomPainter {
  final double fraction;
  final Color unfilledColor;

  static const _dotsPerTrack = 9;
  static const _dotRadius = 4.7;

  _TwoTrackDotArchPainter({
    required this.fraction,
    required this.unfilledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .52);
    final filled = (fraction.clamp(0, 1) * _dotsPerTrack * 4).round();
    var dotIndex = 0;

    for (final side in [-1, 1]) {
      for (var i = 0; i < _dotsPerTrack; i++) {
        for (final radius in [size.width * .37, size.width * .45]) {
          final t = i / (_dotsPerTrack - 1);
          final degrees = side < 0 ? 112 + (128 * t) : 300 + (128 * t);
          final radians = degrees * math.pi / 180;
          canvas.drawCircle(
            Offset(
              center.dx + radius * math.cos(radians),
              center.dy + radius * math.sin(radians),
            ),
            _dotRadius,
            Paint()..color = _speedColorForDot(dotIndex, filled),
          );
          dotIndex++;
        }
      }
    }
  }

  Color _speedColorForDot(int index, int filled) {
    if (index >= filled) return unfilledColor;
    final speedAtDot = ((index + 1) / (_dotsPerTrack * 4)) * 60;
    if (speedAtDot > 55) return const Color(0xFFE35B54);
    if (speedAtDot > 45) return const Color(0xFFF1A33B);
    if (speedAtDot > 40) return const Color(0xFF2C9FCC);
    return const Color(0xFF35A982);
  }

  @override
  bool shouldRepaint(covariant _TwoTrackDotArchPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.unfilledColor != unfilledColor;
}
