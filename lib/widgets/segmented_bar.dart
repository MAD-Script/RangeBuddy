import 'package:flutter/material.dart';

/// Slanted energy segments inspired by the reference dashboard.
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: scheme.onSurfaceVariant,
              ),
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
                  height: 28,
                  child: ClipPath(
                    clipper: const _TrapezoidClipper(),
                    child: ColoredBox(
                      color: i < filled
                          ? color
                          : scheme.surfaceContainerHighest,
                    ),
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
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _TrapezoidClipper extends CustomClipper<Path> {
  const _TrapezoidClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .16, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width * .84, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _TrapezoidClipper oldClipper) => false;
}
