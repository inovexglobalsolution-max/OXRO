import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/location/data/geo_store.dart';

/// 03 Country / Location — matches referencer 03 (white, India card,
/// deliver line, flat India-map illustration, solid Continue).
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    // GPS → IP cascade in the background (silent India fallback).
    GeoStore.instance.detect();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _continue() {
    replaceScreen(context, const LoginScreen());
  }

  /// Slow-rising ambient dot (deterministic slot, phase offset).
  Widget _floatDot(int i, double a) {
    const xs = [0.15, 0.28, 0.72, 0.85, 0.5, 0.62];
    const ys = [0.3, 0.55, 0.32, 0.58, 0.2, 0.68];
    final drift = 8 * math.sin(a * math.pi * 2 + i * 1.1);
    final colors = [
      OxroColors.primary,
      OxroColors.royalBlue,
      OxroColors.skyBlue,
    ];
    return Positioned(
      left: context.w * xs[i % xs.length],
      top: context.rs(200) * ys[i % ys.length] + drift,
      child: Opacity(
        opacity: (0.35 + 0.25 * a).clamp(0.0, 0.7),
        child: Container(
          width: 7 - (i % 3) * 1.5,
          height: 7 - (i % 3) * 1.5,
          decoration: BoxDecoration(
            color: colors[i % colors.length],
            shape: i.isEven
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: i.isEven
                ? null
                : BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: context.maxContentW),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.rs(18)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.padX + 4),
                  child: Text(
                    'Where do you want\nto receive your orders?',
                    style: TextStyle(
                      fontSize: context.font(24),
                      fontWeight: FontWeight.w800,
                      color: OxroColors.dark,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: context.rs(8)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.padX + 4),
                  child: Text(
                    'Select delivery location',
                    style: TextStyle(
                        fontSize: context.font(13.5),
                        color: OxroColors.muted),
                  ),
                ),
                SizedBox(height: context.rs(14)),
                // Country selector card (auto-detected, India fallback).
                ListenableBuilder(
                  listenable: GeoStore.instance,
                  builder: (context, _) {
                    final geo = GeoStore.instance;
                    final detecting = geo.detecting &&
                        geo.place.source ==
                            GeoSource.fallback;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.padX),
                      child: Container(
                        key: const ValueKey(
                            'location_country_card'),
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: OxroColors.border),
                        ),
                        child: Row(
                          children: [
                            const _FlagBadge(
                                key: ValueKey(
                                    'location_flag')),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  geo.place.countryName,
                                  key: const ValueKey(
                                      'location_country'),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: OxroColors
                                          .charcoal)),
                            ),
                            if (detecting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: context.rs(10)),
                // Deliver line (detected city when known).
                ListenableBuilder(
                  listenable: GeoStore.instance,
                  builder: (context, _) {
                    final geo = GeoStore.instance;
                    final city =
                        (geo.city ?? '').trim();
                    final line = city.isNotEmpty
                        ? 'Delivering to ${geo.place.displayLine}'
                        : 'We deliver across India';
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.padX + 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16,
                              color: OxroColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              line,
                              key: const ValueKey(
                                  'location_deliver'),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: OxroColors.muted,
                                  fontWeight:
                                      FontWeight.w500)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: context.rs(8)),
                // Animated illustration (ref: city + peach India +
                // red pin + boxes) with ambient life: breathing glow,
                // floating dots, elastic pin, drifting parcels + truck.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.padX),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_anim, _ambient]),
                      builder: (context, _) {
                        final t = _anim.value;
                        final a = _ambient.value;
                        final bounce = -10 *
                                math.sin(
                                    t * math.pi * 2) *
                                math.sin(
                                    t * math.pi * 2)
                                .abs() +
                            2;
                        final breathe =
                            1.0 + 0.03 * math.sin(a * math.pi * 2);
                        final glowA =
                            0.10 + 0.04 * a;
                        return CustomPaint(
                          painter: _CityPainter(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Breathing glow behind map.
                              Container(
                                width: context.rs(220) *
                                    breathe,
                                height: context.rs(220) *
                                    breathe,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: OxroColors.primary
                                      .withValues(
                                          alpha: glowA *
                                              0.5),
                                ),
                              ),
                              // Floating ambient dots.
                              for (var i = 0;
                                  i < 6;
                                  i++)
                                _floatDot(i, a),
                              Transform.scale(
                                scale: breathe,
                                child: CustomPaint(
                                  size: Size(
                                      context.w,
                                      context.rs(220)),
                                  painter:
                                      _IndiaPainter(),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, bounce),
                                child: Icon(
                                  Icons.location_on,
                                  size: context.rs(64),
                                  color:
                                      const Color(0xFFE11D48),
                                ),
                              ),
                              // Shadow pulses with pin height.
                              Positioned(
                                bottom: context.rs(52),
                                child: Container(
                                  width: 44 -
                                      bounce * 0.8,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(
                                            alpha: 0.12 +
                                                bounce *
                                                    0.004),
                                    borderRadius:
                                        BorderRadius
                                            .circular(6),
                                  ),
                                ),
                              ),
                              // Drifting parcels (phase offset).
                              Positioned(
                                right: context.rs(28),
                                bottom: context.rs(48) +
                                    4 *
                                        math.sin(a *
                                                math.pi *
                                                2 +
                                            1.2),
                                child: _BoxParcel(
                                    size: context.rs(52)),
                              ),
                              Positioned(
                                left: context.rs(30),
                                bottom: context.rs(56) +
                                    4 *
                                        math.sin(a *
                                                math.pi *
                                                2 +
                                            2.6),
                                child: _BoxParcel(
                                    size: context.rs(30)),
                              ),
                              // Mini truck sliding along bottom.
                              Positioned(
                                bottom: context.rs(16),
                                left: context.rs(16) +
                                    (context.w -
                                            context.rs(
                                                90)) *
                                        t *
                                        0.5,
                                child: Opacity(
                                  opacity: (0.55 +
                                          0.35 * a)
                                      .clamp(
                                          0.0, 1.0),
                                  child: const Icon(
                                    Icons
                                        .local_shipping_outlined,
                                    size: 24,
                                    color: OxroColors
                                        .royalBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: context.rs(12)),
                // Solid Continue (ref: solid #FF6A00, not gradient).
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.padX, 0, context.padX, context.rs(16)),
                  child: GestureDetector(
                    onTap: _continue,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: context.btnH,
                      constraints:
                          const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OxroColors.primary,
                        borderRadius: BorderRadius.circular(
                            context.rs(12)),
                      ),
                      child: Text(
                        'Continue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(16),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tricolor flag badge (ref: saffron/white/green + Ashoka chakra).
class _FlagBadge extends StatelessWidget {
  const _FlagBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: OxroColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10051D47),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            const Column(
              children: [
                Expanded(
                    child: ColoredBox(
                        color: Color(0xFFFF9933))),
                Expanded(
                    child:
                        ColoredBox(color: Colors.white)),
                Expanded(
                    child: ColoredBox(
                        color: Color(0xFF138808))),
              ],
            ),
            Center(
              child: CustomPaint(
                size: const Size.square(9),
                painter: _ChakraPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ashoka chakra: navy ring + 12 spokes + hub.
class _ChakraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
        size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFF000080)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(c, r, paint);
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2;
      canvas.drawLine(
          c,
          c + Offset(math.cos(a) * r,
              math.sin(a) * r),
          paint);
    }
    canvas.drawCircle(
        c,
        1,
        Paint()..color = const Color(0xFF000080));
  }

  @override
  bool shouldRepaint(
          covariant CustomPainter oldDelegate) =>
      false;
}

/// Small parcel box (ref: brown boxes beside map).
class _BoxParcel extends StatelessWidget {
  const _BoxParcel({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFFD9A05B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: const Color(0xFFB07C3A)),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: size * 0.14,
              height: size * 0.85,
              color: const Color(0xFFB07C3A)
                  .withValues(alpha: 0.7),
            ),
          ),
          Center(
            child: Container(
              width: size,
              height: size * 0.12,
              color: const Color(0xFFB07C3A)
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFF1F3F5);
    // Faint skyline bars at the bottom (ref: grey city).
    final bars = [0.10, 0.22, 0.16, 0.28, 0.20, 0.14, 0.24, 0.18];
    final bw = size.width / (bars.length * 2);
    for (var i = 0; i < bars.length; i++) {
      final h = size.height * bars[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              i * bw * 2, size.height - h - 20, bw, h),
          const Radius.circular(3),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IndiaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simplified peach India blob (ref: light peach map).
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(cx - 52, cy - 46)
      ..lineTo(cx + 44, cy - 50)
      ..lineTo(cx + 58, cy - 10)
      ..lineTo(cx + 34, cy + 34)
      ..lineTo(cx + 6, cy + 62)
      ..lineTo(cx - 22, cy + 30)
      ..lineTo(cx - 58, cy - 6)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFE3CB)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
