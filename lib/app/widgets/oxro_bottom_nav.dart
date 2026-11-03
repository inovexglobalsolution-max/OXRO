import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

const _rnNavy = Color(0xFF0B132B);
const _rnGold = Color(0xFFD4AF37);
const _rnGoldSoft = Color(0xFFE8D48B);

/// Shared floating bottom nav (Home shell + pushed shopping pages).
/// Order: Delivery · Cart (raised) · Dining.
class OxroBottomNav extends StatefulWidget {
  const OxroBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barH = 62;
  static const double _lift = 16;
  static const double _shadowPad = 4;
  static const double _stackH = _barH + _lift + _shadowPad;
  static const double _cartSize = 58;

  @override
  State<OxroBottomNav> createState() => _OxroBottomNavState();
}

class _OxroBottomNavState extends State<OxroBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      key: const ValueKey('oxro_bottom_nav'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomPad),
      color: Colors.transparent,
      child: SizedBox(
        height: OxroBottomNav._stackH,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / 3;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: constraints.maxWidth * 0.05,
                  right: constraints.maxWidth * 0.05,
                  bottom: 0,
                  height: OxroBottomNav._barH,
                  child: Container(
                    key: const ValueKey('nav_bar'),
                    decoration: BoxDecoration(
                      color: _rnNavy,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _rnGold, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: _rnGold.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * 0.05,
                  right: constraints.maxWidth * 0.05,
                  bottom: 0,
                  height: OxroBottomNav._barH,
                  child: Row(
                    children: [
                      _NavItem(
                        key: const ValueKey('nav_delivery'),
                        label: 'Delivery',
                        icon: Icons.delivery_dining_rounded,
                        selected: widget.currentIndex == 0,
                        onTap: () => widget.onTap(0),
                      ),
                      // Reserved slot for the raised cart button.
                      const Expanded(child: SizedBox()),
                      _NavItem(
                        key: const ValueKey('nav_dining'),
                        label: 'Dining',
                        icon: Icons.restaurant_rounded,
                        selected: widget.currentIndex == 2,
                        onTap: () => widget.onTap(2),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: slot * 1.5 - OxroBottomNav._cartSize / 2,
                  top: OxroBottomNav._shadowPad,
                  width: OxroBottomNav._cartSize,
                  height: OxroBottomNav._cartSize,
                  child: OverflowBox(
                    maxHeight: 120,
                    maxWidth: 120,
                    alignment: Alignment.center,
                    child: _NavCart(
                      float: _float,
                      selected: widget.currentIndex == 1,
                      onTap: () => widget.onTap(1),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _rnGold : _rnGold.withValues(alpha: 0.45),
                  width: selected ? 1.6 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _rnGold.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 25,
                color: selected ? _rnGold : _rnGoldSoft,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? _rnGold : _rnGoldSoft.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
              child: Text(label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCart extends StatefulWidget {
  const _NavCart({
    required this.float,
    required this.selected,
    required this.onTap,
  });

  final Animation<double> float;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavCart> createState() => _NavCartState();
}

class _NavCartState extends State<_NavCart> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('nav_cart'),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: 'Cart',
        child: AnimatedBuilder(
          animation: widget.float,
          builder: (context, child) {
            final dy = (widget.float.value - 0.5) * 4.0;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              key: const ValueKey('nav_cart_button'),
              decoration: BoxDecoration(
                color: OxroColors.premiumBurgundy,
                shape: BoxShape.circle,
                border: Border.all(color: _rnGold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _rnGold.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: OxroColors.premiumDeep.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Inner gold ring (double border effect)
                  Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _rnGold.withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.shopping_cart_rounded,
                    size: 27,
                    color: widget.selected ? Colors.white : _rnGoldSoft,
                  ),
                  const Positioned(right: -6, top: -6, child: BagBadge()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nav taps from pushed shopping pages (L2/PLP/PDP/Search).
/// Delivery resets to the Home shell; Cart/Dining push on top
/// so back returns to the current page.
void handleShopNav(BuildContext context, int i) {
  switch (i) {
    case 1:
      pushScreen(
        context,
        BagScreen(onShopNow: () => Navigator.of(context).maybePop()),
      );
      return;
    case 2:
      pushScreen(context, const DineoutScreen());
      return;
    default:
      replaceAllWith(context, const HomeScreen());
  }
}

/// Collapsible nav — slides + collapses to 0 height so content
/// expands. Scroll down hides, scroll up / stop shows again.
class HideableOxroBottomNav extends StatelessWidget {
  const HideableOxroBottomNav({
    super.key,
    required this.visible,
    required this.currentIndex,
    required this.onTap,
  });

  final bool visible;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: visible ? 82 + bottomPad : 0,
      child: ClipHardEdge(
        child: Wrap(
          children: [OxroBottomNav(currentIndex: currentIndex, onTap: onTap)],
        ),
      ),
    );
  }
}

/// Reusable hide-on-scroll logic — mix into any shopping screen.
/// Scroll down (reverse) hides, scroll up (forward) shows, scroll
/// end re-shows after 400ms so a stopped screen never strands
/// the user without nav.
mixin AutoHideNavState<T extends StatefulWidget> on State<T> {
  bool navVisible = true;
  Timer? _navTimer;

  bool handleNavScroll(ScrollNotification n) {
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse && navVisible && mounted) {
        setState(() => navVisible = false);
      } else if (n.direction == ScrollDirection.forward &&
          !navVisible &&
          mounted) {
        _navTimer?.cancel();
        setState(() => navVisible = true);
      }
    } else if (n is ScrollEndNotification) {
      _navTimer?.cancel();
      _navTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && !navVisible) {
          setState(() => navVisible = true);
        }
      });
    }
    return false;
  }

  void cancelNavTimer() => _navTimer?.cancel();
}

class ClipHardEdge extends StatelessWidget {
  const ClipHardEdge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        maxHeight: 120,
        child: child,
      ),
    );
  }
}
