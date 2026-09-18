import 'package:flutter/material.dart';

/// A segmented pill-style progress bar — a row of rounded blocks,
/// filled up to [fraction] in [color], the rest dimmed. Used for
/// Charge Left / Range Left on the active ride screen.
class SegmentedBar extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double fraction; // 0..1
  final Color color;
  final int segmentCount;
  final IconData? icon;

  const SegmentedBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.fraction,
    required this.color,
    this.segmentCount = 10,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final filled = (fraction.clamp(0, 1) * segmentCount).round();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < segmentCount; i++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: i == segmentCount - 1 ? 0 : 4,
                  ),
                  height: 20,
                  decoration: BoxDecoration(
                    color: i < filled ? color : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          valueLabel,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
