import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/applock/data/applock_store.dart';
import 'package:oxro/features/applock/presentation/screens/pin_screen.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/help/data/support_store.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/location/data/geo_store.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';
import 'package:oxro/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/reviews/data/review_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// 01 Splash Screen — responsive: logo = 31% width, fonts scale.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Parallel loads + brand beat run together (was 3 sequential
    // awaits); any prefs failure falls back to Login, never hangs.
    try {
      await Future.wait([
        ProfileStore.instance.load(),
        ApplockStore.instance.load(),
        ReviewStore.instance.load(),
        CartStore.instance.load(),
        AddressStore.instance.load(),
        OrderStore.instance.load(),
        WalletStore.instance.load(),
        WishlistStore.instance.load(),
        PaymentStore.instance.load(),
        PremiumStore.instance.load(),
        PricingConfigStore.instance.load(),
        GeoStore.instance.load(),
        FoodPreferenceStore.instance.load(),
        SupportStore.instance.load(),
        Future.delayed(const Duration(milliseconds: 1800)),
      ]);
    } catch (_) {
      // Fall through to Login below.
    }
    if (!mounted) return;
    final prof = ProfileStore.instance;
    final Widget dest;
    if (prof.isLoggedIn) {
      dest = const HomeScreen();
    } else if (prof.seenOnboarding) {
      dest = const LoginScreen();
    } else {
      dest = const OnboardingScreen();
    }
    if (ApplockStore.instance.enabled) {
      replaceScreen(
        context,
        PinScreen(onUnlock: () => replaceAllWith(context, dest)),
      );
    } else {
      replaceScreen(context, dest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = context.w * 0.31; // 99 @320, 133 @430
    final barW = context.w * 0.31;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: OxroColors.gradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentW),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.rs(28)),
                    child: Image.asset(
                      'assets/logo/oxro_logo.jpeg',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: logoSize,
                        height: logoSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(context.rs(28)),
                        ),
                        child: Text(
                          'O',
                          style: TextStyle(
                            fontSize: context.font(64),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(16)),
                  Text(
                    'OXRO',
                    style: TextStyle(
                      fontSize: context.font(32),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Eat More  Live Better',
                    style: TextStyle(
                      fontSize: context.font(13),
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: barW,
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.white38,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: context.font(11),
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: context.rs(32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
