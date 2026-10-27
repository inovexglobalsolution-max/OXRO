import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

/// Shared floating bottom nav (Home shell + pushed shopping pages).
/// Order: Delivery · Cart (raised) · Dining.
class OxroBottomNav extends StatelessWidget {
  const OxroBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barH = 54;
  static const double _lift = 12;
  static const double _shadowPad = 2;
  static const double _stackH = _barH + _lift + _shadowPad;
  static const double _cartSize = 50;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      key: const ValueKey('oxro_bottom_nav'),
      padding: EdgeInsets.fromLTRB(12, 0, 12, 4 + bottomPad),
      color: Colors.transparent,
      child: SizedBox(
        height: _stackH,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / 3;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barH,
                  child: Container(
                    key: const ValueKey('nav_bar'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OxroColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A075F70),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barH,
                  child: Row(
                    children: [
                      _NavItem(
                        key: const ValueKey('nav_delivery'),
                        label: 'Delivery',
                        icon: Icons.delivery_dining_rounded,
                        selected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      // Reserved slot for the raised cart button.
                      const Expanded(child: SizedBox()),
                      _NavItem(
                        key: const ValueKey('nav_dining'),
                        label: 'Dining',
                        icon: Icons.restaurant_rounded,
                        selected: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: slot * 1.5 - _cartSize / 2,
                  top: _shadowPad,
                  width: _cartSize,
                  height: _cartSize,
                  child: _NavCart(
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
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
    final color = selected ? OxroColors.coral : OxroColors.muted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
                child: Text(label, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCart extends StatelessWidget {
  const _NavCart({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('nav_cart'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: 'Cart',
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: Container(
            key: const ValueKey('nav_cart_button'),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  OxroColors.premiumDeep,
                  OxroColors.premiumBurgundy,
                  OxroColors.premiumWine,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? OxroColors.premiumChampagne
                    : OxroColors.premiumChampagne.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.premiumDeep.withValues(
                    alpha: selected ? 0.42 : 0.30,
                  ),
                  blurRadius: selected ? 18 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 23,
                  color: selected ? Colors.white : OxroColors.premiumChampagne,
                ),
                const Positioned(right: -6, top: -6, child: BagBadge()),
              ],
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
      height: visible ? 72 + bottomPad : 0,
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
