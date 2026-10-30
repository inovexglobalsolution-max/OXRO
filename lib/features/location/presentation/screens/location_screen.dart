import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/address/presentation/widgets/address_sheet.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/location/data/geo_store.dart';

/// Location onboarding — white page, isometric food-city art, device
/// location and manual address actions (reference 2.jpg).
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _locating = false;

  void _goLogin() {
    replaceScreen(context, const LoginScreen());
  }

  Future<void> _enableLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      await GeoStore.instance.detect(force: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (!mounted) return;
    if (GeoStore.instance.place.source == GeoSource.fallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location unavailable. Allow device location or enter it manually.',
          ),
        ),
      );
      return;
    }
    _goLogin();
  }

  Future<void> _enterManually() async {
    final saved = await AddressSheet.open(context);
    if (saved && mounted) _goLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('location_screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.maxContentW),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.padX),
              child: Column(
                children: [
                  SizedBox(height: context.rs(56)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
                    child: Text(
                      'Set your location to start\nexploring\nrestaurants near you',
                      key: const ValueKey('location_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.font(27),
                        height: 1.22,
                        fontWeight: FontWeight.w600,
                        color: OxroColors.charcoal,
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(6)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: context.rs(4)),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 360,
                          height: 360,
                          child: _CityArt(
                            key: const ValueKey('location_city_art'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: context.btnH.clamp(52.0, 60.0),
                    child: FilledButton(
                      key: const ValueKey('location_enable'),
                      onPressed: _locating ? null : _enableLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: OxroColors.coral,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: OxroColors.coral.withValues(
                          alpha: 0.7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _locating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Enable Device Location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font(19),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: context.rs(14)),
                  SizedBox(
                    width: double.infinity,
                    height: context.btnH.clamp(52.0, 60.0),
                    child: OutlinedButton(
                      key: const ValueKey('location_manual'),
                      onPressed: _enterManually,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OxroColors.coral,
                        side: const BorderSide(
                          color: OxroColors.coral,
                          width: 1.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Enter Your Location Manually',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(19),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Isometric food-city illustration assembled from a painted city and
/// three small food kiosks around a red location pin.
class _CityArt extends StatefulWidget {
  const _CityArt({super.key});

  @override
  State<_CityArt> createState() => _CityArtState();
}

class _CityArtState extends State<_CityArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _bob,
          builder: (context, _) {
            final lift = -4 * math.sin(_bob.value * math.pi);
            final shadow = 22.0 - 2.5 * _bob.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _CityPainter()),
                ),
                Positioned(
                  left: w * 0.08,
                  top: h * 0.53,
                  child: const _FoodKiosk(
                    icon: Icons.lunch_dining_rounded,
                    accent: Color(0xFFF0A23D),
                    awning: Color(0xFFB8742C),
                    width: 70,
                    height: 60,
                  ),
                ),
                Positioned(
                  left: w * 0.74,
                  top: h * 0.47,
                  child: const _FoodKiosk(
                    icon: Icons.local_pizza_rounded,
                    accent: Color(0xFFF2C64B),
                    awning: Color(0xFFD95B4A),
                    width: 62,
                    height: 56,
                  ),
                ),
                Positioned(
                  left: w * 0.41,
                  top: h * 0.75,
                  child: const _FoodKiosk(
                    icon: Icons.kebab_dining_rounded,
                    accent: Color(0xFFF2B45C),
                    awning: Color(0xFFE45757),
                    width: 76,
                    height: 62,
                  ),
                ),
                Positioned(
                  left: w / 2 - 26,
                  top: h * 0.50 + lift + 33,
                  child: Container(
                    width: 52,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE45560).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  left: w / 2 - 30,
                  top: h * 0.45 + lift,
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 60,
                    color: const Color(0xFFF0545E),
                    shadows: [
                      Shadow(
                        color: const Color(0xFFF0545E).withValues(alpha: 0.32),
                        blurRadius: shadow,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FoodKiosk extends StatelessWidget {
  const _FoodKiosk({
    required this.icon,
    required this.accent,
    required this.awning,
    required this.width,
    required this.height,
  });

  final IconData icon;
  final Color accent;
  final Color awning;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            top: 14,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFFF2DFC0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            height: height * 0.48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: height * 0.5,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 1.5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? accent.withValues(alpha: 0.55)
                            : Colors.white,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 7,
            height: 14,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: i.isEven ? awning : const Color(0xFFFFF4DC),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: width * 0.18,
            top: height * 0.18,
            child: Container(
              width: width * 0.64,
              height: height * 0.34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Icon(icon, size: width * 0.3, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft white/grey isometric city with roads and trees. Kept deliberately
/// pale so the coloured kiosks and red pin stay dominant (ref 2.jpg).
class _CityPainter extends CustomPainter {
  const _CityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final road = Paint()
      ..color = const Color(0xFFF0F3F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final roadEdge = Paint()
      ..color = const Color(0xFFF8FAFB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathA = Path()
      ..moveTo(w * 0.02, h * 0.76)
      ..cubicTo(w * 0.20, h * 0.68, w * 0.30, h * 0.64, w * 0.48, h * 0.66)
      ..cubicTo(w * 0.66, h * 0.68, w * 0.78, h * 0.60, w * 0.98, h * 0.50);
    final pathB = Path()
      ..moveTo(w * 0.20, h * 0.98)
      ..cubicTo(w * 0.28, h * 0.80, w * 0.34, h * 0.62, w * 0.42, h * 0.44)
      ..cubicTo(w * 0.48, h * 0.28, w * 0.50, h * 0.18, w * 0.53, h * 0.04);
    for (final p in [pathA, pathB]) {
      canvas.drawPath(p, roadEdge);
      canvas.drawPath(p, road);
    }

    final buildings = <_Building>[
      _Building(0.35, 0.39, 0.085, 0.115, 0.030, 0.99),
      _Building(0.45, 0.36, 0.105, 0.145, 0.038, 0.96),
      _Building(0.57, 0.39, 0.075, 0.105, 0.030, 0.92),
      _Building(0.64, 0.41, 0.090, 0.085, 0.026, 0.97),
      _Building(0.30, 0.47, 0.095, 0.070, 0.026, 0.94),
      _Building(0.52, 0.47, 0.080, 0.060, 0.024, 0.90),
      _Building(0.17, 0.56, 0.080, 0.080, 0.026, 0.96),
      _Building(0.28, 0.58, 0.100, 0.055, 0.024, 0.91),
      _Building(0.66, 0.55, 0.100, 0.070, 0.028, 0.95),
      _Building(0.78, 0.59, 0.070, 0.055, 0.024, 0.90),
      _Building(0.55, 0.58, 0.075, 0.045, 0.020, 0.88),
      _Building(0.36, 0.68, 0.075, 0.050, 0.022, 0.93),
    ];
    for (final b in buildings) {
      _drawBuilding(canvas, w, h, b);
    }

    const trees = [
      Offset(0.13, 0.45),
      Offset(0.22, 0.42),
      Offset(0.72, 0.38),
      Offset(0.86, 0.50),
      Offset(0.13, 0.69),
      Offset(0.24, 0.75),
      Offset(0.62, 0.72),
      Offset(0.80, 0.70),
      Offset(0.90, 0.63),
      Offset(0.32, 0.82),
      Offset(0.56, 0.85),
    ];
    for (var i = 0; i < trees.length; i++) {
      _drawTree(canvas, w, h, trees[i], 7.0 + (i % 3) * 1.8);
    }

    final cloud = Paint()
      ..color = const Color(0xFFF1F4F7)
      ..style = PaintingStyle.fill;
    for (final c in const [Offset(0.18, 0.23), Offset(0.84, 0.27)]) {
      final cx = w * c.dx;
      final cy = h * c.dy;
      canvas.drawCircle(Offset(cx, cy), 8, cloud);
      canvas.drawCircle(Offset(cx + 10, cy + 2), 6, cloud);
      canvas.drawCircle(Offset(cx - 9, cy + 3), 5, cloud);
    }
  }

  void _drawBuilding(Canvas canvas, double w, double h, _Building b) {
    final x = w * b.x;
    final y = h * b.y;
    final bw = w * b.w;
    final bh = h * b.h;
    final d = w * b.d;

    final top = Path()
      ..moveTo(x, y)
      ..lineTo(x + d, y - d)
      ..lineTo(x + bw + d, y - d)
      ..lineTo(x + bw, y)
      ..close();
    final right = Path()
      ..moveTo(x + bw, y)
      ..lineTo(x + bw + d, y - d)
      ..lineTo(x + bw + d, y + bh - d)
      ..lineTo(x + bw, y + bh)
      ..close();
    final front = Rect.fromLTWH(x, y, bw, bh);

    canvas.drawPath(
      top,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFFFFFFF),
          const Color(0xFFE9EEF3),
          b.shade,
        )!,
    );
    canvas.drawPath(right, Paint()..color = const Color(0xFFDDE5EC));
    canvas.drawRect(front, Paint()..color = const Color(0xFFF5F8FA));

    final win = Paint()..color = const Color(0xFFE1E8EE);
    for (var i = 0; i < 3; i++) {
      final wy = y + 6 + i * (bh / 4);
      if (wy + 4 > y + bh - 3) break;
      canvas.drawRect(Rect.fromLTWH(x + bw * 0.18, wy, bw * 0.64, 3.4), win);
    }
    final winSide = Paint()..color = const Color(0xFFD3DEE7);
    for (var i = 0; i < 2; i++) {
      final wy = y - d + 8 + i * (bh / 3);
      final sx = x + bw + d * 0.25;
      canvas.drawRect(Rect.fromLTWH(sx, wy, d * 0.38, 2.8), winSide);
    }
  }

  void _drawTree(Canvas canvas, double w, double h, Offset p, double r) {
    final x = w * p.dx;
    final y = h * p.dy;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, y + r * 0.5, 2, r * 1.2),
      Paint()..color = const Color(0xFFD9E0E7),
    );
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()..color = const Color(0xFFE4EAEF),
    );
    canvas.drawCircle(
      Offset(x - r * 0.25, y - r * 0.25),
      r * 0.55,
      Paint()..color = const Color(0xFFF0F4F7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Building {
  const _Building(this.x, this.y, this.w, this.h, this.d, this.shade);

  final double x;
  final double y;
  final double w;
  final double h;
  final double d;
  final double shade;
}
