import 'package:flutter/material.dart';

/// Shared press-down scale wrapper (premium tap feel).
/// Single detector: press down/up drives the scale, [onTap] fires
/// on tap-up. Nesting a second tap detector inside swallows taps,
/// so this widget IS the tap handler — don't wrap it in another
/// GestureDetector with onTap.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: widget.scale,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.value = widget.scale,
      onTapUp: (_) => _c.value = 1.0,
      onTapCancel: () => _c.value = 1.0,
      onTap: () {
        _c.value = 1.0;
        widget.onTap?.call();
      },
      behavior: widget.behavior,
      child: ScaleTransition(scale: _c, child: widget.child),
    );
  }
}
