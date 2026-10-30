import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';

/// Notification permission onboarding (reference 23.jpg):
/// delivery character with floating notification decor, orange CTA
/// and a "Not Now" escape to login.
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('notif_perm_screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.maxContentW),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.padX),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: context.rs(28)),
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
                  SizedBox(height: context.rs(12)),
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: context.rs(4)),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: _HeroArt(bob: _bob),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: context.btnH.clamp(52.0, 60.0),
                    child: FilledButton(
                      key: const ValueKey('notif_perm_enable'),
                      onPressed: _enable,
                      style: FilledButton.styleFrom(
                        backgroundColor: OxroColors.coral,
                        foregroundColor: Colors.white,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(6)),
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
                  SizedBox(height: context.rs(14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Delivery character with floating notification bubbles (Option A).
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.bob});

  final AnimationController bob;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: bob,
          builder: (context, _) {
            final t = bob.value;
            final lift = -6 * math.sin(t * math.pi);
            final halo = 0.9 + 0.1 * math.sin(t * math.pi * 2);
            return Stack(
              clipBehavior: Clip.none,
              children: [
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
                        color: OxroColors.primary.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.06,
                  top: h * 0.14 + lift,
                  child: _FloatBadge(
                    icon: Icons.notifications_active_rounded,
                    color: OxroColors.primary,
                    size: 46,
                  ),
                ),
                Positioned(
                  right: w * 0.04,
                  top: h * 0.24 - lift,
                  child: _FloatBadge(
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF7C4DFF),
                    size: 54,
                  ),
                ),
                Positioned(
                  right: w * 0.14,
                  bottom: h * 0.12 + lift,
                  child: _FloatBadge(
                    icon: Icons.check_circle_rounded,
                    color: OxroColors.green,
                    size: 40,
                  ),
                ),
                Positioned(
                  left: w * 0.5 - 96,
                  top: h * 0.5 - 96 + lift,
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
                  left: w * 0.5 - 30,
                  bottom: h * 0.08,
                  child: Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: OxroColors.charcoal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
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

class _FloatBadge extends StatelessWidget {
  const _FloatBadge({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}
