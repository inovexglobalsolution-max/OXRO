import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/shimmer.dart';
import 'package:oxro/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:oxro/features/account/presentation/screens/profile_screen.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:oxro/features/settings/presentation/screens/settings_screen.dart';
import 'package:oxro/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/orders/presentation/screens/orders_screen.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';
import 'package:oxro/features/wishlist/presentation/screens/wishlist_screen.dart';
import 'package:oxro/features/categories/presentation/screens/categories_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/features/categories/data/category_style.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';

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
    with TickerProviderStateMixin {
  late int _tab = widget.initialTab;
  int _banner = 0;
  late final PageController _bannerCtrl;
  Timer? _bannerTimer;
  Timer? _dealTimer;
  late DateTime _dealEndsAt;
  bool _liveBlink = true;

  // Blinkit-style rotating search hint (fashion catalogue).
  int _searchWord = 0;
  Timer? _searchTimer;
  static const _searchWords = [
    'shirts',
    'shoes',
    'watches',
    'kurtas',
    'sneakers',
    'handbags',
  ];

  // Today's Offers infinite feed.
  final _feed = <Product>[];
  int _feedPage = 0;
  bool _feedFirst = true;
  bool _feedMore = false;
  late final ScrollController _homeScroll;

  // Shop-by-Category auto-scroll loop (Myntra feel).
  late final ScrollController _catScroll;
  Timer? _catTimer;
  Timer? _catResume;
  bool _catHeld = false;

  late final AnimationController _entry;
  late final AnimationController _tabFade;
  late final AnimationController _ambient;
  bool _switching = false;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _bannerCtrl = PageController(viewportFraction: 1.0);
    _homeScroll = ScrollController()..addListener(_onHomeScroll);
    _catScroll = ScrollController();
    _catTimer =
        Timer.periodic(const Duration(seconds: 3), (_) {
      _stepCategories();
    });
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
    )..repeat(reverse: true);
    _bannerTimer =
        Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_banner + 1) % homeBanners.length;
      _bannerCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
    _dealEndsAt = DateTime.now().add(
      const Duration(hours: 5, minutes: 23, seconds: 11),
    );
    _dealTimer = Timer.periodic(
        const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _liveBlink = !_liveBlink;
        });
      }
    });
    // Blinkit-style search hint rotation (1.5s, no delivery badge).
    _searchTimer = Timer.periodic(
        const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() {
        _searchWord = (_searchWord + 1) % _searchWords.length;
      });
    });
    // First feed page after first paint (fast home start).
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _feed.addAll(ProductRepo.page(
            'home', "Today's Offers", 0,
            icon: Icons.local_offer_outlined));
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

  Future<void> _loadFeedMore() async {
    setState(() => _feedMore = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _feed.addAll(ProductRepo.page(
          'home', "Today's Offers", _feedPage,
          icon: Icons.local_offer_outlined));
      _feedPage++;
      _feedMore = false;
    });
  }

  /// One auto-scroll step for the category strip.
  /// Slides one card forward; rewinds smoothly at the end.
  /// Skips while the user holds the strip or reduced-motion is on.
  void _stepCategories() {
    if (!mounted || _catHeld || !_catScroll.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) return;
    final pos = _catScroll.position;
    // Card width 112 + 12 gap (rs-scaled to match the strip).
    final step = context.rs(112) + context.rs(12);
    final next = pos.pixels + step;
    if (next >= pos.maxScrollExtent - 4) {
      _catScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    } else {
      _catScroll.animateTo(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Pauses auto-scroll while the finger is down; resumes after 5s idle.
  void _pauseCategories() {
    _catHeld = true;
    _catResume?.cancel();
  }

  void _resumeCategories() {
    _catResume?.cancel();
    _catResume = Timer(const Duration(seconds: 5), () {
      _catHeld = false;
    });
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _homeScroll.dispose();
    _catScroll.dispose();
    _bannerTimer?.cancel();
    _dealTimer?.cancel();
    _searchTimer?.cancel();
    _catTimer?.cancel();
    _catResume?.cancel();
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

  String get _countdown {
    final left = _dealEndsAt.difference(DateTime.now());
    if (left.isNegative) return '00:00:00';
    final h = left.inHours.toString().padLeft(2, '0');
    final m =
        (left.inMinutes % 60).toString().padLeft(2, '0');
    final s =
        (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _soon(String what) {
    showOxroSnack(context, '$what — coming in the next screen');
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
                pushScreen(
                  context,
                  SubCategoryScreen(category: c),
                );
              },
            ),
            BagScreen(onShopNow: () => _switchTab(0)),
            OrdersScreen(onShopNow: () => _switchTab(0)),
            ProfileScreen(
              onOrders: () => _switchTab(3),
              onWishlist: () => pushScreen(
                context,
                WishlistScreen(
                    onDiscover: () => _switchTab(0)),
              ),
              onAddresses: () => pushScreen(
                context,
                const AddressSelectionScreen(
                    manageMode: true),
              ),
              onHelp: () => pushScreen(
                context,
                HelpScreen(onOrders: () => _switchTab(3)),
              ),
              onSettings: () => pushScreen(
                context,
                const SettingsScreen(),
              ),
              onWallet: () => pushScreen(
                context,
                const WalletScreen(),
              ),
              onEdit: () => pushScreen(
                context,
                const EditProfileScreen(),
              ),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: OxroBottomNav(
        currentIndex: _tab,
        onTap: _switchTab,
      ),
    );
  }

  Widget _homeTab() {
    return Stack(
      children: [
        // Warm brand wash + drifting ambient blobs.
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF7F1),
                  Colors.white,
                  Color(0xFFF4F7FB),
                ],
                stops: [0.0, 0.45, 1.0],
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
                      top: 90 +
                          16 *
                              math.sin(
                                  t * math.pi * 2),
                      right: -70,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: OxroColors.primary
                              .withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 480 +
                          14 *
                              math.cos(
                                  t * math.pi * 2),
                      left: -80,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: OxroColors.royalBlue
                              .withValues(alpha: 0.06),
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
        // Sticky search header (transparent over wash, paper on scroll).
        SliverAppBar(
          pinned: true,
          backgroundColor:
              _scrolled ? Colors.white : Colors.transparent,
          elevation: _scrolled ? 4 : 0,
          shadowColor: OxroColors.royalBlue
              .withValues(alpha: 0.12),
          toolbarHeight: 64,
          titleSpacing: 0,
          title: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: context.padX),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: OxroColors.primary),
                const SizedBox(width: 4),
                const Text('Chennai',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.dark)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => pushScreen(
                        context, const SearchScreen()),
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: OxroColors.royalBlue
                                .withValues(alpha: 0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 18, color: OxroColors.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              key: const ValueKey(
                                  'search_rotator'),
                              duration: const Duration(
                                  milliseconds: 300),
                              transitionBuilder:
                                  (child, anim) =>
                                      SlideTransition(
                                position: Tween<Offset>(
                                  begin:
                                      const Offset(0, 0.6),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: FadeTransition(
                                    opacity: anim,
                                    child: child),
                              ),
                              child: Text(
                                'Search "${_searchWords[_searchWord]}"',
                                key: ValueKey(
                                    'search_word_$_searchWord'),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: OxroColors.muted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: NotifStore.instance,
                  builder: (context, _) {
                    final unread =
                        NotifStore.instance.unreadCount;
                    return Stack(
                      children: [
                        IconButton(
                          key: const ValueKey('notif_bell'),
                          onPressed: () => pushScreen(
                            context,
                            NotificationsScreen(
                              onOrders: () =>
                                  _switchTab(3),
                              onOffer: () =>
                                  _switchTab(0),
                            ),
                          ),
                          icon: const Icon(
                              Icons
                                  .notifications_outlined,
                              color: OxroColors.dark),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              key: const ValueKey(
                                  'notif_badge'),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                      horizontal: 5,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                              ),
                              child: Text(
                                  unread > 9
                                      ? '9+'
                                      : '$unread',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w800,
                                      color:
                                          Colors.white)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () =>
                          setState(() => _tab = 2),
                      icon: const Icon(
                          Icons.shopping_bag_outlined,
                          color: OxroColors.dark),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: const BagBadge(),
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
                  padding: EdgeInsets.fromLTRB(context.padX,
                      context.rs(10), context.padX, 0),
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
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: context.rs(12)),
              // Sale carousel (auto-play).
              _in(
                0.1,
                Column(
                  children: [
                    // Full-art banners (2048x768 = 8:3): exact-fit,
                    // zero crop — baked text never cuts.
                    AspectRatio(
                      aspectRatio: 2048 / 768,
                      child: PageView.builder(
                        controller: _bannerCtrl,
                        itemCount: homeBanners.length,
                        onPageChanged: (i) =>
                            setState(() => _banner = i),
                        itemBuilder: (_, i) {
                          final b = homeBanners[i];
                          return AnimatedBuilder(
                            animation: _bannerCtrl,
                            builder: (context, _) {
                              double scale = 1.0;
                              if (_bannerCtrl
                                  .position.haveDimensions) {
                                final page =
                                    _bannerCtrl.page ?? 0;
                                scale = (1 -
                                        ((page - i).abs() *
                                            0.08))
                                    .clamp(0.9, 1.0);
                              }
                              return Transform.scale(
                                scale: scale,
                                child: GestureDetector(
                                  key: ValueKey(
                                      'banner_cta_$i'),
                                  onTap: () {
                                    final ci =
                                        bannerCategoryIndex[
                                            i %
                                                bannerCategoryIndex
                                                    .length];
                                    // -1 sentinel: All-in-One
                                    // opens the Categories tab.
                                    if (ci < 0) {
                                      _switchTab(1);
                                      return;
                                    }
                                    pushScreen(
                                      context,
                                      SubCategoryScreen(
                                          category:
                                              homeCategories[
                                                  ci]),
                                    );
                                  },
                                  behavior:
                                      HitTestBehavior.opaque,
                                  child: Container(
                                    margin:
                                        EdgeInsets.symmetric(
                                            horizontal:
                                                context.rs(
                                                    6)),
                                    decoration: BoxDecoration(
                                      gradient:
                                          LinearGradient(
                                              colors:
                                                  b.colors),
                                      borderRadius:
                                          BorderRadius.circular(
                                              18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: b.colors
                                              .last
                                              .withValues(
                                                  alpha:
                                                      0.35),
                                          blurRadius: 16,
                                          offset:
                                              const Offset(
                                                  0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              18),
                                      // Image-only art (baked text
                                      // inside the PNG). Gradient +
                                      // icon show on load failure.
                                      child: b.image ==
                                              null
                                          ? Center(
                                              child: Icon(
                                                  b.icon,
                                                  size: context.rs(
                                                      72),
                                                  color: Colors
                                                      .white
                                                      .withValues(
                                                          alpha:
                                                              0.9)),
                                            )
                                          : Image.asset(
                                              b.image!,
                                              fit: BoxFit
                                                  .cover,
                                              errorBuilder: (ctx,
                                                      err,
                                                      stack) =>
                                                  Center(
                                                child: Icon(
                                                    b.icon,
                                                    size: context.rs(
                                                        72),
                                                    color: Colors
                                                        .white
                                                        .withValues(
                                                            alpha:
                                                                0.9)),
                                              ),
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
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: List.generate(
                        homeBanners.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 250),
                          margin:
                              const EdgeInsets.symmetric(
                                  horizontal: 2.5),
                          width: _banner == i ? 14 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _banner == i
                                ? OxroColors.primary
                                : OxroColors.muted,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rs(14)),
              // Categories.
              _in(
                0.3,
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.padX),
                      child: Text('Shop by Category',
                          style: TextStyle(
                              fontSize: context.font(16),
                              fontWeight: FontWeight.w800,
                              color: OxroColors.dark)),
                    ),
                    SizedBox(height: context.rs(10)),
                    SizedBox(
                      height: context.rs(152),
                      child: Listener(
                        onPointerDown: (_) =>
                            _pauseCategories(),
                        onPointerUp: (_) =>
                            _resumeCategories(),
                        onPointerCancel: (_) =>
                            _resumeCategories(),
                        child: ListView.separated(
                          key: const ValueKey(
                              'home_cat_strip'),
                          controller: _catScroll,
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                              horizontal: context.padX),
                          itemCount:
                              homeCategories.length,
                        separatorBuilder: (context, _) =>
                            SizedBox(width: context.rs(12)),
                        itemBuilder: (_, i) {
                          final n = homeCategories.length;
                          final start =
                              0.3 + (i / n) * 0.25;
                          return AnimatedBuilder(
                            animation: _entry,
                            builder: (context, _) {
                              final t =
                                  Curves.easeOutCubic.transform(
                                ((_entry.value - start) /
                                        (1 - start))
                                    .clamp(0.0, 1.0),
                              );
                              final pop =
                                  Curves.easeOutBack.transform(
                                      t);
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(
                                      0, 18 * (1 - t)),
                                  child: Transform.scale(
                                    scale: (0.9 + 0.1 * pop)
                                        .clamp(0.9, 1.03),
                                    child: _HomeCatCard(
                                      index: i,
                                      onTap: () => pushScreen(
                                        context,
                                        SubCategoryScreen(
                                          category:
                                              homeCategories[
                                                  i],
                                          heroTag:
                                              'home_cat_${homeCategories[i].label}',
                                        ),
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
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rs(16)),
              // Deals of the Day.
              _in(
                0.5,
                Container(
                  color: OxroColors.lightGrey,
                  padding: EdgeInsets.symmetric(
                      vertical: context.rs(14)),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.padX),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text('Deals of the Day',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize:
                                          context.font(16),
                                      fontWeight:
                                          FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4),
                              decoration: BoxDecoration(
                                color: OxroColors.red
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.timer_outlined,
                                      size: 13,
                                      color: OxroColors.red),
                                  const SizedBox(width: 3),
                                  Text(_countdown,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: OxroColors.red)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  _soon('All deals'),
                              child: const Text('See All >',
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: OxroColors.blue)),
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
                              horizontal: context.padX),
                          itemCount: homeDeals.length,
                          separatorBuilder: (context, _) =>
                              SizedBox(
                                  width: context.rs(12)),
                          itemBuilder: (_, i) =>
                              _dealCard(homeDeals[i]),
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
                  padding: EdgeInsets.symmetric(
                      horizontal: context.padX),
                  child: Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.all(context.rs(14)),
                    decoration: BoxDecoration(
                      color: OxroColors.dark,
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('100% Original Brands',
                                  style: TextStyle(
                                      fontSize:
                                          context.font(15),
                                      fontWeight:
                                          FontWeight.w800,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              const Text(
                                  'Nike • Puma • Samsung • Lakmé',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70)),
                            ],
                          ),
                        ),
                        const Icon(
                            Icons.verified_outlined,
                            size: 36,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
              // Today's Offers — infinite product feed.
              // Scroll pannu panna products show agum.
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.padX),
                  child: Row(
                    children: [
                      Text("Today's Offers",
                          style: TextStyle(
                              fontSize: context.font(16),
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal)),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        key: const ValueKey('offers_live'),
                        duration: const Duration(
                            milliseconds: 500),
                        curve: Curves.easeInOut,
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [
                                Color(0xFF16A34A),
                                Color(0xFF4ADE80)
                              ]),
                          borderRadius:
                              BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                      0xFF16A34A)
                                  .withValues(
                                      alpha: _liveBlink
                                          ? 0.45
                                          : 0.18),
                              blurRadius:
                                  _liveBlink ? 12 : 6,
                              offset:
                                  const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(
                                  milliseconds: 500),
                              opacity:
                                  _liveBlink ? 1.0 : 0.25,
                              child: Container(
                                key: const ValueKey(
                                    'offers_live_dot'),
                                width: 8,
                                height: 8,
                                decoration:
                                    const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('LIVE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: Colors.white)),
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
                              'Electronics',
                              'Fashion',
                              'Home & Kitchen',
                              'Beauty'
                            ],
                            icon:
                                Icons.local_offer_outlined,
                          ),
                        ),
                        child: const Text('See All >',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.royalBlue)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                  child: SizedBox(height: context.rs(12))),
              _feedFirst && _feed.isEmpty
                  ? SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.padX),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              context.isTablet ? 3 : 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.58,
                        ),
                        delegate:
                            SliverChildBuilderDelegate(
                          (context, _) =>
                              const _FeedSkeleton(),
                          childCount: 6,
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.padX),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              context.isTablet ? 3 : 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.58,
                        ),
                        delegate:
                            SliverChildBuilderDelegate(
                          (ctx, i) => _dealCard(
                              _feed[i],
                              feedKey: true),
                          childCount: _feed.length,
                        ),
                      ),
                    ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: context.rs(18)),
                  child: Center(
                    child: _feedMore
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              color: OxroColors.primary,
                            ),
                          )
                        : _feed.length >=
                                ProductRepo.totalPerLeaf
                            ? const Text(
                                "You've seen it all 🎉",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: OxroColors.muted,
                                    fontWeight:
                                        FontWeight.w600))
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
      ],
        ),
      ],
    );
  }

  Widget _dealCard(Product p, {bool feedKey = false}) {
    return PressScale(
      key: feedKey ? ValueKey('home_feed_${p.id}') : null,
      onTap: () =>
          pushScreen(context, ProductDetailScreen(product: p)),
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
                Hero(
                  tag: 'pdp_image_${p.id}',
                  child: Container(
                    height: context.rs(100),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: p.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius:
                          const BorderRadius.vertical(
                              top: Radius.circular(14)),
                    ),
                    child: Icon(p.icon,
                        size: 56, color: OxroColors.muted),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.all(
                          Radius.circular(6)),
                    ),
                    child: Text('${p.off}% OFF',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: ListenableBuilder(
                    listenable: WishlistStore.instance,
                    builder: (context, _) {
                      final wished = WishlistStore
                          .instance
                          .contains(p.id);
                      return GestureDetector(
                        onTap: () => WishlistStore
                            .instance
                            .toggle(p),
                        behavior:
                            HitTestBehavior.opaque,
                        child: TweenAnimationBuilder<
                            double>(
                          key: ValueKey(
                              'wish_${p.id}_$wished'),
                          tween: Tween(
                              begin: 0.5, end: 1.0),
                          duration: const Duration(
                              milliseconds: 220),
                          curve: Curves.easeOutBack,
                          builder: (context, v, _) =>
                              Transform.scale(
                            scale: v,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(
                                      6),
                              decoration:
                                  const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                wished
                                    ? Icons.favorite
                                    : Icons
                                        .favorite_outline,
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
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          color: OxroColors.muted,
                          fontWeight: FontWeight.w600)),
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(Product.inr(p.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(Product.inr(p.mrp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: OxroColors.muted,
                                decoration: TextDecoration
                                    .lineThrough)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                        child: Text('${p.rating}★',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.green)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('(${p.reviews})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10,
                                color: OxroColors.muted)),
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
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(14)),
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
                  const ShimmerBox(
                      height: 12, width: double.infinity),
                  const Spacer(),
                  const ShimmerBox(height: 12, width: 90),
                  const SizedBox(height: 6),
                  const ShimmerBox(
                    height: 28,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating cart bar — Image 2 layout, app light-orange theme
/// (peach slab + charcoal text + solid orange Proceed).
/// Home tab only; slides up when the bag is non-empty.
/// Premium: spring entry + icon bounce on add + total tick +
/// shine sweep + ambient breathe. Full-bar tap → Bag tab.
class _CartBar extends StatefulWidget {
  const _CartBar({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  State<_CartBar> createState() => _CartBarState();
}

class _CartBarState extends State<_CartBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

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
                        context.padX, 0, context.padX, 10),
                    child: GestureDetector(
                      key: const ValueKey('cart_bar'),
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _ambient,
                        builder: (context, _) =>
                            Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8),
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(
                                    colors: [
                                  Color(0xFFFFE3CB),
                                  Color(0xFFFFC79B)
                                ],
                                    begin:
                                        Alignment.topLeft,
                                    end: Alignment
                                        .bottomRight),
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                                color: OxroColors.primary,
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: OxroColors.primary
                                    .withValues(
                                        alpha: 0.22 +
                                            0.08 *
                                                _ambient
                                                    .value),
                                blurRadius: 16,
                                offset:
                                    const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              TweenAnimationBuilder<
                                  double>(
                                key: ValueKey(
                                    'cart_bounce_${store.count}'),
                                tween: Tween(
                                    begin: 0.5,
                                    end: 1.0),
                                duration:
                                    const Duration(
                                        milliseconds:
                                            280),
                                curve:
                                    Curves.easeOutBack,
                                builder:
                                    (context, v, _) =>
                                        Transform.scale(
                                  scale: v,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment:
                                        Alignment.center,
                                    decoration: BoxDecoration(
                                      color: OxroColors
                                          .primary
                                          .withValues(
                                              alpha:
                                                  0.14),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  12),
                                    ),
                                    child: const Icon(
                                        Icons
                                            .shopping_cart_outlined,
                                        size: 22,
                                        color: OxroColors
                                            .primary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(
                                              milliseconds:
                                                  200),
                                      transitionBuilder:
                                          (child,
                                                  anim) =>
                                              ScaleTransition(
                                                  scale:
                                                      anim,
                                                  child:
                                                      child),
                                      child: Text(
                                        '${store.count} items',
                                        key: ValueKey(
                                            'bar_${store.count}'),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight
                                                        .w800,
                                                color: OxroColors
                                                    .charcoal),
                                      ),
                                    ),
                                    Text(
                                        store.savings > 0
                                            ? '${Product.inr(store.savings)} savings'
                                            : 'Cart ready',
                                        key: ValueKey(
                                            'bar_sub_${store.savings}'),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: OxroColors
                                                .muted)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 34,
                                margin:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 4),
                                child: CustomPaint(
                                    painter:
                                        _DashLinePainter()),
                              ),
                              Flexible(
                                child: TweenAnimationBuilder<
                                    double>(
                                key: ValueKey(
                                    'cart_flash_${store.totalPrice}'),
                                tween: Tween(
                                    begin: 0.0,
                                    end: 1.0),
                                duration:
                                    const Duration(
                                        milliseconds:
                                            350),
                                curve: Curves.easeOut,
                                builder:
                                    (context, v, _) =>
                                        Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                              4,
                                          vertical: 2),
                                  decoration:
                                      BoxDecoration(
                                    color: OxroColors
                                        .primary
                                        .withValues(
                                            alpha: 0.18 *
                                                (1 - v)),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(
                                            milliseconds:
                                                200),
                                    // FittedBox shrinks the font
                                    // instead of cutting the amount.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          Alignment.centerLeft,
                                      child: Text(
                                        Product.inr(store
                                            .totalPrice),
                                        key: ValueKey(
                                            'cart_bar_total_${store.totalPrice}'),
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                            color: OxroColors
                                                .charcoal),
                                      ),
                                    ),
                                  ),
                                ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CartGoBtn(
                                key: const ValueKey(
                                    'cart_bar_go'),
                                onTap: widget.onTap,
                                ambient: _ambient,
                              ),
                            ],
                          ),
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

/// Solid orange Proceed pill with looping shine sweep + press scale.
class _CartGoBtn extends StatefulWidget {
  const _CartGoBtn(
      {super.key, required this.onTap, required this.ambient});

  final VoidCallback onTap;
  final Animation<double> ambient;

  @override
  State<_CartGoBtn> createState() => _CartGoBtnState();
}

class _CartGoBtnState extends State<_CartGoBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.value = 0.94,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: () {
        _press.value = 1.0;
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedBuilder(
          animation: widget.ambient,
          builder: (context, _) => Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: OxroColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.primary.withValues(
                      alpha:
                          0.30 + 0.12 * widget.ambient.value),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Proceed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 16, color: Colors.white),
                  ],
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(16),
                    child: Transform.translate(
                      offset: Offset(
                          -60 +
                              120 *
                                  widget
                                      .ambient.value,
                          0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 18,
                          color: Colors.white.withValues(
                              alpha: 0.35 *
                                  (1 -
                                      widget
                                          .ambient.value *
                                          0.5)),
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

/// Myntra-style category card for Home "Shop by Category".
/// Gradient header + glass icon + label + items count, press-scale tap,
/// Hero icon (tag `cat_<label>`) matched in L2 header.
class _HomeCatCard extends StatelessWidget {
  const _HomeCatCard({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = homeCategories[index];
    final g = catGradient(index);
    final glow = g.last;
    final w = context.rs(112);
    return RepaintBoundary(
      child: PressScale(
        key: ValueKey('home_cat_${c.short}'),
        scale: 0.94,
        onTap: onTap,
        child: Container(
          width: w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OxroColors.border),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'home_cat_${c.label}',
                child: Container(
                  height: context.rs(78),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: g,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(
                            top: Radius.circular(16)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: -18,
                        top: -18,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -14,
                        bottom: -20,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(
                        width: context.rs(44),
                        height: context.rs(44),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x30051D47),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(c.icon,
                            size: 22, color: glow),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(c.short,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal,
                              height: 1.2)),
                      const SizedBox(height: 2),
                      Text(c.items,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: glow,
                              height: 1.2)),
                    ],
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

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OxroColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y),
          Offset(0, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}
