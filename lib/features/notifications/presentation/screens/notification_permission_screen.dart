import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';

/// Notification permission onboarding (reference 23.jpg, premium pass):
/// delivery character with 4 independently animated notification badges,
/// warm radial glow, staggered entry, orange gradient CTA and "Not Now".
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _enter;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduce) return;
    _reduce = reduce;
    if (reduce) {
      _bob
        ..stop()
        ..value = 0.5;
      _enter.value = 1;
    } else {
      _bob.repeat(reverse: true);
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _continue() {
    replaceScreen(context, const LoginScreen());
  }

  void _enable() {
    NotifStore.instance.setEnabled(true);
    _continue();
  }

  void _skip() {
    NotifStore.instance.setEnabled(false);
    _continue();
  }

  Widget _in(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value.clamp(0.0, 1.0))),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      key: const ValueKey('notif_perm_screen'),
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.72),
            radius: 1.15,
            colors: [
              OxroColors.primary.withValues(alpha: 0.09),
              OxroColors.primary.withValues(alpha: 0.02),
              Colors.white,
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentW),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.padX),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: context.rs(28)),
                    _in(
                      0,
                      0.35,
                      Text(
                        'Get updates on your order status',
                        key: const ValueKey('notif_perm_title'),
                        style: TextStyle(
                          fontSize: context.font(27),
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ),
                    SizedBox(height: context.rs(12)),
                    _in(
                      0.08,
                      0.43,
                      Text(
                        'Allow push notifications to get real-time updates '
                        'on your order status.',
                        key: const ValueKey('notif_perm_sub'),
                        style: TextStyle(
                          fontSize: context.font(15),
                          height: 1.45,
                          color: OxroColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: context.rs(4)),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: _HeroArt(
                              bob: _bob,
                              enter: _enter,
                              reduceMotion: reduceMotion,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _in(
                      0.5,
                      0.85,
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              OxroColors.orangeTop,
                              OxroColors.orangeBottom,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: OxroColors.primary.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: context.btnH.clamp(52.0, 60.0),
                          child: FilledButton(
                            key: const ValueKey('notif_perm_enable'),
                            onPressed: _enable,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Turn on Notification',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font(19),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.rs(6)),
                    _in(
                      0.6,
                      0.95,
                      TextButton(
                        key: const ValueKey('notif_perm_skip'),
                        onPressed: _skip,
                        child: Text(
                          'Not Now',
                          style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w600,
                            color: OxroColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.rs(14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Delivery character with 4 staggered, independently animated
/// notification badges (bell / package / chat / star).
class _HeroArt extends StatelessWidget {
  const _HeroArt({
    required this.bob,
    required this.enter,
    required this.reduceMotion,
  });

  final AnimationController bob;
  final AnimationController enter;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: Listenable.merge([bob, enter]),
          builder: (context, _) {
            final t = reduceMotion ? 0.5 : bob.value;
            final lift = -6 * math.sin(t * math.pi);
            final halo = 0.92 + 0.08 * math.sin(t * math.pi * 2);
            final champ = CurvedAnimation(
              parent: enter,
              curve: const Interval(0.15, 0.5, curve: Curves.easeOutBack),
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: w * 0.5 - 106,
                  top: h * 0.5 - 106,
                  child: Transform.scale(
                    scale: champ.value.clamp(0.0, 1.06) * halo,
                    child: Container(
                      width: 212,
                      height: 212,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OxroColors.premiumChampagne.withValues(
                            alpha: 0.45,
                          ),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: OxroColors.gold.withValues(alpha: 0.10),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.5 - 96,
                  top: h * 0.5 - 96,
                  child: Transform.scale(
                    scale: halo,
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OxroColors.primary.withValues(alpha: 0.14),
                            OxroColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.06,
                  top: h * 0.14 + lift * 1.2,
                  child: _Badge(
                    icon: Icons.notifications_active_rounded,
                    color: OxroColors.primary,
                    size: 44,
                    appear: CurvedAnimation(
                      parent: enter,
                      curve: const Interval(
                        0.2,
                        0.55,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    bobT: t,
                    phase: 0,
                    reduceMotion: reduceMotion,
                  ),
                ),
                Positioned(
                  right: w * 0.04,
                  top: h * 0.22 - lift * 0.9,
                  child: _Badge(
                    icon: Icons.inventory_2_rounded,
                    color: OxroColors.green,
                    size: 40,
                    appear: CurvedAnimation(
                      parent: enter,
                      curve: const Interval(
                        0.3,
                        0.65,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    bobT: t,
                    phase: 1.7,
                    reduceMotion: reduceMotion,
                  ),
                ),
                Positioned(
                  right: w * 0.13,
                  bottom: h * 0.14 + lift * 0.7,
                  child: _Badge(
                    icon: Icons.chat_bubble_rounded,
                    color: const Color(0xFF2563EB),
                    size: 38,
                    appear: CurvedAnimation(
                      parent: enter,
                      curve: const Interval(
                        0.4,
                        0.75,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    bobT: t,
                    phase: 3.4,
                    reduceMotion: reduceMotion,
                  ),
                ),
                Positioned(
                  left: w * 0.1,
                  bottom: h * 0.16 - lift * 0.6,
                  child: _Badge(
                    icon: Icons.star_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 36,
                    appear: CurvedAnimation(
                      parent: enter,
                      curve: const Interval(
                        0.5,
                        0.85,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    bobT: t,
                    phase: 4.9,
                    reduceMotion: reduceMotion,
                  ),
                ),
                Positioned(
                  left: w * 0.5 - 96,
                  top: h * 0.5 - 96,
                  child: Transform.translate(
                    offset: Offset(0, lift * 3),
                    child: Image.asset(
                      'assets/images/delivery_boy_icon.png',
                      width: 192,
                      height: 192,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(
                        Icons.delivery_dining_rounded,
                        size: 120,
                        color: OxroColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.5 - 34,
                  bottom: h * 0.07,
                  child: Transform.scale(
                    scaleX: 1 + 0.14 * math.sin(t * math.pi),
                    child: Container(
                      width: 68,
                      height: 10,
                      decoration: BoxDecoration(
                        color: OxroColors.charcoal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.size,
    required this.appear,
    required this.bobT,
    required this.phase,
    required this.reduceMotion,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Animation<double> appear;
  final double bobT;
  final double phase;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final a = reduceMotion ? 1.0 : appear.value.clamp(0.0, 1.0);
    final t = reduceMotion ? 0.5 : bobT;
    // Micro-float each badge on its own sine phase so they never sync up.
    final bobY = reduceMotion ? 0.0 : 4.5 * math.sin((t * math.pi * 2) + phase);
    final pop = Curves.easeOutBack.transform(a).clamp(0.0, 1.08);
    // Star twinkles; the rest stay steady.
    final twinkle = icon == Icons.star_rounded && !reduceMotion
        ? 0.72 + 0.28 * math.sin((t * math.pi * 2.5) + phase)
        : 1.0;
    return Transform.translate(
      offset: Offset(0, bobY),
      child: Transform.scale(
        scale: pop,
        child: Opacity(
          opacity: twinkle.clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.48, color: color),
          ),
        ),
      ),
    );
  }
}
