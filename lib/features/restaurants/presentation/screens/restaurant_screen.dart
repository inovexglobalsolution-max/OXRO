import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/dashed_divider.dart';
import 'package:oxro/app/widgets/dish_row.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/cart/presentation/quick_add.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

enum _DishFilter { veg, egg, nonVeg }

class _RestaurantScreenState extends State<RestaurantScreen> {
  static const _menuBarHeight = 96.0;

  final _scroll = ScrollController();
  final _chipScroll = ScrollController();
  final _sectionKeys = <GlobalKey>[];
  final _chipKeys = <GlobalKey>[];
  final _collapsed = <int>{};
  int _activeSection = 0;
  FoodPreference? _diet;
  _DishFilter? _filter;

  Restaurant? get _restaurant => RestaurantRepo.byId(widget.restaurantId);

  @override
  void initState() {
    super.initState();
    _diet = FoodPreferenceStore.instance.activeFilter;
    FoodPreferenceStore.instance.addListener(_onPreferenceChanged);
    _scroll.addListener(_onMenuScroll);
  }

  @override
  void dispose() {
    FoodPreferenceStore.instance.removeListener(_onPreferenceChanged);
    _scroll.removeListener(_onMenuScroll);
    _scroll.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  void _onPreferenceChanged() {
    final next = FoodPreferenceStore.instance.activeFilter;
    if (!mounted || next == _diet) return;
    setState(() {
      _diet = next;
      _activeSection = 0;
    });
  }

  void _openDish(Product dish) {
    pushScreen(context, ProductDetailScreen(product: dish));
  }

  void _openCart() {
    pushScreen(
      context,
      BagScreen(onShopNow: () => Navigator.of(context).maybePop()),
    );
  }

  Future<void> _addDish(Product dish) => quickAddProduct(context, dish);

  bool _keepDish(Product dish) {
    switch (_filter) {
      case _DishFilter.veg:
        return dish.veg;
      case _DishFilter.egg:
        return dish.egg;
      case _DishFilter.nonVeg:
        // Egg dishes are non-veg too; the Egg chip narrows further.
        return !dish.veg;
      case null:
        break;
    }
    final diet = _diet;
    if (diet == null) return true;
    return diet == FoodPreference.veg ? dish.veg : !dish.veg;
  }

  List<MenuSection> _sectionsFor(
    Restaurant r, {
    Set<int> excludeIds = const {},
  }) {
    return [
      for (final section in r.menu)
        if (section.dishes.any(
          (d) => _keepDish(d) && !excludeIds.contains(d.id),
        ))
          MenuSection(
            title: section.title,
            dishes: [
              for (final dish in section.dishes)
                if (_keepDish(dish) && !excludeIds.contains(dish.id)) dish,
            ],
          ),
    ];
  }

  List<MenuSection> _menuFor(Restaurant r) {
    final base = _sectionsFor(r);
    final all = [for (final section in base) ...section.dishes];
    final unique = <int, Product>{
      for (final dish in all) dish.id: dish,
    }.values.toList();
    if (unique.length < 4) return base;
    final picks = unique..sort((a, b) => b.reviews.compareTo(a.reviews));
    final recommended = picks.take(4).toList();
    final exclude = {for (final dish in recommended) dish.id};
    return [
      MenuSection(title: 'Recommended for you', dishes: recommended),
      ..._sectionsFor(r, excludeIds: exclude),
    ];
  }

  ({IconData icon, Color color, String title, String body}) _emptyMenuState() {
    switch (_filter) {
      case _DishFilter.veg:
        return (
          icon: Icons.eco_rounded,
          color: OxroColors.vegGreen,
          title: 'No veg dishes in this menu',
          body: 'Try another filter or reset to see the full menu.',
        );
      case _DishFilter.egg:
        return (
          icon: Icons.egg_alt_outlined,
          color: const Color(0xFFD97706),
          title: 'No egg dishes in this menu',
          body: 'Try another filter or reset to see the full menu.',
        );
      case _DishFilter.nonVeg:
        return (
          icon: Icons.local_fire_department_rounded,
          color: OxroColors.nonVegRed,
          title: 'No non-veg dishes in this menu',
          body: 'Try another filter or reset to see the full menu.',
        );
      case null:
        break;
    }
    switch (_diet) {
      case FoodPreference.veg:
        return (
          icon: Icons.eco_rounded,
          color: OxroColors.vegGreen,
          title: 'No veg dishes in this menu',
          body: 'Turn off the food preference to see everything.',
        );
      case FoodPreference.nonVeg:
        return (
          icon: Icons.local_fire_department_rounded,
          color: OxroColors.nonVegRed,
          title: 'No non-veg dishes in this menu',
          body: 'Turn off the food preference to see everything.',
        );
      case null:
        return (
          icon: Icons.restaurant_menu_rounded,
          color: OxroColors.muted,
          title: 'This menu is being refreshed',
          body: 'Please check back in a moment.',
        );
    }
  }

  void _ensureKeys(int count) {
    while (_sectionKeys.length < count) {
      _sectionKeys.add(GlobalKey());
    }
    while (_chipKeys.length < count) {
      _chipKeys.add(GlobalKey());
    }
    if (_sectionKeys.length > count) {
      _sectionKeys.removeRange(count, _sectionKeys.length);
    }
    if (_chipKeys.length > count) {
      _chipKeys.removeRange(count, _chipKeys.length);
    }
  }

  Map<int, String> _badgesFor(Restaurant r) {
    final sorted = [...r.dishes]
      ..sort((a, b) => b.reviews.compareTo(a.reviews));
    final out = <int, String>{};
    for (final dish in sorted.take(2)) {
      out[dish.id] = 'Bestseller';
    }
    final recommended =
        sorted.where((d) => !out.containsKey(d.id) && d.rating >= 4.2).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
    for (final dish in recommended.take(2)) {
      out[dish.id] = 'Recommended';
    }
    return out;
  }

  void _onMenuScroll() {
    if (!_scroll.hasClients || _sectionKeys.isEmpty) return;
    final threshold =
        MediaQuery.paddingOf(context).top + kToolbarHeight + _menuBarHeight + 8;
    var active = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        active = i;
      } else {
        break;
      }
    }
    if (active != _activeSection) {
      setState(() => _activeSection = active);
      _revealChip(active);
    }
  }

  void _revealChip(int index) {
    if (index < 0 || index >= _chipKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chipScroll.hasClients) return;
      final ctx = _chipKeys[index].currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final viewport = RenderAbstractViewport.of(box);
      final target = viewport
          .getOffsetToReveal(box, 0.5)
          .offset
          .clamp(0.0, _chipScroll.position.maxScrollExtent)
          .toDouble();
      _chipScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToSection(int index, List<MenuSection> sections) {
    if (index < 0 || index >= sections.length) return;
    setState(() => _activeSection = index);
    _revealChip(index);

    final ctx = _sectionKeys[index].currentContext;
    final box = ctx?.findRenderObject();
    if (box is RenderBox && box.attached && _scroll.hasClients) {
      final viewport = RenderAbstractViewport.of(box);
      final reveal = viewport.getOffsetToReveal(box, 0).offset;
      final header =
          MediaQuery.paddingOf(context).top + kToolbarHeight + _menuBarHeight;
      final target = (reveal - header)
          .clamp(0.0, _scroll.position.maxScrollExtent)
          .toDouble();
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final approx = max * (index + 1) / (sections.length + 1);
    _scroll.animateTo(
      approx.clamp(0.0, max).toDouble(),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _setFilter(_DishFilter? filter) {
    setState(() {
      _filter = _filter == filter ? null : filter;
      _activeSection = 0;
      _collapsed.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = _restaurant;
      if (r == null) return;
      _jumpToSection(0, _menuFor(r));
    });
  }

  void _openFilters(Restaurant r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        void pick(_DishFilter filter) {
          Navigator.of(sheetContext).pop();
          _setFilter(filter);
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const Spacer(),
                    if (_filter != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _setFilter(_filter);
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.coral,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Diet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DietChip(
                      chipKey: const ValueKey('restaurant_filters_veg'),
                      label: 'Veg',
                      mark: const VegMark(veg: true, size: 18),
                      selected: _filter == _DishFilter.veg,
                      onTap: () => pick(_DishFilter.veg),
                    ),
                    if (!r.pureVeg) ...[
                      _DietChip(
                        chipKey: const ValueKey('restaurant_filters_egg'),
                        label: 'Egg',
                        mark: const VegMark(veg: false, egg: true, size: 18),
                        selected: _filter == _DishFilter.egg,
                        onTap: () => pick(_DishFilter.egg),
                      ),
                      _DietChip(
                        chipKey: const ValueKey('restaurant_filters_nonveg'),
                        label: 'Non-veg',
                        mark: const VegMark(veg: false, size: 18),
                        selected: _filter == _DishFilter.nonVeg,
                        onTap: () => pick(_DishFilter.nonVeg),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openOffers(Restaurant r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available offers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 16,
                    color: OxroColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.hasOffer
                          ? r.offerText
                          : 'Use code WELCOME50 for ₹50 off on your order.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OxroColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInfo(Restaurant r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${r.cuisineLabel}  ·  ${r.locality}',
                style: const TextStyle(fontSize: 12, color: OxroColors.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  RatingChip(rating: r.rating),
                  const SizedBox(width: 8),
                  Text(
                    '${r.ratingCount ~/ 100 / 10}K ratings',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OxroColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${r.etaLabel}  ·  ${Product.inr(r.costForTwo)} for two',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: OxroColors.charcoal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenuIndex(Restaurant r, List<MenuSection> sections) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          key: const ValueKey('restaurant_menu_index'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Jump to menu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OxroColors.charcoal,
                ),
              ),
            ),
            for (var i = 0; i < sections.length; i++)
              ListTile(
                key: ValueKey('restaurant_menu_index_$i'),
                title: Text(
                  sections[i].title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal,
                  ),
                ),
                trailing: Text(
                  '${sections[i].dishes.length}',
                  style: const TextStyle(fontSize: 12, color: OxroColors.muted),
                ),
                onTap: () => Navigator.of(context).pop(i),
              ),
          ],
        ),
      ),
    );
    if (index != null && mounted) _jumpToSection(index, sections);
  }

  Future<void> _openMenuSearch(Restaurant r) async {
    final dish = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _MenuSearchSheet(restaurant: r),
    );
    if (dish != null && mounted) _openDish(dish);
  }

  Widget _buildMenuBar(
    BuildContext context,
    Restaurant r,
    List<MenuSection> sections,
    int active,
  ) {
    final dishCount = sections.fold<int>(
      0,
      (sum, section) => sum + section.dishes.length,
    );
    return Container(
      key: const ValueKey('restaurant_menu_bar'),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: OxroColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F051D47),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(context.padX, 4, context.padX, 6),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                const Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OxroColors.charcoal,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$dishCount ${dishCount == 1 ? 'dish' : 'dishes'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: OxroColors.muted,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  key: const ValueKey('restaurant_menu_index_button'),
                  onTap: () => _openMenuIndex(r, sections),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OxroColors.pageBg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: OxroColors.border),
                    ),
                    child: const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 17,
                      color: OxroColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              controller: _chipScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 3),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == active;
                return KeyedSubtree(
                  key: _chipKeys[i],
                  child: GestureDetector(
                    key: ValueKey('restaurant_section_chip_$i'),
                    onTap: () => _jumpToSection(i, sections),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? OxroColors.primary
                            : OxroColors.pageBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? OxroColors.primary
                              : OxroColors.border,
                        ),
                      ),
                      child: Text(
                        sections[i].title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : OxroColors.charcoal,
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
  }

  @override
  Widget build(BuildContext context) {
    final r = _restaurant;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurant')),
        body: const Center(child: Text('Restaurant not found')),
      );
    }
    final sections = _menuFor(r);
    _ensureKeys(sections.length);
    final empty = _emptyMenuState();
    final badges = _badgesFor(r);
    final active = sections.isEmpty
        ? 0
        : (_activeSection >= sections.length
              ? sections.length - 1
              : _activeSection);
    return Scaffold(
      key: const ValueKey('restaurant_screen'),
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: OxroColors.charcoal,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: OxroColors.border,
            leading: IconButton(
              key: const ValueKey('restaurant_back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            titleSpacing: 0,
            title: GestureDetector(
              key: const ValueKey('restaurant_menu_search'),
              onTap: () => _openMenuSearch(r),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 38,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: OxroColors.pageBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OxroColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: OxroColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Search in ${r.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OxroColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                key: const ValueKey('restaurant_more'),
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _openInfo(r),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      color: OxroColors.charcoal,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  key: const ValueKey('restaurant_info'),
                                  onTap: () => _openInfo(r),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: OxroColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    r.cuisineLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: OxroColors.muted,
                                    ),
                                  ),
                                ),
                                if (r.pureVeg) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: OxroColors.vegGreen.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PURE VEG',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: OxroColors.vegGreen,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RatingBadge(rating: r.rating),
                          const SizedBox(height: 4),
                          Text(
                            '${r.ratingCount ~/ 100 / 10}K ratings',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: OxroColors.muted,
                              decoration: TextDecoration.underline,
                              decorationColor: OxroColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: OxroColors.charcoal,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${r.distanceLabel}  ·  ${r.locality}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 17,
                        color: OxroColors.charcoal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: OxroColors.charcoal,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${r.etaRangeLabel}  ·  Schedule for later',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 17,
                        color: OxroColors.charcoal,
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: OxroColors.border),
                  ),
                  GestureDetector(
                    key: const ValueKey('restaurant_offer_summary'),
                    onTap: () => _openOffers(r),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_rounded,
                          size: 19,
                          color: OxroColors.coral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Free Delivery above ${Product.inr(r.minOrder)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.hasOffer ? '1 offer' : 'Offers',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: OxroColors.muted,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 17,
                          color: OxroColors.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: ColoredBox(
              color: OxroColors.pageBg,
              child: SizedBox(height: 8, width: double.infinity),
            ),
          ),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.padX, 10, 0, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(right: context.padX),
                  child: Row(
                    children: [
                      _DietChip(
                        chipKey: const ValueKey('restaurant_filters'),
                        label: 'Filters',
                        mark: const Icon(
                          Icons.tune_rounded,
                          size: 17,
                          color: OxroColors.charcoal,
                        ),
                        trailing: const Icon(
                          Icons.expand_more_rounded,
                          size: 17,
                          color: OxroColors.charcoal,
                        ),
                        selected: false,
                        onTap: () => _openFilters(r),
                      ),
                      const SizedBox(width: 8),
                      _DietChip(
                        chipKey: const ValueKey('restaurant_filter_veg'),
                        label: 'Veg',
                        mark: const VegMark(veg: true, size: 18),
                        selected: _filter == _DishFilter.veg,
                        onTap: () => _setFilter(_DishFilter.veg),
                      ),
                      if (!r.pureVeg) ...[
                        const SizedBox(width: 8),
                        _DietChip(
                          chipKey: const ValueKey('restaurant_filter_egg'),
                          label: 'Egg',
                          mark: const VegMark(veg: false, egg: true, size: 18),
                          selected: _filter == _DishFilter.egg,
                          onTap: () => _setFilter(_DishFilter.egg),
                        ),
                        const SizedBox(width: 8),
                        _DietChip(
                          chipKey: const ValueKey('restaurant_filter_nonveg'),
                          label: 'Non-veg',
                          mark: const VegMark(veg: false, size: 18),
                          selected: _filter == _DishFilter.nonVeg,
                          onTap: () => _setFilter(_DishFilter.nonVeg),
                        ),
                      ],
                      if (_filter != null) ...[
                        const SizedBox(width: 8),
                        _DietChip(
                          chipKey: const ValueKey('restaurant_filter_reset'),
                          label: 'Reset',
                          mark: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: OxroColors.coral,
                          ),
                          selected: false,
                          onTap: () => _setFilter(_filter),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _MenuBarDelegate(
              height: _menuBarHeight,
              child: _buildMenuBar(context, r, sections, active),
            ),
          ),
          if (sections.isEmpty) ...[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                key: const ValueKey('restaurant_empty_menu'),
                alignment: Alignment.center,
                padding: EdgeInsets.fromLTRB(
                  context.padX,
                  24,
                  context.padX,
                  36,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(empty.icon, size: 34, color: empty.color),
                    const SizedBox(height: 10),
                    Text(
                      empty.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      empty.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OxroColors.muted,
                      ),
                    ),
                    if (_filter != null) ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        key: const ValueKey('restaurant_empty_reset'),
                        onPressed: () => _setFilter(_filter),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Show all dishes'),
                        style: TextButton.styleFrom(
                          foregroundColor: OxroColors.coral,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ] else if (_diet != null) ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        key: const ValueKey('restaurant_empty_preference'),
                        onPressed: () {
                          FoodPreferenceStore.instance.disable();
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Turn off food preference'),
                        style: TextButton.styleFrom(
                          foregroundColor: OxroColors.coral,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.padX,
                        14,
                        context.padX,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            key: _sectionKeys[i],
                            child: InkWell(
                              key: ValueKey('restaurant_section_toggle_$i'),
                              onTap: () => setState(() {
                                if (!_collapsed.remove(i)) _collapsed.add(i);
                              }),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sections[i].title,
                                        key: ValueKey(
                                          'restaurant_section_header_$i',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: OxroColors.charcoal,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _collapsed.contains(i)
                                          ? Icons.expand_more_rounded
                                          : Icons.expand_less_rounded,
                                      size: 19,
                                      color: OxroColors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!_collapsed.contains(i))
                            for (final dish in sections[i].dishes) ...[
                              DishRow(
                                dish: dish,
                                badge: badges[dish.id],
                                reordered: badges[dish.id] == 'Bestseller',
                                onTap: () => _openDish(dish),
                                onAdd: () => _addDish(dish),
                              ),
                              const DashedDivider(),
                            ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ],
      ),
      floatingActionButton: _activeSection > 0
          ? FloatingActionButton.small(
              key: const ValueKey('restaurant_menu_fab'),
              heroTag: null,
              backgroundColor: OxroColors.charcoal,
              foregroundColor: Colors.white,
              onPressed: () => _openMenuIndex(r, sections),
              child: const Icon(Icons.menu_rounded, size: 20),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const ValueKey('restaurant_offer_strip'),
              onTap: () => _openOffers(r),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: const Color(0xFFEAF2FF),
                child: Row(
                  children: [
                    const Icon(
                      Icons.discount_rounded,
                      size: 15,
                      color: Color(0xFF2F6FE0),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        r.hasOffer
                            ? r.offerText
                            : 'Use WELCOME50 · ₹50 off your order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ),
                    const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F6FE0),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF2F6FE0),
                    ),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: CartStore.instance,
              builder: (context, _) {
                final count = CartStore.instance.count;
                if (count == 0) return const SizedBox.shrink();
                final total = CartStore.instance.totalPrice;
                return GestureDetector(
                  key: const ValueKey('restaurant_cart_bar'),
                  onTap: _openCart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      context.padX,
                      8,
                      context.padX,
                      8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: OxroColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$count ${count == 1 ? 'item' : 'items'} · ${Product.inr(total)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'VIEW CART',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DietChip extends StatelessWidget {
  const _DietChip({
    required this.chipKey,
    required this.label,
    required this.mark,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final Key chipKey;
  final String label;
  final Widget mark;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: chipKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? OxroColors.charcoal : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OxroColors.charcoal : OxroColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : OxroColors.charcoal,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

class _MenuBarDelegate extends SliverPersistentHeaderDelegate {
  const _MenuBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _MenuBarDelegate oldDelegate) => true;
}

class _MenuSearchSheet extends StatefulWidget {
  const _MenuSearchSheet({required this.restaurant});

  final Restaurant restaurant;

  @override
  State<_MenuSearchSheet> createState() => _MenuSearchSheetState();
}

class _MenuSearchSheetState extends State<_MenuSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <Product>[]
        : widget.restaurant.dishes
              .where(
                (dish) =>
                    dish.name.toLowerCase().contains(q) ||
                    dish.description.toLowerCase().contains(q) ||
                    dish.brand.toLowerCase().contains(q),
              )
              .take(30)
              .toList();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * 0.82 - inset)
        .clamp(280.0, 720.0)
        .toDouble();

    return Padding(
      key: const ValueKey('menu_search_sheet'),
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: OxroColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Search this menu',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.charcoal,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('menu_search_close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: OxroColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: OxroColors.pageBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OxroColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: OxroColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('menu_search_field'),
                        controller: _ctrl,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Try biryani, paneer, dosa…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: OxroColors.muted,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        key: const ValueKey('menu_search_clear'),
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _query = '');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: OxroColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: OxroColors.border),
            Expanded(
              child: q.isEmpty
                  ? const _MenuSearchIdle()
                  : results.isEmpty
                  ? const Center(
                      child: Padding(
                        key: ValueKey('menu_search_empty'),
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 34,
                              color: OxroColors.muted,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No dishes found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.charcoal,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Try a shorter dish name or another craving.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: OxroColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const DashedDivider(),
                      itemBuilder: (context, i) =>
                          _menuResult(context, results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuResult(BuildContext context, Product dish) {
    return GestureDetector(
      key: ValueKey('menu_search_result_${dish.id}'),
      onTap: () => Navigator.of(context).pop(dish),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            FoodImage(
              imageUrl: dish.imageUrl,
              colors: dish.colors,
              icon: dish.icon,
              width: 50,
              height: 50,
              radius: 11,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegMark(veg: dish.veg, size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${Product.inr(dish.price)}  ·  ${dish.rating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OxroColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: OxroColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSearchIdle extends StatelessWidget {
  const _MenuSearchIdle();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color: OxroColors.border,
            ),
            SizedBox(height: 12),
            Text(
              'Find a dish faster',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Search by dish name, ingredient or craving.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: OxroColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
