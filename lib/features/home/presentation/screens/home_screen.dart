import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/shimmer.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/account/presentation/widgets/profile_avatar.dart';
import 'package:oxro/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:oxro/features/account/presentation/screens/profile_screen.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:oxro/features/settings/presentation/screens/settings_screen.dart';
import 'package:oxro/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/orders/presentation/screens/orders_screen.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';
import 'package:oxro/features/wishlist/presentation/screens/wishlist_screen.dart';
import 'package:oxro/features/categories/presentation/screens/categories_screen.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/features/home/presentation/widgets/food_home_tab.dart';
import 'package:oxro/features/home/presentation/widgets/welcome_popup.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 06 Home Screen — reference pattern (Myntra-best, animated).
/// Search header + auto-play sale carousel + categories +
/// Deals of the Day (live countdown) + bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.welcomeName, this.initialTab = 0});

  final String? welcomeName;

  /// Shell tab to open (pushed pages reset here via bottom nav).
  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutoHideNavState {
  late int _tab = widget.initialTab;
  int _banner = 0;
  late final PageController _bannerCtrl;
  Timer? _bannerTimer;
  Timer? _dealTimer;
  bool _liveBlink = true;

  // Quick category rail selection (0 = All, else homeCategories[i-1]).
  // Same data + same destination as "Shop by Category" grid below.
  int _quickCat = 0;

  // Typewriter search hint — auto types product names char-by-char.
  int _hintWord = 0;
  final ValueNotifier<String> _hintShown = ValueNotifier<String>('');
  bool _hintCursor = true;
  Timer? _typeTimer;
  Timer? _cursorTimer;
  int _typeChars = 0;
  int _typeHold = 0;
  static const _searchWords = [
    'Chicken Biryani',
    'Masala Dosa',
    'Farmhouse Pizza',
    'Paneer Butter Masala',
    'Chicken Momos',
    'Butter Naan',
    'Chocolate Cake',
    'Cold Coffee',
    'Veg Fried Rice',
    'Gulab Jamun',
  ];

  // Today's Offers infinite feed.
  final _feed = <Product>[];
  int _feedPage = 0;
  bool _feedFirst = true;
  bool _feedMore = false;
  Timer? _feedTimer;
  late final ScrollController _homeScroll;

  late final AnimationController _entry;
  late final AnimationController _tabFade;
  late final AnimationController _ambient;
  bool _switching = false;
  bool _scrolled = false;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    // First successful Home entry after login/registration only.
    // Persist immediately so rebuilds and back-navigation never
    // replay it.
    final profile = ProfileStore.instance;
    if (profile.isLoggedIn && !profile.welcomeShown) {
      _showWelcome = true;
      unawaited(profile.markWelcomeShown());
    }
    _bannerCtrl = PageController(viewportFraction: 1.0);
    _homeScroll = ScrollController()..addListener(_onHomeScroll);
    // Blinkit pattern: static grid, no auto-scroll loop.
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _tabFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..value = 1.0;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    if (!_useLegacyHome) return;
    _ambient.repeat(reverse: true);
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_banner + 1) % homeBanners.length;
      _bannerCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
    // LIVE badge blink (Blinkit-style, no countdown).
    _dealTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _liveBlink = !_liveBlink;
        });
      }
    });
    // Typewriter hint: 65ms per char, hold 18 ticks (~1.2s), next word.
    _typeTimer = Timer.periodic(const Duration(milliseconds: 65), (_) {
      if (!mounted) return;
      final full = _searchWords[_hintWord];
      if (_typeHold > 0) {
        _typeHold--;
        if (_typeHold == 0) {
          _hintWord = (_hintWord + 1) % _searchWords.length;
          _typeChars = 0;
          _hintShown.value = '';
        }
        return;
      }
      _typeChars++;
      if (_typeChars >= full.length) {
        _hintShown.value = full;
        _typeHold = 18;
      } else {
        _hintShown.value = full.substring(0, _typeChars);
      }
    });
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (!mounted) return;
      setState(() => _hintCursor = !_hintCursor);
    });
    // First feed page after first paint (fast home start).
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _feed.addAll(
          ProductRepo.page(
            'home',
            "Today's Offers",
            0,
            icon: Icons.local_offer_outlined,
          ),
        );
        _feedPage = 1;
        _feedFirst = false;
      });
    });
  }

  void _onHomeScroll() {
    if (_homeScroll.hasClients) {
      final sc = _homeScroll.position.pixels > 40;
      if (sc != _scrolled && mounted) {
        setState(() => _scrolled = sc);
      }
    }
    if (_feedMore || _feedFirst) return;
    if (_feed.length >= ProductRepo.totalPerLeaf) return;
    if (_homeScroll.position.pixels >=
        _homeScroll.position.maxScrollExtent - 500) {
      _loadFeedMore();
    }
  }

  void _loadFeedMore() {
    setState(() => _feedMore = true);
    _feedTimer?.cancel();
    _feedTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _feed.addAll(
          ProductRepo.page(
            'home',
            "Today's Offers",
            _feedPage,
            icon: Icons.local_offer_outlined,
          ),
        );
        _feedPage++;
        _feedMore = false;
      });
    });
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _homeScroll.dispose();
    _bannerTimer?.cancel();
    _dealTimer?.cancel();
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    _feedTimer?.cancel();
    cancelNavTimer();
    _hintShown.dispose();
    _entry.dispose();
    _tabFade.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// Crossfade tab switch — single tree, no duplicate controllers.
  void _switchTab(int i) {
    if (i == _tab || _switching) return;
    _switching = true;
    _tabFade.reverse().then((_) {
      if (!mounted) return;
      setState(() => _tab = i);
      _tabFade.forward().then((_) => _switching = false);
    });
  }

  int get _navIndex => switch (_tab) {
    2 => 1,
    _ => 0,
  };

  void _onNavTap(int i) {
    switch (i) {
      case 1:
        _switchTab(2);
        return;
      case 2:
        pushScreen(context, const DineoutScreen());
        return;
      default:
        _switchTab(0);
    }
  }

  void _backToHome() {
    if (!mounted) return;
    setState(() => navVisible = true);
    _switchTab(0);
  }

  void _soon(String what) {
    showOxroSnack(context, '$what — coming in the next screen');
  }

  /// Real mic: live speech-to-text + tap-to-search fallback.
  void _openVoiceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: _VoiceSheet(
          suggestions: _searchWords,
          onPick: (q) {
            Navigator.of(ctx).pop();
            pushScreen(context, SearchScreen(initialQuery: q));
          },
          onType: () {
            Navigator.of(ctx).pop();
            pushScreen(context, const SearchScreen());
          },
        ),
      ),
    );
  }

  /// Opens an inline ad target (Blinkit-style native promo).
  void _openInlineAd(int target) {
    if (target < 0) {
      _switchTab(1);
      return;
    }
    pushScreen(context, SubCategoryScreen(category: homeCategories[target]));
  }

  /// Full-width inline ad strip (mid-scroll banner).
  /// [slot] keeps keys unique across static + repeating placements.
  Widget _inlineAdCard(
    BuildContext context, {
    required String slot,
    required int adIndex,
  }) {
    final ad = homeInlineAds[adIndex % homeInlineAds.length];
    return PressScale(
      key: ValueKey('feed_ad_$slot'),
      onTap: () => _openInlineAd(ad.target),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.rs(14)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ad.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ad.colors.last.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: context.rs(44),
              height: context.rs(44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: Icon(ad.icon, size: 22, color: ad.colors.last),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ad.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.rs(8)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ad.cta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ad.colors.last,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recently-viewed thumbnail (no AddButton/Hero — rails own the keys).
  Widget _recentThumb(BuildContext context, Product p) {
    return PressScale(
      key: ValueKey('recent_${p.id}'),
      onTap: () => pushScreen(context, ProductDetailScreen(product: p)),
      child: Container(
        width: context.rs(96),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OxroColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: context.rs(48),
              height: context.rs(48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: p.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(p.icon, size: 24, color: OxroColors.muted),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OxroColors.charcoal,
                ),
              ),
            ),
            Text(
              Product.inr(p.price),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: OxroColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gradient + icon shown when a banner photo is absent,
  /// still loading, or fails to load (offline / tests).
  Widget _bannerFallback(BuildContext context, HomeBanner b) {
    return Center(
      child: Icon(
        b.icon,
        size: context.rs(72),
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  /// Blinkit-style mini promo card (static, no timer).
  Widget _miniPromo(
    BuildContext context, {
    required String key,
    required String title,
    required String sub,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: PressScale(
        key: ValueKey('mini_$key'),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(context.rs(10)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Staggered entrance wrapper.
  Widget _in(double start, Widget child) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          (_entry.value - start).clamp(0.0, 1.0) / (1 - start),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: handleNavScroll,
          child: FadeTransition(
            opacity: _tabFade,
            child: Stack(
              children: [
                IndexedStack(
                  index: _tab,
                  children: [
                    _homeTab(),
                    CategoriesScreen(
                      onBack: () => _switchTab(0),
                      onOpen: (c) {
                        pushScreen(context, SubCategoryScreen(category: c));
                      },
                    ),
                    BagScreen(
                      onShopNow: () => _switchTab(0),
                      onOrders: () => _switchTab(3),
                    ),
                    OrdersScreen(
                      onShopNow: () => _switchTab(0),
                      onBag: () => _switchTab(2),
                    ),
                    ProfileScreen(
                      onBack: _backToHome,
                      onOrders: () => _switchTab(3),
                      onWishlist: () => pushScreen(
                        context,
                        WishlistScreen(onDiscover: () => _switchTab(0)),
                      ),
                      onNotifications: () => pushScreen(
                        context,
                        NotificationsScreen(
                          onOrders: () => _switchTab(3),
                          onOffer: () => _switchTab(0),
                        ),
                      ),
                      onAddresses: () => pushScreen(
                        context,
                        const AddressSelectionScreen(manageMode: true),
                      ),
                      onHelp: () => pushScreen(
                        context,
                        HelpScreen(onOrders: () => _switchTab(3)),
                      ),
                      onSettings: () =>
                          pushScreen(context, const SettingsScreen()),
                      onWallet: () => pushScreen(context, const WalletScreen()),
                      onEdit: () =>
                          pushScreen(context, const EditProfileScreen()),
                    ),
                  ],
                ),
                // Floating cart bar on every tab except Bag itself
                // (Bag already shows totals). Slides up when non-empty.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CartBar(
                    visible: _tab != 2,
                    onTap: () => _switchTab(2),
                  ),
                ),
                // Premium welcome popup — once on first Home entry.
                if (_showWelcome)
                  Positioned.fill(
                    child: WelcomePopup(
                      onDismissed: () {
                        if (!mounted) return;
                        setState(() => _showWelcome = false);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: HideableOxroBottomNav(
        visible: navVisible && _tab != 4,
        currentIndex: _navIndex,
        onTap: _onNavTap,
      ),
    );
  }

  static const bool _useLegacyHome = bool.fromEnvironment('OXRO_LEGACY_HOME');

  Widget _homeTab() {
    if (_useLegacyHome) return _legacyHomeTab();
    return FoodHomeTab(onTab: _switchTab);
  }

  Widget _legacyHomeTab() {
    return Stack(
      children: [
        // Royal-blue header wash (merged single tone from
        // address row through quick rail) fading to page white.
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8EEF9),
                  Color(0xFFD3E0F5),
                  Colors.white,
                  Color(0xFFF4F7FB),
                ],
                stops: [0.0, 0.22, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) {
                final t = _ambient.value;
                return Stack(
                  children: [
                    Positioned(
                      top: 90 + 16 * math.sin(t * math.pi * 2),
                      right: -70,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: OxroColors.primary.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 480 + 14 * math.cos(t * math.pi * 2),
                      left: -80,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: OxroColors.royalBlue.withValues(alpha: 0.035),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        CustomScrollView(
          key: const ValueKey('home_scroll'),
          controller: _homeScroll,
          slivers: [
            // Sticky search header (royal-blue over wash, solid on scroll).
            SliverAppBar(
              pinned: true,
              backgroundColor: _scrolled
                  ? const Color(0xFFD3E0F5)
                  : Colors.transparent,
              elevation: _scrolled ? 4 : 0,
              shadowColor: OxroColors.royalBlue.withValues(alpha: 0.12),
              toolbarHeight: 134,
              titleSpacing: 0,
              title: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.padX),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Greeting above the address row.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ListenableBuilder(
                        listenable: ProfileStore.instance,
                        builder: (context, _) {
                          final prof = ProfileStore.instance;
                          final greet = prof.isLoggedIn
                              ? 'Welcome back, ${prof.displayName} 👋'
                              : 'Welcome to OXRO 👋';
                          return Text(
                            greet,
                            key: const ValueKey('welcome_greet'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OxroColors.muted,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Row 1: address + wallet + profile.
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey('address_row'),
                            onTap: () => pushScreen(
                              context,
                              const AddressSelectionScreen(manageMode: true),
                            ),
                            behavior: HitTestBehavior.opaque,
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: OxroColors.primary,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'HOME - Chennai, 80 feet road',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: OxroColors.dark,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: OxroColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ListenableBuilder(
                          listenable: WalletStore.instance,
                          builder: (context, _) {
                            final bal = WalletStore.instance.balance;
                            return GestureDetector(
                              key: const ValueKey('wallet_pill'),
                              onTap: () =>
                                  pushScreen(context, const WalletScreen()),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: OxroColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: OxroColors.royalBlue.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 16,
                                      color: OxroColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      Product.inr(bal),
                                      key: const ValueKey('wallet_balance'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: OxroColors.dark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          key: const ValueKey('profile_btn'),
                          onTap: () => _switchTab(4),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: OxroColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: OxroColors.royalBlue.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const ProfileAvatar(
                              size: 38,
                              backgroundColor: Colors.transparent,
                              fallback: Icon(
                                Icons.person_outline,
                                size: 20,
                                color: OxroColors.dark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rs(8)),
                    // Row 2: bigger search (full width) + working mic.
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                pushScreen(context, const SearchScreen()),
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: OxroColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: OxroColors.royalBlue.withValues(
                                      alpha: 0.07,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 20,
                                    color: OxroColors.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: _hintShown,
                                      builder: (context, hint, _) {
                                        return Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Search ',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: OxroColors.muted,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '"$hint"',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: OxroColors.dark,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text: _hintCursor ? '▏' : ' ',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: OxroColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          key: ValueKey(
                                            'search_word_$_hintWord',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          key: const ValueKey('voice_btn'),
                          onTap: () => _openVoiceSheet(context),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: OxroColors.gradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: OxroColors.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.welcomeName != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.padX,
                        context.rs(10),
                        context.padX,
                        0,
                      ),
                      child: _in(
                        0.0,
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(context.rs(12)),
                          decoration: BoxDecoration(
                            gradient: OxroColors.gradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Welcome to OXRO, ${widget.welcomeName}! 🎉',
                            style: TextStyle(
                              fontSize: context.font(14),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: context.rs(12)),
                  // Quick category rail (transparent — sits on the
                  // merged golden wash above).
                  _in(
                    0.05,
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: OxroColors.dark.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: 80,
                        child: ListView.separated(
                          key: const ValueKey('home_quick_cats'),
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.fromLTRB(
                            context.padX,
                            6,
                            context.padX,
                            0,
                          ),
                          itemCount: homeCategories.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (_, i) {
                            final selected = _quickCat == i;
                            final IconData icon = i == 0
                                ? Icons.restaurant_menu_outlined
                                : homeCategories[i - 1].icon;
                            final String label = i == 0
                                ? 'All'
                                : homeCategories[i - 1].short;
                            return GestureDetector(
                              key: ValueKey('quick_cat_${i - 1}'),
                              onTap: () {
                                setState(() => _quickCat = i);
                                if (i == 0) {
                                  _switchTab(1);
                                  return;
                                }
                                pushScreen(
                                  context,
                                  SubCategoryScreen(
                                    category: homeCategories[i - 1],
                                  ),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 56,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 26,
                                      color: OxroColors.dark,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: OxroColors.dark,
                                      ),
                                    ),
                                    const Spacer(),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      height: 3,
                                      width: selected ? 56 : 0,
                                      decoration: BoxDecoration(
                                        color: OxroColors.dark,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(4)),
                  // Sale carousel (auto-play).
                  _in(
                    0.1,
                    Column(
                      children: [
                        // Food photo banners (8:3) with a bottom scrim
                        // and title/sub/CTA overlay; gradient + icon
                        // fallback on load failure.
                        AspectRatio(
                          aspectRatio: 2048 / 768,
                          child: PageView.builder(
                            controller: _bannerCtrl,
                            itemCount: homeBanners.length,
                            onPageChanged: (i) => setState(() => _banner = i),
                            itemBuilder: (_, i) {
                              final b = homeBanners[i];
                              return AnimatedBuilder(
                                animation: _bannerCtrl,
                                builder: (context, _) {
                                  double scale = 1.0;
                                  if (_bannerCtrl.position.haveDimensions) {
                                    final page = _bannerCtrl.page ?? 0;
                                    scale = (1 - ((page - i).abs() * 0.08))
                                        .clamp(0.9, 1.0);
                                  }
                                  return Transform.scale(
                                    scale: scale,
                                    child: GestureDetector(
                                      key: ValueKey('banner_cta_$i'),
                                      onTap: () {
                                        final ci =
                                            bannerCategoryIndex[i %
                                                bannerCategoryIndex.length];
                                        // -1 sentinel: All-in-One
                                        // opens the Categories tab.
                                        if (ci < 0) {
                                          _switchTab(1);
                                          return;
                                        }
                                        pushScreen(
                                          context,
                                          SubCategoryScreen(
                                            category: homeCategories[ci],
                                          ),
                                        );
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                          horizontal: context.rs(6),
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: b.colors,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: b.colors.last.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // Network food photo;
                                              // gradient + icon shows
                                              // while loading / offline.
                                              if (b.imageUrl == null)
                                                _bannerFallback(context, b)
                                              else
                                                Image.network(
                                                  b.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (ctx, child, progress) =>
                                                          progress == null
                                                          ? child
                                                          : _bannerFallback(
                                                              context,
                                                              b,
                                                            ),
                                                  errorBuilder:
                                                      (ctx, err, stack) =>
                                                          _bannerFallback(
                                                            context,
                                                            b,
                                                          ),
                                                ),
                                              // Bottom scrim keeps the
                                              // copy legible over art.
                                              DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withValues(
                                                        alpha: 0.55,
                                                      ),
                                                    ],
                                                    stops: const [0.4, 1.0],
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  context.rs(14),
                                                  0,
                                                  context.rs(14),
                                                  context.rs(10),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      b.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: context.rs(
                                                          15,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    Text(
                                                      b.sub,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        fontSize: context.rs(
                                                          11,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: context.rs(6),
                                                    ),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: context
                                                                .rs(10),
                                                            vertical: context
                                                                .rs(4),
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        b.cta,
                                                        style: TextStyle(
                                                          color: b.colors.last,
                                                          fontSize: context.rs(
                                                            10,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: context.rs(8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            homeBanners.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: _banner == i ? 14 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _banner == i
                                    ? OxroColors.primary
                                    : OxroColors.muted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.rs(10)),
                        // Blinkit-style mini promo cards (food).
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rs(6),
                          ),
                          child: Row(
                            children: [
                              _miniPromo(
                                context,
                                key: 'mini_new',
                                title: 'New',
                                sub: 'Fresh off the grill',
                                icon: Icons.new_releases_outlined,
                                colors: const [
                                  Color(0xFFFF6A00),
                                  Color(0xFFFFB25E),
                                ],
                                onTap: () => _switchTab(1),
                              ),
                              SizedBox(width: context.rs(8)),
                              _miniPromo(
                                context,
                                key: 'mini_brands',
                                title: 'Top Kitchens',
                                sub: 'Paradise • A2B',
                                icon: Icons.verified_outlined,
                                colors: const [
                                  Color(0xFF082B66),
                                  Color(0xFF27A9E1),
                                ],
                                onTap: () => pushScreen(
                                  context,
                                  ProductListingScreen(
                                    title: 'Top Kitchens',
                                    leafs: const [
                                      'Hyderabadi Chicken Biryani',
                                      'Masala Dosa',
                                      'Farmhouse Pizza',
                                      'Butter Chicken',
                                    ],
                                    icon: Icons.verified_outlined,
                                  ),
                                ),
                              ),
                              SizedBox(width: context.rs(8)),
                              _miniPromo(
                                context,
                                key: 'mini_under999',
                                title: 'Under ₹199',
                                sub: 'Value bites',
                                icon: Icons.local_offer_outlined,
                                colors: const [
                                  Color(0xFF16A34A),
                                  Color(0xFF4ADE80),
                                ],
                                onTap: () => pushScreen(
                                  context,
                                  ProductListingScreen(
                                    title: "Today's Offers",
                                    leafs: const [
                                      'Chicken Biryani',
                                      'Masala Dosa',
                                      'Farmhouse Pizza',
                                      'Butter Chicken',
                                    ],
                                    icon: Icons.local_offer_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(14)),
                  // Best Sellers rail (Blinkit pattern, no countdown).
                  _in(
                    0.5,
                    Container(
                      color: OxroColors.lightGrey,
                      padding: EdgeInsets.symmetric(vertical: context.rs(14)),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.padX,
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Best Sellers',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: context.font(16),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OxroColors.green.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'TOP RATED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: OxroColors.green,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => pushScreen(
                                    context,
                                    ProductListingScreen(
                                      title: "Today's Offers",
                                      leafs: const [
                                        'Chicken Biryani',
                                        'Masala Dosa',
                                        'Farmhouse Pizza',
                                        'Butter Chicken',
                                      ],
                                      icon: Icons.local_offer_outlined,
                                    ),
                                  ),
                                  child: const Text(
                                    'See All >',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OxroColors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: context.rs(12)),
                          SizedBox(
                            height: context.rs(260),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: context.padX,
                              ),
                              itemCount: 3,
                              separatorBuilder: (context, _) =>
                                  SizedBox(width: context.rs(12)),
                              itemBuilder: (_, i) =>
                                  _dealCard(homeDeals[i], hero: false),
                            ),
                          ),
                          SizedBox(height: context.rs(14)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.padX,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'New Arrivals',
                                  style: TextStyle(
                                    fontSize: context.font(15),
                                    fontWeight: FontWeight.w800,
                                    color: OxroColors.dark,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  key: const ValueKey('new_arrivals_see_all'),
                                  onTap: () => _soon('New arrivals'),
                                  child: const Text(
                                    'See All >',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OxroColors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: context.rs(10)),
                          SizedBox(
                            height: context.rs(260),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: context.padX,
                              ),
                              itemCount: 3,
                              separatorBuilder: (context, _) =>
                                  SizedBox(width: context.rs(12)),
                              itemBuilder: (_, i) =>
                                  _dealCard(homeDeals[3 + i], hero: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(16)),
                  // Brand strip.
                  _in(
                    0.7,
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.rs(14)),
                        decoration: BoxDecoration(
                          color: OxroColors.dark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Fresh Ingredients',
                                    style: TextStyle(
                                      fontSize: context.font(15),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Paradise • A2B • Domino’s • KFC',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.verified_outlined,
                              size: 36,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Recently Viewed rail (Blinkit Order-Again feel).
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.padX),
                    child: Row(
                      children: [
                        Text(
                          'Recently Viewed',
                          style: TextStyle(
                            fontSize: context.font(15),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.dark,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          key: const ValueKey('recent_see_all'),
                          onTap: () => _soon('Recently viewed'),
                          child: const Text(
                            'See All >',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(10)),
                  SizedBox(
                    height: context.rs(120),
                    child: ListView.separated(
                      key: const ValueKey('recent_rail'),
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      itemCount: homeDeals.length > 4 ? 4 : homeDeals.length,
                      separatorBuilder: (context, _) =>
                          SizedBox(width: context.rs(12)),
                      // No AddButton/Hero here: avoids duplicate
                      // keys + hero tags with the rails above.
                      itemBuilder: (_, i) =>
                          _recentThumb(context, homeDeals[i]),
                    ),
                  ),
                  SizedBox(height: context.rs(16)),
                ],
              ),
            ),
            // Static mid-scroll banner before the feed.
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.padX,
                  0,
                  context.padX,
                  context.rs(14),
                ),
                child: _inlineAdCard(context, slot: 'top', adIndex: 0),
              ),
            ),
            // Today's Offers — infinite product feed.
            // Scroll pannu panna products show agum.
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.padX),
                child: Row(
                  children: [
                    Text(
                      "Today's Offers",
                      style: TextStyle(
                        fontSize: context.font(16),
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      key: const ValueKey('offers_live'),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF16A34A,
                            ).withValues(alpha: _liveBlink ? 0.45 : 0.18),
                            blurRadius: _liveBlink ? 12 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 500),
                            opacity: _liveBlink ? 1.0 : 0.25,
                            child: Container(
                              key: const ValueKey('offers_live_dot'),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => pushScreen(
                        context,
                        ProductListingScreen(
                          title: "Today's Offers",
                          leafs: const [
                            'Chicken Biryani',
                            'Masala Dosa',
                            'Farmhouse Pizza',
                            'Butter Chicken',
                          ],
                          icon: Icons.local_offer_outlined,
                        ),
                      ),
                      child: const Text(
                        'See All >',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.royalBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: context.rs(12))),
            ...(_feedFirst && _feed.isEmpty
                ? [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.isTablet ? 3 : 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.58,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, _) => const _FeedSkeleton(),
                          childCount: 6,
                        ),
                      ),
                    ),
                  ]
                : () {
                    // Chunked feed: every 10 products → full-width ad.
                    final chunks = (_feed.length / ProductRepo.pageSize).ceil();
                    return [
                      for (var c = 0; c < chunks; c++) ...[
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.padX,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: context.isTablet ? 3 : 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.58,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final idx = c * ProductRepo.pageSize + i;
                                return _dealCard(_feed[idx], feedKey: true);
                              },
                              childCount: (c == chunks - 1)
                                  ? _feed.length - c * ProductRepo.pageSize
                                  : ProductRepo.pageSize,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.padX,
                              context.rs(12),
                              context.padX,
                              0,
                            ),
                            child: _inlineAdCard(
                              context,
                              slot: '$c',
                              adIndex: (c + 1) % homeInlineAds.length,
                            ),
                          ),
                        ),
                      ],
                    ];
                  }()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.rs(18)),
                child: Center(
                  child: _feedMore
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: OxroColors.primary,
                          ),
                        )
                      : _feed.length >= ProductRepo.totalPerLeaf
                      ? const Text(
                          "You've seen it all 🎉",
                          style: TextStyle(
                            fontSize: 12,
                            color: OxroColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dealCard(Product p, {bool feedKey = false, bool hero = true}) {
    return PressScale(
      key: feedKey ? ValueKey('home_feed_${p.id}') : null,
      onTap: () => pushScreen(context, ProductDetailScreen(product: p)),
      child: Container(
        width: feedKey ? null : context.rs(150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OxroColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                HeroMode(
                  enabled: hero,
                  child: Hero(
                    tag: 'pdp_image_${p.id}',
                    child: Container(
                      height: context.rs(100),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: p.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Icon(p.icon, size: 56, color: OxroColors.muted),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Text(
                      '${p.off}% OFF',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListenableBuilder(
                        listenable: WishlistStore.instance,
                        builder: (context, _) {
                          final wished = WishlistStore.instance.contains(p.id);
                          return GestureDetector(
                            onTap: () => WishlistStore.instance.toggle(p),
                            behavior: HitTestBehavior.opaque,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('wish_${p.id}_$wished'),
                              tween: Tween(begin: 0.5, end: 1.0),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              builder: (context, v, _) => Transform.scale(
                                scale: v,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    wished
                                        ? Icons.favorite
                                        : Icons.favorite_outline,
                                    size: 16,
                                    color: wished
                                        ? Colors.red
                                        : OxroColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      ProductShareButton(product: p, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          Product.inr(p.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          Product.inr(p.mrp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: OxroColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.rating}★',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '(${p.reviews})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: OxroColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: AddButton(product: p),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey shimmer placeholder for the feed's first load.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OxroColors.lightGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Expanded(
            flex: 5,
            child: ShimmerBox(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(height: 10, width: 70),
                  const SizedBox(height: 6),
                  const ShimmerBox(height: 12, width: double.infinity),
                  const Spacer(),
                  const ShimmerBox(height: 12, width: 90),
                  const SizedBox(height: 6),
                  const ShimmerBox(height: 28, width: double.infinity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid-orange floating cart bar (Image 2 layout): one line with
/// item count + total on the left, VIEW CART on the right.
/// Home tab only; slides up when the bag is non-empty.
class _CartBar extends StatefulWidget {
  const _CartBar({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  State<_CartBar> createState() => _CartBarState();
}

class _CartBarState extends State<_CartBar> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final store = CartStore.instance;
        final show = widget.visible && store.count > 0;
        return AnimatedSlide(
          offset: show ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: show
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.padX,
                      0,
                      context.padX,
                      10,
                    ),
                    child: GestureDetector(
                      key: const ValueKey('cart_bar'),
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: OxroColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: OxroColors.primary.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: FittedBox(
                                  key: ValueKey('bar_${store.count}'),
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${store.count} Item${store.count == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        ' · ${Product.inr(store.totalPrice)}',
                                        key: ValueKey(
                                          'cart_bar_total_${store.totalPrice}',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              key: const ValueKey('cart_bar_go'),
                              onTap: widget.onTap,
                              behavior: HitTestBehavior.opaque,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'VIEW CART',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Live voice sheet — real device STT with fallback suggestions.
class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({
    required this.suggestions,
    required this.onPick,
    required this.onType,
  });

  final List<String> suggestions;
  final ValueChanged<String> onPick;
  final VoidCallback onType;

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _transcript = '';
  String _status = 'Starting mic…';
  double _level = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    try {
      _available = await _stt.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _status = 'Mic error — tap retry or pick below';
            _listening = false;
          });
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s.contains('done') || s.contains('notListening')) {
            setState(() {
              _listening = false;
              _level = 0;
              if (_transcript.isEmpty) {
                _status = 'Tap mic to try again';
              } else {
                _status = 'Heard you — search now';
              }
            });
          }
        },
      );
    } catch (_) {
      _available = false;
    }
    if (!mounted) return;
    if (!_available) {
      setState(() => _status = 'Voice not available here — pick a suggestion');
      return;
    }
    _start();
  }

  Future<void> _start() async {
    if (!_available || _listening) return;
    setState(() {
      _status = 'Listening… say “running shoes”';
    });
    try {
      await _stt.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() {
            _transcript = r.recognizedWords;
            _status = r.finalResult ? 'Heard you — search now' : 'Listening…';
          });
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 3),
        ),
        onSoundLevelChange: (l) {
          if (!mounted) return;
          setState(() => _level = l.clamp(0, 12) / 12);
        },
      );
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Mic blocked — allow permission';
          _listening = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _listening = false;
        _level = 0;
      });
    }
  }

  @override
  void dispose() {
    _stt.stop();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _transcript.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(context.padX, 16, context.padX, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const ValueKey('voice_mic_btn'),
            onTap: () => _listening ? _stop() : _start(),
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final glow = _listening
                    ? 0.30 + _level * 0.45 + _pulse.value * 0.12
                    : 0.30;
                final scale = _listening ? 1.0 + _level * 0.18 : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _listening
                          ? OxroColors.gradient
                          : const LinearGradient(
                              colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: OxroColors.primary.withValues(alpha: glow),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _listening ? 'Listening…' : 'Try saying…',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: OxroColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _status,
            key: const ValueKey('voice_status'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: OxroColors.muted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('voice_transcript_box'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: OxroColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OxroColors.border),
            ),
            child: Text(
              q.isEmpty ? 'Say “running shoes”… ' : '“$q”',
              key: const ValueKey('voice_transcript'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: q.isEmpty ? OxroColors.muted : OxroColors.dark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            key: const ValueKey('voice_search_btn'),
            onTap: q.isEmpty ? null : () => widget.onPick(q),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: q.isEmpty ? 0.45 : 1.0,
              child: Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: OxroColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  q.isEmpty ? 'Speak to search' : 'Search “$q”',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.suggestions.take(6))
                GestureDetector(
                  key: ValueKey('voice_q_$s'),
                  onTap: () => widget.onPick(s),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.pageBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OxroColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.graphic_eq,
                          size: 14,
                          color: OxroColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            key: const ValueKey('voice_type_btn'),
            onTap: widget.onType,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OxroColors.dark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Type instead',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
