import 'package:flutter/material.dart';

/// Big hero number for current speed — the visual focal point of the
/// active ride screen, same weight/prominence as the reference
/// screenshot's big percentage number. (The decorative dot-arcs
/// flanking that number are left out here — purely ornamental, not
/// worth the added custom-paint complexity for a live-updating value
/// that redraws every GPS sample.)
class SpeedHero extends StatelessWidget {
  final double speedKmh;

  const SpeedHero({super.key, required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          speedKmh.toStringAsFixed(0),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 88,
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
    );
  }
}
