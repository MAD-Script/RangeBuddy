import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A horizontal battery silhouette with an animated liquid-style fill —
/// the visual expression of the "software energy tank" model. Deliberately
/// not a generic circular ring: this app's whole premise is a tank of
/// energy you're tracking by calculation, not a percentage the hardware
/// hands you, so the gauge should look like what it actually is.
class BatteryTankGauge extends StatelessWidget {
  final double percent; // 0-100
  final String? rangeLabel; // e.g. "38 km remaining"
  final bool isEstimateUncertain; // widen the confidence band visually

  const BatteryTankGauge({
    super.key,
    required this.percent,
    this.rangeLabel,
    this.isEstimateUncertain = false,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    final color = TankColors.forPercent(clamped);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 120.0;
        const nubWidth = 14.0;
        const nubHeight = 40.0;
        final bodyWidth = width - nubWidth;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Battery body outline
                  Positioned(
                    left: 0,
                    child: Container(
                      width: bodyWidth,
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: clamped / 100),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return FractionallySizedBox(
                                widthFactor: value,
                                heightFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Battery nub
                  Positioned(
                    left: bodyWidth,
                    child: Container(
                      width: nubWidth,
                      height: nubHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  // Percentage overlay
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${clamped.toStringAsFixed(0)}%'
                            '${isEstimateUncertain ? '~' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (rangeLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                rangeLabel!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}
