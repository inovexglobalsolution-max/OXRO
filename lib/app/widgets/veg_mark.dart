import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';

class VegMark extends StatelessWidget {
  const VegMark({super.key, required this.veg, this.egg = false, this.size = 16});

  final bool veg;
  final bool egg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = veg
        ? OxroColors.vegGreen
        : egg
        ? OxroColors.eggAmber
        : OxroColors.nonVegRed;
    return Semantics(
      label: veg ? 'Vegetarian' : (egg ? 'Contains egg' : 'Non vegetarian'),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: veg || egg
            ? Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              )
            : CustomPaint(
                size: Size(size * 0.56, size * 0.56),
                painter: _TrianglePainter(color),
              ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
