import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/video_banner.dart';
import 'package:oxro/app/widgets/oxro_button.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/location/presentation/screens/location_screen.dart';

/// 02 Onboarding — responsive + animated, no blank space.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final PageController _pageCtrl;
  late final AnimationController _anim;

  final _pages = const [
    (
      title: 'Great Food,\nDelivered Fast',
      sub: 'Biryani, pizza, dosa, desserts and more — from kitchens near you.',
      icon: Icons.delivery_dining_outlined,
      chip1: 'Biryani 30% OFF',
      chip2: 'Free Delivery',
      bgTop: Color(0xFFFFF7F1),
      bgBottom: Color(0xFFFFE3CB),
    ),
    (
      title: 'Deals Made\nFor You',
      sub: 'Buy 1 Get 1 pizza, combo meals and Offers of the Day.',
      icon: Icons.local_offer_outlined,
      chip1: 'Up to 40% OFF',
      chip2: 'Combo Meals',
      bgTop: Color(0xFFFFF1F3),
      bgBottom: Color(0xFFFFD9E2),
    ),
    (
      title: 'Live Tracking\nTo Your Door',
      sub: 'Track your rider live and pay securely with UPI / COD.',
      icon: Icons.local_shipping_outlined,
      chip1: 'COD Available',
      chip2: '30-min Delivery',
      bgTop: Color(0xFFF0F7FF),
      bgBottom: Color(0xFFD8EBFF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _goNext() {
    ProfileStore.instance.markOnboardingSeen();
    replaceScreen(context, const LocationScreen());
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [page.bgTop, page.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentW),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.padX,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo/oxro_logo.jpeg',
                            width: context.rs(28),
                            height: context.rs(28),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: context.rs(28),
                              height: context.rs(28),
                              color: OxroColors.primary,
                              alignment: Alignment.center,
                              child: const Text(
                                'O',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OXRO',
                          style: TextStyle(
                            fontSize: context.font(16),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _goNext,
                          child: const Text('Skip >'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.padX + 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(_index),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              page.title,
                              style: TextStyle(
                                fontSize: context.font(isLandscape ? 22 : 26),
                                fontWeight: FontWeight.w800,
                                color: OxroColors.dark,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: context.rs(6)),
                            Text(
                              page.sub,
                              style: TextStyle(
                                fontSize: context.font(13.5),
                                color: OxroColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: _pages.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _AnimatedCard(
                          icon: _pages[i].icon,
                          chip1: _pages[i].chip1,
                          chip2: _pages[i].chip2,
                          anim: _anim,
                          pageIndex: i,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _index == i ? context.rs(22) : context.rs(8),
                        height: context.rs(8),
                        decoration: BoxDecoration(
                          color: _index == i
                              ? OxroColors.primary
                              : OxroColors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.padX,
                      0,
                      context.padX,
                      context.rs(14),
                    ),
                    child: OxroButton(
                      label: _index == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onTap: () {
                        if (_index < _pages.length - 1) {
                          _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _goNext();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({
    required this.icon,
    required this.chip1,
    required this.chip2,
    required this.anim,
    required this.pageIndex,
  });

  final IconData icon;
  final String chip1;
  final String chip2;
  final AnimationController anim;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final hero = math.min(context.w * 0.56, context.h * 0.28);
    final circle = hero * 0.76;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(context.rs(24)),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: OxroColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rs(24)),
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: -40,
              child: Container(
                width: context.rs(140),
                height: context.rs(140),
                decoration: BoxDecoration(
                  color: OxroColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: context.rs(120),
                height: context.rs(120),
                decoration: BoxDecoration(
                  color: OxroColors.blue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: (pageIndex == 0 || pageIndex == 1 || pageIndex == 2)
                  ? SizedBox.expand(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(context.rs(24)),
                        child: VideoBanner(
                          asset: pageIndex == 0
                              ? 'assets/videos/gimbap.mp4'
                              : pageIndex == 1
                              ? 'assets/videos/restaurant_3d.mov'
                              : 'assets/videos/corn_dog.mp4',
                          fallbackAsset: 'assets/food/hero_biryani.jpg',
                          fit: BoxFit.cover,
                          play: true,
                        ),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: anim,
                      builder: (context, child) {
                        final t = anim.value;
                        final floatY = -10 * math.sin(t * math.pi * 2);
                        final pulse = 1.0 + 0.06 * math.sin(t * math.pi * 2);
                        final wiggle = pageIndex == 1
                            ? 0.12 * math.sin(t * math.pi * 4)
                            : 0.0;
                        final slideX = pageIndex == 2
                            ? 26 * math.sin(t * math.pi * 2)
                            : 0.0;
                        final orbit = t * math.pi * 2;
                        final r = hero * 0.35;
                        return SizedBox(
                          width: hero,
                          height: hero,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: pulse,
                                child: Container(
                                  width: circle,
                                  height: circle,
                                  decoration: const BoxDecoration(
                                    gradient: OxroColors.gradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x55FF6A00),
                                        blurRadius: 30,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: hero / 2 + r * math.cos(orbit) - 13,
                                top: hero / 2 + r * math.sin(orbit) - 13,
                                child: Container(
                                  width: context.rs(26),
                                  height: context.rs(26),
                                  decoration: const BoxDecoration(
                                    color: OxroColors.blue,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x440A8CFF),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(slideX, floatY),
                                child: Transform.rotate(
                                  angle: wiggle,
                                  child: Icon(
                                    icon,
                                    size: context.rs(80),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              left: 14,
              top: 16,
              child: _FloatChip(label: chip1, delay: 0),
            ),
            Positioned(
              right: 14,
              bottom: 16,
              child: _FloatChip(label: chip2, delay: 1),
            ),
            if (pageIndex == 2)
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (context, child) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      7,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 22,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha:
                                0.12 +
                                0.10 * ((i + (anim.value * 7).floor()) % 2),
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatChip extends StatefulWidget {
  const _FloatChip({required this.label, required this.delay});
  final String label;
  final int delay;

  @override
  State<_FloatChip> createState() => _FloatChipState();
}

class _FloatChipState extends State<_FloatChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 150 * widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: context.rs(7),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x22051D47), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  gradient: OxroColors.gradient,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: context.font(12),
                  fontWeight: FontWeight.w700,
                  color: OxroColors.dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
