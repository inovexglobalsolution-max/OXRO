import 'package:flutter/material.dart';

/// Responsive helpers — all phones 320..430 + tablet, no package.
/// Base design width 390 (iPhone 14). Scales clamped to avoid extremes.
extension RespX on BuildContext {
  double get w => MediaQuery.sizeOf(this).width;
  double get h => MediaQuery.sizeOf(this).height;

  bool get isSmallPhone => w < 360;
  bool get isLargePhone => w >= 420;
  bool get isTablet => w >= 600;
  bool get isShortScreen => h < 640;

  /// Scale factor 0.85..1.2 based on width.
  double get _s => (w / 390).clamp(0.85, 1.2);

  /// Responsive size for icons, boxes, radius.
  double rs(double v) => v * _s;

  /// Responsive font — respects system text scale, clamped 0.85..1.3.
  double font(double v) {
    final sys = MediaQuery.textScalerOf(this).scale(1);
    return v * _s * sys.clamp(0.85, 1.15);
  }

  /// Page horizontal padding: 20 on 390, scales.
  double get padX => w * 0.0513; // ~20 @390

  /// Max content width for tablet — center column.
  double get maxContentW => isTablet ? 520 : double.infinity;

  /// Button height 52..60.
  double get btnH => (h * 0.07).clamp(52.0, 60.0);
}
