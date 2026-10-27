import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';

/// Compact premium "Welcome to OXRO" notification shown once on Home.
///
/// Fades/scales in, holds for ~6 seconds so the copy is easy to read,
/// plays a lightweight petal + confetti + sparkle burst, then fades
/// out automatically (no tap required).
class WelcomePopup extends StatefulWidget {
  const WelcomePopup({required this.onDismissed, super.key});

  /// Called once the fade-out completes.
  final VoidCallback onDismissed;

  @override
  State<WelcomePopup> createState() => _WelcomePopupState();
}

class _WelcomePopupState extends State<WelcomePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _visible = false;
  bool _fadeStarted = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _life,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOutBack),
      ),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _life,
            curve: const Interval(0.0, 0.12, curve: Curves.easeOutCubic),
          ),
        );
    _life.addListener(_onLifeTick);
    _life.forward();

    // Start the implicit fade-in after the first frame so the
    // initial opacity is genuinely 0.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  void _onLifeTick() {
    if (_fadeStarted || !mounted) return;
    if (_life.value >= 0.9) {
      _fadeStarted = true;
      setState(() => _visible = false);
    }
  }

  void _handleFadeEnd() {
    if (_visible || _dismissed) return;
    _dismissed = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _life.removeListener(_onLifeTick);
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final fadeDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 600);
    final scale = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1.0)
        : _scale;
    final slide = reduceMotion
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : _slide;

    return AnimatedOpacity(
      key: const ValueKey('welcome_popup'),
      opacity: _visible ? 1.0 : 0.0,
      duration: fadeDuration,
      curve: Curves.easeOut,
      onEnd: _handleFadeEnd,
      child: IgnorePointer(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'Welcome to OXRO. Your Shopping Journey Starts Here!',
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      Color(0x4A2A0714),
                      Color(0x0F2A0714),
                      Color(0x002A0714),
                    ],
                  ),
                ),
              ),
              if (!reduceMotion)
                RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('welcome_particles'),
                    painter: _CelebrationPainter(progress: _life),
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(
                        scale: scale,
                        child: _WelcomeCard(
                          animation: _life,
                          animate: !reduceMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.animation, required this.animate});

  final Animation<double> animation;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('welcome_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OxroColors.premiumCream, OxroColors.premiumCreamDeep],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: OxroColors.premiumChampagne, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: OxroColors.premiumBurgundy.withValues(alpha: 0.22),
            blurRadius: 50,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.6),
        child: Stack(
          children: [
            Positioned(
              top: -42,
              right: -18,
              child: Text(
                'O',
                style: TextStyle(
                  fontSize: 150,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: OxroColors.premiumBurgundy.withValues(alpha: 0.045),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: OxroColors.premiumChampagne.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingBadge(animation: animation, animate: animate),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to OXRO 🛍️',
                      key: ValueKey('welcome_title'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.premiumBurgundy,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Shopping Journey Starts Here!',
                      key: ValueKey('welcome_subtitle'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: OxroColors.premiumMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _GoldOrnament(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Twin champagne hairlines around a rotated gold diamond.
class _GoldOrnament extends StatelessWidget {
  const _GoldOrnament();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _goldLine(reverse: true),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [OxroColors.gold, OxroColors.premiumChampagne],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _goldLine(reverse: false),
      ],
    );
  }

  Widget _goldLine({required bool reverse}) {
    final colors = reverse
        ? [OxroColors.premiumChampagne.withValues(alpha: 0), OxroColors.gold]
        : [OxroColors.gold, OxroColors.premiumChampagne.withValues(alpha: 0)];
    return Container(
      width: 44,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Burgundy shopping badge with a champagne ring, gentle pulse + glow.
class _PulsingBadge extends StatelessWidget {
  const _PulsingBadge({required this.animation, required this.animate});

  final Animation<double> animation;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = math.sin(animation.value * math.pi * 8);
        final scale = animate ? 1.0 + 0.055 * wave : 1.0;
        final glow = animate ? 0.26 + 0.10 * (0.5 + 0.5 * wave) : 0.32;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [OxroColors.premiumWine, OxroColors.premiumBurgundy],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: OxroColors.premiumChampagne.withValues(alpha: 0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.premiumBurgundy.withValues(alpha: glow),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: OxroColors.premiumChampagne.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.shopping_bag_rounded,
        size: 30,
        color: OxroColors.premiumChampagne,
      ),
    );
  }
}

/// Lightweight celebration painter: flower petals, confetti and
/// golden sparkles arranged around the centered card.
class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  static const _petalColors = [
    Color(0xFFE6C79C),
    Color(0xFFC65C7A),
    Color(0xFFF1D79A),
  ];

  static const _confettiColors = [
    OxroColors.premiumBurgundy,
    OxroColors.gold,
    OxroColors.premiumRose,
    OxroColors.premiumChampagne,
    OxroColors.premiumWine,
  ];

  static const _gold = OxroColors.gold;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;

    final center = size.center(Offset.zero);
    final fade = 1 - ((t - 0.86) / 0.14).clamp(0.0, 1.0);

    _paintPetals(canvas, center, t, fade);
    _paintConfetti(canvas, center, t, fade);
    _paintSparkles(canvas, center, t, fade);
  }

  void _paintPetals(Canvas canvas, Offset center, double t, double fade) {
    final paint = Paint();
    const count = 9;

    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i - math.pi / 2 + t * 1.1;
      final rx = 164 + 28 * t + (i % 2) * 12;
      final ry = 128 + 24 * t;
      final pos = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry,
      );
      final petalSize = 6.0 + (i % 3) * 1.7;
      final rotation = angle + t * 0.9;
      final alpha = (0.9 * fade).clamp(0.0, 1.0);

      for (var k = 0; k < 5; k++) {
        final petalAngle = rotation + (math.pi * 2 / 5) * k;
        final petalCenter =
            pos +
            Offset(math.cos(petalAngle), math.sin(petalAngle)) *
                petalSize *
                0.85;
        paint.color = _petalColors[i % _petalColors.length].withValues(
          alpha: alpha,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: petalCenter,
            width: petalSize * 1.5,
            height: petalSize,
          ),
          paint,
        );
      }

      paint.color = _gold.withValues(alpha: alpha);
      canvas.drawCircle(pos, petalSize * 0.5, paint);
    }
  }

  void _paintConfetti(Canvas canvas, Offset center, double t, double fade) {
    final paint = Paint();
    const count = 22;

    for (var i = 0; i < count; i++) {
      final seed = (i * 0.61803398875) % 1.0;
      final angle = (math.pi * 2 / count) * i + seed * 1.4;
      final spread = 0.6 + (i % 4) * 0.09 + t * 0.55;
      final rx = 164 * spread;
      final ry = 126 * spread;
      final pos = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry + seed * 22 * t,
      );
      final width = 4.5 + (i % 4) * 1.4;
      final alpha = (0.85 * fade).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + t * 3.6 + seed * 5);
      paint.color = _confettiColors[i % _confettiColors.length].withValues(
        alpha: alpha,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: width * 2.1,
            height: width,
          ),
          const Radius.circular(1.2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintSparkles(Canvas canvas, Offset center, double t, double fade) {
    final paint = Paint();
    const count = 16;

    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i + 0.25 + t * 0.5;
      final rx = 176 + (i % 4) * 10 + 12 * t;
      final ry = 138 + (i % 3) * 9 + 10 * t;
      final pos = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry,
      );
      final twinkle = 0.45 + 0.55 * math.sin((t * 9 + i) * math.pi).abs();
      final alpha = (fade * twinkle).clamp(0.0, 1.0);
      final radius = 3.2 + (i % 3) * 1.6;

      paint.color = _gold.withValues(alpha: alpha);
      canvas.drawPath(_starPath(pos, radius), paint);
    }
  }

  Path _starPath(Offset center, double radius) {
    final inner = radius * 0.28;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + inner, center.dy - inner)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + inner, center.dy + inner)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - inner, center.dy + inner)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - inner, center.dy - inner)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
