import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

/// Shared bottom nav (Home shell + pushed shopping pages).
/// Same 5 items + center Bag circle + live [BagBadge].
/// Shown on every shopping page until the Bag — never on
/// Bag/Checkout/Address/Coupons/Success/Tracking.
class OxroBottomNav extends StatelessWidget {
  const OxroBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: OxroColors.primary,
      unselectedItemColor: OxroColors.muted,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Categories'),
        BottomNavigationBarItem(
            icon: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentIndex == 2
                        ? OxroColors.primary
                        : OxroColors.primary
                            .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      Icons.shopping_bag_outlined,
                      color: currentIndex == 2
                          ? Colors.white
                          : OxroColors.primary),
                ),
                const Positioned(
                  right: 0,
                  top: 0,
                  child: BagBadge(),
                ),
              ],
            ),
            label: 'Bag'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Orders'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account'),
      ],
    );
  }
}

/// Nav taps from pushed shopping pages (L2/PLP/PDP/Search).
/// Home/Categories/Orders/Account reset to the Home shell tab
/// (no back-stack loops); Bag pushes on top so back returns.
void handleShopNav(BuildContext context, int i) {
  if (i == 2) {
    pushScreen(
      context,
      BagScreen(
          onShopNow: () => Navigator.of(context).maybePop()),
    );
    return;
  }
  replaceAllWith(context, HomeScreen(initialTab: i));
}
