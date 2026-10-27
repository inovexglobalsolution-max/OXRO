import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = OxroColors.border,
    this.dash = 4,
    this.gap = 4,
  });

  final double height;
  final Color color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(
          color: color,
          dash: dash,
          gap: gap,
          strokeWidth: height,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, strokeWidth / 2),
          Offset((x + dash).clamp(0, size.width),
              strokeWidth / 2),
          paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}
