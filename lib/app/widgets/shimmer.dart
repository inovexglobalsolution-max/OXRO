import 'package:flutter/material.dart';

/// Shared shimmer pulse for loading skeletons (premium loading feel).
/// Opacity breathes 0.45 ↔ 1.0 on a 900ms loop. Sizes mirror the
/// content they stand in for so grids never jump on load.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.borderRadius,
    this.color = const Color(0xFFE2E6EA),
  });

  final double? width;
  final double? height;
  final double radius;
  final BorderRadiusGeometry? borderRadius;
  final Color color;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.45,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}
