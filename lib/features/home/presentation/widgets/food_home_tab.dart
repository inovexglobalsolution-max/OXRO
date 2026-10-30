import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/animated_search_hint.dart';
import 'package:oxro/app/widgets/filter_chip_row.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/restaurant_card.dart';
import 'package:oxro/app/widgets/section_header.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/account/presentation/widgets/profile_avatar.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/widgets/animated_promo_banner.dart';
import 'package:oxro/features/home/presentation/widgets/animated_sale_banner.dart';
import 'package:oxro/features/home/presentation/widgets/dish_spotlight.dart';
import 'package:oxro/features/home/presentation/widgets/schedule_sheet.dart';
import 'package:oxro/features/home/presentation/widgets/veg_mode_sheet.dart';
import 'package:oxro/features/location/data/geo_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_listing_screen.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';
import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/features/wallet/presentation/screens/wallet_screen.dart';

class FoodHomeTab extends StatefulWidget {
  const FoodHomeTab({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  State<FoodHomeTab> createState() => _FoodHomeTabState();
}

class _FoodHomeTabState extends State<FoodHomeTab>
    with TickerProviderStateMixin {
  late final PageController _bannerCtrl;
  late final ScrollController _scrollCtrl;
  late final AnimationController _entry;
  late final AnimationController _ambient;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  Timer? _bannerTimer;
  int _bannerPage = 0;
  bool _scrolled = false;
  RestaurantFilters _filters = const RestaurantFilters();
  DeliverySchedule? _schedule;
  String _activeStop = 'All';
  Timer? _cuisineTapTimer;

  /// Huge virtual page count so the carousel can loop forward (and backward)
  /// forever without ever animating back through all slides.
  static const _bannerLoopMid = 1000;
  static const _bannerLoopLength = 2000;

  static const _cuisineStops = [
    _CuisineStop(
      label: 'All',
      icon: Icons.restaurant_menu_rounded,
      image: FoodMedia.heroThali,
    ),
    _CuisineStop(
      label: 'Biryani',
      cuisine: 'Biryani',
      icon: Icons.rice_bowl_outlined,
      image: FoodMedia.biryani,
    ),
    _CuisineStop(
      label: 'Rice',
      query: 'Rice',
      icon: Icons.rice_bowl_rounded,
      image: FoodMedia.curry,
    ),
    _CuisineStop(
      label: 'Veg Meal',
      query: 'Veg',
      icon: Icons.dinner_dining_outlined,
      image: FoodMedia.thali,
    ),
    _CuisineStop(
      label: 'Chicken',
      query: 'Chicken',
      icon: Icons.local_fire_department_outlined,
      image: FoodMedia.grill,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bannerCtrl = PageController(
      initialPage: homeBanners.length * _bannerLoopMid,
    );
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    _headerFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.62, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entry,
            curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
          ),
        );
    FoodPreferenceStore.instance.addListener(_onPreferenceChanged);
    _armBannerTimer();
  }

  @override
  void dispose() {
    FoodPreferenceStore.instance.removeListener(_onPreferenceChanged);
    _cuisineTapTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _scrollCtrl.dispose();
    _entry.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _onPreferenceChanged() {
    if (mounted) setState(() {});
  }

  bool get _isPremium => homeBanners[_bannerPage].style == BannerStyle.premium;

  RestaurantFilters get _effectiveFilters => _filters.copyWith(
    foodPreference: FoodPreferenceStore.instance.activeFilter,
  );

  void _onScroll() {
    final next = _scrollCtrl.hasClients && _scrollCtrl.offset > 20;
    if (next != _scrolled && mounted) setState(() => _scrolled = next);
  }

  void _armBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;
      final current = _bannerCtrl.page?.round() ?? _bannerPage;
      _bannerCtrl.animateToPage(
        current + 1,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<Restaurant> get _feed =>
      filterRestaurants(RestaurantRepo.all, _effectiveFilters);

  List<RestaurantDish> _fastDishes() {
    final out = <RestaurantDish>[];
    final preference = FoodPreferenceStore.instance.activeFilter;
    for (final restaurant in _feed) {
      if (restaurant.etaMinutes > 30) continue;
      var added = 0;
      for (final dish in restaurant.dishes) {
        if (preference == FoodPreference.veg && !dish.veg) continue;
        if (preference == FoodPreference.nonVeg && dish.veg) continue;
        out.add(RestaurantDish(restaurant: restaurant, dish: dish));
        added++;
        if (added >= 2) break;
      }
      if (out.length >= 12) break;
    }
    return out;
  }

  List<Product> _uniqueDishes(Iterable<Product> source, {int limit = 10}) {
    final seen = <String>{};
    final out = <Product>[];
    for (final p in source) {
      if (!seen.add(p.name.trim().toLowerCase())) continue;
      out.add(p);
      if (out.length >= limit) break;
    }
    return out;
  }

  List<Product> get _repeatItems {
    final out = <Product>[];
    for (final order in OrderStore.instance.all) {
      for (final p in order.products) {
        if (p.restaurantName == null && p.restaurantId == null) continue;
        out.add(p);
      }
    }
    return _uniqueDishes(out, limit: 8);
  }

  void _openRestaurant(String id) {
    pushScreen(context, RestaurantScreen(restaurantId: id));
  }

  void _openDish(Product dish) {
    final r = RestaurantRepo.byName(dish.restaurantName);
    if (r != null) {
      _openRestaurant(r.id);
    } else {
      pushScreen(context, ProductDetailScreen(product: dish));
    }
  }

  void _openListing({String? cuisine, String? query}) {
    pushScreen(
      context,
      RestaurantListingScreen(
        title: query ?? cuisine ?? 'Restaurants near you',
        cuisine: cuisine,
        query: query,
        initialFilters: _effectiveFilters,
      ),
    );
  }

  void _openQuickStop(_CuisineStop stop) {
    _openListing(cuisine: stop.cuisine, query: stop.query);
  }

  /// Select first so the glow/underline is visible, then open the listing.
  void _onCuisineTap(_CuisineStop stop) {
    if (_activeStop != stop.label) {
      setState(() => _activeStop = stop.label);
    }
    _cuisineTapTimer?.cancel();
    _cuisineTapTimer = Timer(const Duration(milliseconds: 180), () {
      _cuisineTapTimer = null;
      if (mounted) _openQuickStop(stop);
    });
  }

  void _openOffers() {
    pushScreen(
      context,
      RestaurantListingScreen(
        title: 'Best offers',
        initialFilters: _effectiveFilters.copyWith(offers: true),
      ),
    );
  }

  void _openBudget(int maxCost) {
    pushScreen(
      context,
      RestaurantListingScreen(
        title: 'Under ₹$maxCost',
        initialFilters: _effectiveFilters.copyWith(maxCostForTwo: maxCost),
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final picked = await showScheduleSheet(context, initial: _schedule);
    if (!mounted || picked == null) return;
    setState(() => _schedule = picked);
  }

  Future<void> _onVegTap() async {
    final store = FoodPreferenceStore.instance;
    if (store.enabled) {
      await store.disable();
      return;
    }
    final choice = await showFoodPreferenceSheet(
      context,
      preference: store.preference,
    );
    if (!mounted || choice == null) return;
    if (choice == FoodSheetChoice.moreSettings) {
      await showFoodSettingsSheet(context);
      return;
    }
    final preference = choice == FoodSheetChoice.nonVeg
        ? FoodPreference.nonVeg
        : FoodPreference.veg;
    await store.apply(preference);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            FoodPreferenceTransitionScreen(preference: preference),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openDeal(Restaurant restaurant) {
    _openRestaurant(restaurant.id);
  }

  void _openBanner(int i) {
    if (homeBanners[i].style == BannerStyle.premium) {
      pushScreen(context, const PremiumScreen());
      return;
    }
    final idx = bannerCategoryIndex[i];
    if (idx < 0 || idx >= homeCategories.length) {
      _openListing();
    } else {
      _openListing(cuisine: homeCategories[idx].label);
    }
  }

  List<Product> get _bestSellers => _uniqueDishes([
    ...homeDeals,
    for (final r in RestaurantRepo.topRated.take(3)) ...r.dishes.take(2),
  ]);

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final repeats = _repeatItems;
    final fastDishes = _fastDishes();
    return CustomScrollView(
      key: const ValueKey('home_scroll'),
      controller: _scrollCtrl,
      slivers: [
        _header(context),
        SliverToBoxAdapter(
          child: _Reveal(delayMs: 30, child: _bannerCarousel(context)),
        ),
        SliverToBoxAdapter(
          child: _Reveal(delayMs: 60, child: _categoryRail(context)),
        ),
        SliverToBoxAdapter(
          child: _Reveal(
            delayMs: 100,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: FilterChipRow(
                  chips: [
                    OxroFilterChip(
                      key: const ValueKey('home_filter_schedule'),
                      label: _schedule?.chipLabel ?? 'Schedule',
                      selected: _schedule != null,
                      prominent: true,
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                      onTap: _pickSchedule,
                      onClear: _schedule == null
                          ? null
                          : () => setState(() => _schedule = null),
                    ),
                    OxroFilterChip(
                      key: const ValueKey('home_filter_great_offers'),
                      label: 'Great offers',
                      selected: _filters.offers,
                      prominent: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(offers: !_filters.offers);
                      }),
                    ),
                    OxroFilterChip(
                      key: const ValueKey('home_filter_rating4'),
                      label: 'Rating 4.0+',
                      selected: _filters.rating4,
                      prominent: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(
                          rating4: !_filters.rating4,
                        );
                      }),
                    ),
                    OxroFilterChip(
                      key: const ValueKey('home_filter_pure_veg'),
                      label: 'Pure Veg',
                      selected: _filters.pureVeg,
                      prominent: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(
                          pureVeg: !_filters.pureVeg,
                        );
                      }),
                    ),
                    OxroFilterChip(
                      key: const ValueKey('home_filter_all'),
                      label: 'Filters',
                      icon: Icons.tune_rounded,
                      selected: _effectiveFilters.isActive,
                      prominent: true,
                      badge: _filters.count > 0 ? _filters.count : null,
                      onTap: () => _openListing(),
                    ),
                    if (_filters.isActive || _schedule != null)
                      OxroResetChip(
                        key: const ValueKey('home_filter_reset'),
                        prominent: true,
                        onTap: () => setState(() {
                          _filters = const RestaurantFilters();
                          _schedule = null;
                        }),
                      ),
                    OxroFilterChip(
                      key: const ValueKey('food_filter_fast'),
                      label: 'Near & Fast',
                      icon: Icons.bolt_rounded,
                      selected: _filters.under30,
                      prominent: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(
                          under30: !_filters.under30,
                        );
                      }),
                    ),
                    OxroFilterChip(
                      key: const ValueKey('home_filter_budget'),
                      label: 'Under ₹150',
                      icon: Icons.currency_rupee_rounded,
                      selected: _filters.maxCostForTwo == 150,
                      prominent: true,
                      onTap: () => _openBudget(150),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _Reveal(delayMs: 140, child: _recommendedDeals(context)),
        ),
        if (repeats.isNotEmpty)
          SliverToBoxAdapter(
            child: _Reveal(
              delayMs: 220,
              child: _DishRail(
                key: const ValueKey('food_order_again'),
                title: 'Order again',
                subtitle: 'Your favourites, one tap away',
                products: repeats,
                onTap: _openDish,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _Reveal(
            delayMs: 240,
            child: Padding(
              key: const ValueKey('food_restaurants_header'),
              padding: EdgeInsets.fromLTRB(context.padX, 20, context.padX, 8),
              child: SectionHeader(
                title: 'Restaurants near you',
                subtitle: _effectiveFilters.isActive
                    ? '${feed.length} places match your filters'
                    : 'Fresh picks around ${AddressStore.instance.hasValid ? 'your address' : 'you'}',
                actionLabel: 'See all',
                onAction: () => _openListing(),
              ),
            ),
          ),
        ),
        if (feed.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No restaurants match these filters.',
                  style: TextStyle(
                    fontSize: 13,
                    color: OxroColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else ...[
          _restaurantCards(
            context,
            feed.take(2).toList(),
            key: const ValueKey('food_restaurant_feed_before_fast'),
          ),
          if (fastDishes.isNotEmpty)
            SliverToBoxAdapter(
              key: const ValueKey('home_fast_dishes_sliver'),
              child: _Reveal(
                delayMs: 110,
                child: FastDishRail(
                  items: fastDishes,
                  onTap: (item) => _openRestaurant(item.restaurant.id),
                ),
              ),
            ),
          _restaurantCards(
            context,
            feed.skip(2).toList(),
            startIndex: 2,
            key: const ValueKey('food_restaurant_feed_after_fast'),
          ),
        ],
        SliverToBoxAdapter(
          child: _Reveal(
            delayMs: 140,
            child: Column(
              children: [
                for (final collection in RestaurantRepo.collections)
                  _CollectionRail(
                    collection: collection,
                    onTap: _openRestaurant,
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _Reveal(
            delayMs: 180,
            child: _DishRail(
              key: const ValueKey('food_best_sellers'),
              title: 'Best sellers',
              subtitle: 'Dishes everyone is ordering',
              products: _bestSellers,
              onTap: _openDish,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 112)),
      ],
    );
  }

  Widget _restaurantCards(
    BuildContext context,
    List<Restaurant> items, {
    int startIndex = 0,
    Key? key,
  }) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(key: key, child: const SizedBox.shrink());
    }
    return SliverPadding(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: context.padX),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final r = items[i];
          final index = startIndex + i;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentW),
              child: _Reveal(
                delayMs: 40 + (index.clamp(0, 4) * 35),
                child: RestaurantCard(
                  restaurant: r,
                  onTap: () => _openRestaurant(r.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final palette = _headerPaletteFor(homeBanners[_bannerPage]);
    final ink = palette.ink;
    final inkSoft = palette.inkSoft;
    final pillBg = palette.pillBg;
    final pillBorder = palette.pillBorder;
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 138,
      backgroundColor: _scrolled ? palette.scrolled : palette.top,
      surfaceTintColor: Colors.transparent,
      elevation: _scrolled ? 7 : 0,
      shadowColor: const Color(0x33075F70),
      titleSpacing: 0,
      flexibleSpace: _HeaderWash(palette: palette),
      title: FadeTransition(
        opacity: _headerFade,
        child: SlideTransition(
          position: _headerSlide,
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('food_location'),
                        onTap: () => pushScreen(
                          context,
                          const AddressSelectionScreen(manageMode: true),
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            AddressStore.instance,
                            GeoStore.instance,
                          ]),
                          builder: (context, _) {
                            final addr = AddressStore.instance;
                            final a = addr.hasValid ? addr.address : null;
                            final city = (GeoStore.instance.place.city ?? '')
                                .trim();
                            final title = a != null
                                ? (a.label.trim().isEmpty ? 'Home' : a.label)
                                : (city.isNotEmpty ? city : 'Set location');
                            final line = a != null
                                ? '${a.line}, ${a.city}'
                                : (city.isNotEmpty
                                      ? GeoStore.instance.place.displayLine
                                      : 'Set your delivery address');
                            return Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 21,
                                  color: ink,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                height: 1.1,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 19,
                                            color: ink,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        line,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('wallet_pill'),
                      onTap: () => pushScreen(context, const WalletScreen()),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pillBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: pillBorder),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 19,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('profile_btn'),
                      onTap: () => widget.onTab(4),
                      behavior: HitTestBehavior.opaque,
                      child: ListenableBuilder(
                        listenable: ProfileStore.instance,
                        builder: (context, _) {
                          final name = ProfileStore.instance.displayName;
                          return Container(
                            width: 38,
                            height: 38,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.75),
                                width: 1.5,
                              ),
                            ),
                            child: ProfileAvatar(
                              size: 34,
                              backgroundColor: _isPremium
                                  ? OxroColors.premiumBurgundy
                                  : OxroColors.maroon,
                              fallback: Center(
                                child: Text(
                                  name.isEmpty ? 'O' : name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('food_search'),
                        onTap: () => pushScreen(context, const SearchScreen()),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A075F70),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                size: 24,
                                color: OxroColors.coral,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'Search',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: OxroColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: AnimatedSearchHint(
                                        key: const ValueKey('food_search_hint'),
                                        hintKey: 'food_search_hint',
                                        items: [
                                          for (final name
                                              in SearchRepo.dishNames)
                                            '"$name"',
                                        ],
                                        fallback: '"Chicken Biryani"',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: OxroColors.dark,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        emphasisStyle: const TextStyle(
                                          fontSize: 13,
                                          color: OxroColors.dark,
                                          fontWeight: FontWeight.w800,
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
                    const SizedBox(width: 8),
                    _MicButton(
                      onTap: () => pushScreen(context, const SearchScreen()),
                    ),
                    const SizedBox(width: 6),
                    _VegToggle(
                      active: FoodPreferenceStore.instance.activeFilter,
                      ink: ink,
                      onTap: _onVegTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryRail(BuildContext context) {
    return Container(
      key: const ValueKey('home_cuisine_strip'),
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          const offersWidth = 64.0;
          const budgetWidth = 64.0;
          final available =
              constraints.maxWidth -
              (context.padX * 2) -
              offersWidth -
              budgetWidth -
              (gap * 2);
          final target = available >= 300
              ? 5
              : available >= 200
              ? 4
              : available >= 140
              ? 3
              : 2;
          final itemWidth = (available - (gap * (target - 1))) / target;
          final thumb = (itemWidth * 0.88).clamp(44.0, 56.0);
          return SizedBox(
            height: 84,
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: context.padX, right: gap),
                  child: _BestOffersTile(onTap: _openOffers),
                ),
                _Under250Tile(onTap: () => _openBudget(250)),
                const SizedBox(width: gap),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('home_quick_cats'),
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(right: context.padX),
                    itemCount: _cuisineStops.length,
                    separatorBuilder: (_, _) => const SizedBox(width: gap),
                    itemBuilder: (context, i) {
                      final stop = _cuisineStops[i];
                      final selected = _activeStop == stop.label;
                      return Semantics(
                        selected: selected,
                        button: true,
                        label: stop.label,
                        child: GestureDetector(
                          key: ValueKey('food_cuisine_$i'),
                          onTap: () => _onCuisineTap(stop),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedScale(
                            scale: selected ? 1.045 : 1,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutBack,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: itemWidth,
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: thumb,
                                    height: thumb,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? OxroColors.coral
                                            : OxroColors.border,
                                        width: selected ? 2 : 1,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: OxroColors.coral
                                                    .withValues(alpha: 0.36),
                                                blurRadius: 12,
                                                spreadRadius: 1.5,
                                              ),
                                              BoxShadow(
                                                color: OxroColors.coral
                                                    .withValues(alpha: 0.16),
                                                blurRadius: 20,
                                                spreadRadius: 4,
                                              ),
                                            ]
                                          : const [
                                              BoxShadow(
                                                color: Color(0x14075F70),
                                                blurRadius: 9,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                    ),
                                    child: FoodImage(
                                      imageUrl: stop.image,
                                      colors: const [
                                        Color(0xFFF7F2E8),
                                        Color(0xFFEFE6D8),
                                      ],
                                      icon: stop.icon,
                                      width: thumb - 4,
                                      height: thumb - 4,
                                      radius: thumb,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    stop.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: selected
                                          ? OxroColors.coral
                                          : OxroColors.charcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedContainer(
                                    key: ValueKey('food_cuisine_underline_$i'),
                                    duration: const Duration(milliseconds: 180),
                                    width: selected ? 26 : 0,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: OxroColors.coral,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: OxroColors.coral
                                                    .withValues(alpha: 0.45),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ],
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
          );
        },
      ),
    );
  }

  Widget _bannerCarousel(BuildContext context) {
    final palette = _headerPaletteFor(homeBanners[_bannerPage]);
    return AnimatedContainer(
      key: const ValueKey('home_promo_hero'),
      duration: const Duration(milliseconds: 260),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderPatternPainter(base: palette.pattern),
            ),
          ),
          SizedBox(
            height: 306,
            child: PageView.builder(
              key: const ValueKey('food_banner_carousel'),
              controller: _bannerCtrl,
              itemCount: homeBanners.length * _bannerLoopLength,
              onPageChanged: (i) {
                setState(() => _bannerPage = i % homeBanners.length);
                _armBannerTimer();
              },
              itemBuilder: (context, i) {
                final real = i % homeBanners.length;
                final banner = homeBanners[real];
                final fallbackPage =
                    _bannerPage.toDouble() +
                    homeBanners.length * _bannerLoopMid.toDouble();
                final page = _bannerCtrl.hasClients
                    ? (_bannerCtrl.page ?? fallbackPage)
                    : fallbackPage;
                final delta = (page - i).abs().clamp(0.0, 1.0);
                final child = switch (banner.style) {
                  BannerStyle.premium => _PremiumPromoBanner(
                    banner: banner,
                    index: real,
                    ambient: _ambient,
                    onTap: () => _openBanner(real),
                  ),
                  BannerStyle.sale => AnimatedSaleBanner(
                    banner: banner,
                    index: real,
                    onTap: () => _openBanner(real),
                  ),
                  _ => AnimatedPromoBanner(
                    banner: banner,
                    index: real,
                    onTap: () => _openBanner(real),
                  ),
                };
                return TickerMode(
                  enabled: real == _bannerPage,
                  child: Transform.scale(
                    scale: 1 - (delta * 0.035),
                    child: Opacity(opacity: 1 - (delta * 0.16), child: child),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < homeBanners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: i == _bannerPage ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _bannerPage
                          ? (_isPremium
                                ? OxroColors.premiumCream
                                : OxroColors.gold)
                          : (_isPremium
                                ? Colors.white.withValues(alpha: 0.34)
                                : Colors.white.withValues(alpha: 0.42)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendedDeals(BuildContext context) {
    final deals = RestaurantRepo.offers;
    if (deals.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.padX),
            child: const _DealsGlowHeader(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 326,
            child: GridView.builder(
              key: const ValueKey('home_deal_rail'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.padX),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 158,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: deals.length,
              itemBuilder: (context, i) {
                final deal = deals[_dealGridOrder(i, deals.length)];
                return _DealRestaurantCard(
                  restaurant: deal,
                  onTap: () => _openDeal(deal),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = 0.2 + 0.8 * _pulse.value;
        return GestureDetector(
          key: const ValueKey('food_mic'),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: OxroColors.coral,
                width: 1.2 + 0.8 * glow,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0x1A075F70,
                  ).withAlpha((0.15 + 0.45 * glow * 255).round().clamp(0, 255)),
                  blurRadius: 10 + 12 * glow,
                  spreadRadius: 0.5 + 2.5 * glow,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: OxroColors.coral.withAlpha(
                    (0.2 + 0.5 * glow * 255).round().clamp(0, 255),
                  ),
                  blurRadius: 6 + 10 * glow,
                  spreadRadius: 0.5 + 2.0 * glow,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: 23,
              color: OxroColors.coral.withAlpha(((0.6 + 0.4 * glow) * 255).round()),
            ),
          ),
        );
      },
    );
  }
}

class _Under250Tile extends StatelessWidget {
  const _Under250Tile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('home_under250'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE8C4), Color(0xFFFFA740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFE08000).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A18).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.0,
                      colors: [
                        const Color(0xFFFF7A18).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A18), Color(0xFFB32D00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF5A1F,
                            ).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 12,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'UNDER',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹250',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1,
                          letterSpacing: -0.3,
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
    );
  }
}

class _DealsGlowHeader extends StatefulWidget {
  const _DealsGlowHeader();

  @override
  State<_DealsGlowHeader> createState() => _DealsGlowHeaderState();
}

class _DealsGlowHeaderState extends State<_DealsGlowHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce == _reduced) return;
    _reduced = reduce;
    if (reduce) {
      _pulse.stop();
      _pulse.value = 0.4;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _reduced ? 0.4 : _pulse.value;
        final wave = (math.sin(t * math.pi * 2) + 1) / 2;
        final glow = 0.16 + 0.26 * wave;
        return Row(
          children: [
            Transform.scale(
              scale: 1.0 + 0.08 * wave,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OxroColors.primary.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.primary.withValues(alpha: glow),
                      blurRadius: 12 + 6 * wave,
                      spreadRadius: 1 + 2 * wave,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: Color.lerp(
                    OxroColors.orangeDark,
                    OxroColors.orangeBottom,
                    wave,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'RECOMMENDED WITH DEALS',
                key: ValueKey('home_deals_header'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OxroColors.muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CuisineStop {
  const _CuisineStop({
    required this.label,
    required this.icon,
    required this.image,
    this.cuisine,
    this.query,
  });

  final String label;
  final IconData icon;
  final String image;
  final String? cuisine;
  final String? query;
}

class _BestOffersTile extends StatefulWidget {
  const _BestOffersTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BestOffersTile> createState() => _BestOffersTileState();
}

class _BestOffersTileState extends State<_BestOffersTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce == _reduced) return;
    _reduced = reduce;
    if (reduce) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('home_best_offers'),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _reduced ? 0.5 : _pulse.value;
          final wave = (math.sin(t * math.pi * 2) + 1) / 2;
          final glow = 0.45 + 0.55 * wave;
          return SizedBox(
            width: 64,
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE8C4), Color(0xFFFFA740)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFE08000).withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7A18).withValues(alpha: 0.1),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NeonOfferPainter(progress: t, glow: glow * 0.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7A18), Color(0xFFB32D00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF5A1F,
                              ).withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'BEST\nOFFERS',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 7,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Explore',
                              style: TextStyle(
                                fontSize: 8,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 11,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NeonOfferPainter extends CustomPainter {
  const _NeonOfferPainter({required this.progress, required this.glow});

  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.8),
      const Radius.circular(10.5),
    );
    final borderShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB35C), Color(0xFFFF5A1F), Color(0xFFFF2D55)],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..shader = borderShader
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 3 * glow),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = borderShader,
    );

    canvas.save();
    canvas.clipRRect(rrect);
    final x = -size.width + progress * size.width * 2.4;
    final shineRect = Rect.fromLTWH(x, 0, size.width * 0.36, size.height);
    canvas.drawRect(
      shineRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)],
        ).createShader(shineRect),
    );
    canvas.restore();

    canvas.drawLine(
      Offset(size.width * 0.18, 1.4),
      Offset(size.width * 0.82, 1.4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14 + 0.24 * glow)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonOfferPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glow != glow;
}

class _VegToggle extends StatelessWidget {
  const _VegToggle({
    required this.active,
    required this.ink,
    required this.onTap,
  });

  final FoodPreference? active;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nonVeg = active == FoodPreference.nonVeg;
    final accent = nonVeg ? OxroColors.nonVegRed : OxroColors.vegGreen;
    final label = active == FoodPreference.nonVeg ? 'NON-VEG' : 'VEG';
    return GestureDetector(
      key: const ValueKey('home_veg_mode'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: FittedBox(
                key: ValueKey(label),
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: active == FoodPreference.nonVeg ? 7.2 : 8.5,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: active == null ? ink : accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            Text(
              'MODE',
              maxLines: 1,
              style: TextStyle(
                fontSize: 8.5,
                height: 0.95,
                fontWeight: FontWeight.w900,
                color: active == null ? ink : accent,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 34,
              height: 19,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: active == null ? const Color(0xFFD8DEE5) : accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: active == null
                    ? null
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                alignment: active == null
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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

class _PremiumPromoBanner extends StatelessWidget {
  const _PremiumPromoBanner({
    required this.banner,
    required this.index,
    required this.ambient,
    required this.onTap,
  });

  final HomeBanner banner;
  final int index;
  final Animation<double> ambient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ListenableBuilder(
      listenable: PremiumStore.instance,
      builder: (context, _) {
        final member = PremiumStore.instance.isMember;
        return AnimatedBuilder(
          animation: ambient,
          builder: (context, _) {
            final t = reduce ? 0.5 : ambient.value;
            final wave = math.sin(t * math.pi * 2);
            return GestureDetector(
              key: ValueKey('food_banner_$index'),
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OxroColors.premiumDeep,
                            OxroColors.premiumBurgundy,
                            OxroColors.premiumWine,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PremiumAmbientPainter(progress: t),
                    ),
                  ),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 680),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 18 + wave * 1.4),
                          child: Transform.rotate(
                            angle: -0.022 + wave * 0.004,
                            child: child,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rs(18),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            key: ValueKey('premium_banner_card_$index'),
                            padding: EdgeInsets.fromLTRB(
                              context.rs(18),
                              context.rs(16),
                              context.rs(18),
                              context.rs(15),
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  OxroColors.premiumCream,
                                  OxroColors.premiumCreamDeep,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: OxroColors.premiumChampagne.withValues(
                                  alpha: 0.9,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 22,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        color: OxroColors.premiumBurgundy,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 15,
                                        color: OxroColors.premiumCream,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'OXRO PREMIUM',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.1,
                                          color: OxroColors.premiumBurgundy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: OxroColors.premiumBurgundy
                                            .withValues(alpha: 0.09),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: OxroColors.premiumBurgundy
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Text(
                                        member ? 'ACTIVE' : '3 MONTHS ₹1',
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                          color: OxroColors.premiumBurgundy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'FREE DELIVERY',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: context.font(27),
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: OxroColors.premiumBurgundy,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'on orders above ₹199',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: OxroColors.premiumMuted,
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  color: OxroColors.premiumChampagne.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        member
                                            ? 'PREMIUM is active'
                                            : '3 months at ₹1 • cancel anytime',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: OxroColors.premiumMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      key: ValueKey('banner_cta_$index'),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        7,
                                        8,
                                        7,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            OxroColors.premiumBurgundy,
                                            OxroColors.premiumWine,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            member ? 'Manage' : 'Join at ₹1',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: OxroColors.premiumCream,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 13,
                                            color: OxroColors.premiumCream,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Burgundy membership hero ambience: rose glow, champagne dust, soft rings.
class _PremiumAmbientPainter extends CustomPainter {
  const _PremiumAmbientPainter({required this.progress});

  final double progress;

  static const _sparkles = [
    Offset(0.10, 0.18),
    Offset(0.20, 0.42),
    Offset(0.31, 0.12),
    Offset(0.72, 0.16),
    Offset(0.88, 0.30),
    Offset(0.93, 0.52),
    Offset(0.12, 0.74),
    Offset(0.79, 0.70),
    Offset(0.27, 0.87),
    Offset(0.68, 0.90),
    Offset(0.48, 0.07),
    Offset(0.56, 0.94),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = progress * math.pi * 2;
    final wave = math.sin(phase);

    _glow(
      canvas,
      Offset(w * (0.16 + 0.03 * wave), h * (0.18 + 0.02 * math.cos(phase))),
      w * 0.56,
      OxroColors.premiumRose,
      0.30,
    );
    _glow(
      canvas,
      Offset(w * (0.88 - 0.03 * wave), h * (0.82 + 0.02 * wave)),
      w * 0.50,
      OxroColors.premiumChampagne,
      0.14,
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = OxroColors.premiumCream.withValues(alpha: 0.12);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * 0.82, h * 0.12),
        w * (0.20 + 0.075 * i) + wave * 2,
        ring,
      );
    }

    for (var i = 0; i < _sparkles.length; i++) {
      final seed = _sparkles[i];
      final bob = math.sin(phase * 1.3 + i * 1.4);
      final twinkle = 0.3 + 0.7 * ((math.sin(phase * 2 + i) + 1) / 2);
      _sparkle(
        canvas,
        Offset(w * seed.dx + bob * 3, h * seed.dy + bob * 6),
        i.isEven ? 2.8 : 1.8,
        OxroColors.premiumChampagne.withValues(alpha: 0.55 * twinkle),
      );
    }
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double a,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
    canvas.drawCircle(center, radius * 0.35, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PremiumAmbientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Interleaves the two rows of the deal grid so each column mixes the feed.
int _dealGridOrder(int i, int length) {
  if (length <= 1) return 0;
  final half = (length + 1) ~/ 2;
  return i.isEven ? i ~/ 2 : half + i ~/ 2;
}

class _DealRestaurantCard extends StatelessWidget {
  const _DealRestaurantCard({required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  bool get _nearAndFast => restaurant.etaMinutes <= 30;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('home_deal_restaurant_${restaurant.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(
                    imageUrl: restaurant.imageUrl,
                    colors: const [Color(0xFFE7F8FA), Color(0xFFC8EDF1)],
                    icon: Icons.restaurant_outlined,
                    width: double.infinity,
                    height: 100,
                    radius: 12,
                  ),
                  if (restaurant.hasOffer)
                    Positioned(
                      left: 8,
                      top: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              restaurant.offerText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.green,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: OxroColors.dark,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                _nearAndFast ? Icons.bolt_rounded : Icons.access_time_rounded,
                size: 14,
                color: _nearAndFast ? OxroColors.green : OxroColors.muted,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  _nearAndFast ? 'Near & Fast' : restaurant.etaRangeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _nearAndFast ? OxroColors.green : OxroColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPalette {
  const _HeaderPalette({
    required this.top,
    required this.bottom,
    required this.scrolled,
    required this.pattern,
    required this.ink,
    required this.inkSoft,
    required this.pillBg,
    required this.pillBorder,
  });

  final Color top;
  final Color bottom;
  final Color scrolled;
  final Color pattern;
  final Color ink;
  final Color inkSoft;
  final Color pillBg;
  final Color pillBorder;
}

/// Header tint that echoes the active banner without copying it: the banner's
/// hue is nudged a few degrees and pushed to a deep, muted tone.
_HeaderPalette _headerPaletteFor(HomeBanner banner) {
  if (banner.style == BannerStyle.premium) {
    return _HeaderPalette(
      top: OxroColors.premiumDeep,
      bottom: OxroColors.premiumBurgundy,
      scrolled: const Color(0xFF370A1B),
      pattern: OxroColors.premiumCream,
      ink: OxroColors.premiumCream,
      inkSoft: OxroColors.premiumCream.withValues(alpha: 0.68),
      pillBg: Colors.white.withValues(alpha: 0.14),
      pillBorder: Colors.white.withValues(alpha: 0.24),
    );
  }
  final base = banner.colors.isNotEmpty ? banner.colors.first : OxroColors.teal;
  final deep = banner.colors.length > 1 ? banner.colors.last : base;
  final hsl = HSLColor.fromColor(base);
  final shifted = hsl
      .withHue((hsl.hue + 8) % 360)
      .withSaturation((hsl.saturation * 0.82).clamp(0.2, 0.78));
  final top = Color.lerp(shifted.withLightness(0.34).toColor(), deep, 0.1)!;
  final bottom = Color.lerp(shifted.withLightness(0.24).toColor(), deep, 0.12)!;
  final scrolled = Color.lerp(
    shifted.withLightness(0.2).toColor(),
    deep,
    0.12,
  )!;
  final useWhiteInk = top.computeLuminance() < 0.45;
  final ink = useWhiteInk ? Colors.white : OxroColors.charcoal;
  return _HeaderPalette(
    top: top,
    bottom: bottom,
    scrolled: scrolled,
    pattern: ink,
    ink: ink,
    inkSoft: ink.withValues(alpha: 0.7),
    pillBg: useWhiteInk
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.38),
    pillBorder: useWhiteInk
        ? Colors.white.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.08),
  );
}

class _HeaderWash extends StatelessWidget {
  const _HeaderWash({required this.palette});

  final _HeaderPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.top, palette.bottom],
            ),
          ),
        ),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: palette.pattern, end: palette.pattern),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) => CustomPaint(
            painter: _HeaderPatternPainter(base: color ?? palette.pattern),
          ),
        ),
      ],
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  const _HeaderPatternPainter({required this.base});

  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = base.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dot = Paint()..color = base.withValues(alpha: 0.10);
    final center = Offset(size.width - 24, size.height * 0.2);

    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 18.0 * i, line);
    }
    for (var i = 0; i < 18; i++) {
      final x = (i * 47.0) % size.width;
      final y = 14.0 + ((i * 31.0) % (size.height - 28));
      canvas.drawCircle(Offset(x, y), 1.6, dot);
    }
    canvas.drawArc(
      Rect.fromCircle(center: Offset(10, size.height), radius: 68),
      math.pi,
      math.pi / 2,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPatternPainter oldDelegate) =>
      oldDelegate.base != base;
}

class _DishRail extends StatelessWidget {
  const _DishRail({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Product> products;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.padX),
            child: SectionHeader(title: title, subtitle: subtitle),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 194,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.padX),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 11),
              itemBuilder: (context, i) {
                final p = products[i];
                return GestureDetector(
                  key: ValueKey('rail_dish_${p.id}'),
                  onTap: () => onTap(p),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 148,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OxroColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D051D47),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            FoodImage(
                              imageUrl: p.imageUrl,
                              colors: p.colors,
                              icon: p.icon,
                              width: 148,
                              height: 104,
                              radius: 15,
                            ),
                            if (p.off > 0)
                              Positioned(
                                left: 7,
                                top: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: OxroColors.offerGradient,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${p.off}% OFF',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 7,
                              bottom: 7,
                              child: RatingChip(
                                rating: p.rating,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 0),
                          child: Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 4, 9, 9),
                          child: Row(
                            children: [
                              Text(
                                Product.inr(p.price),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: OxroColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionRail extends StatelessWidget {
  const _CollectionRail({required this.collection, required this.onTap});

  final RestaurantCollection collection;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.padX),
            child: SectionHeader(
              title: collection.title,
              subtitle: collection.subtitle,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              key: ValueKey('collection_${collection.title}'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.padX),
              itemCount: collection.restaurants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 11),
              itemBuilder: (context, i) {
                final r = collection.restaurants[i];
                return GestureDetector(
                  onTap: () => onTap(r.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 278,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OxroColors.border),
                    ),
                    child: Row(
                      children: [
                        FoodImage(
                          imageUrl: r.imageUrl,
                          colors: const [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
                          icon: Icons.restaurant,
                          width: 70,
                          height: 70,
                          radius: 12,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  RatingChip(rating: r.rating, compact: true),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '${r.etaLabel}  •  ${r.distanceLabel}',
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
                              const SizedBox(height: 4),
                              Text(
                                r.cuisineLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: OxroColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered entrance used by Home sections. Honours reduced-motion settings.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.055),
      end: Offset.zero,
    ).animate(curve);
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce && !_reduced) {
      _reduced = true;
      _timer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
