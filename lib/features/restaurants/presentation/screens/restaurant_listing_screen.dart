import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/dashed_divider.dart';
import 'package:oxro/app/widgets/filter_chip_row.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/presentation/quick_add.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';
import 'package:oxro/features/restaurants/presentation/widgets/restaurant_menu_section.dart';

class _ListingTab {
  const _ListingTab(this.label, {this.dish});

  final String label;
  final Product? dish;
}

class RestaurantListingScreen extends StatefulWidget {
  const RestaurantListingScreen({
    super.key,
    this.title = 'Restaurants',
    this.cuisine,
    this.query,
    this.initialFilters = const RestaurantFilters(),
  });

  final String title;
  final String? cuisine;

  /// Free-text match against restaurant names, cuisines and dish names.
  final String? query;
  final RestaurantFilters initialFilters;

  @override
  State<RestaurantListingScreen> createState() =>
      _RestaurantListingScreenState();
}

class _RestaurantListingScreenState extends State<RestaurantListingScreen> {
  late RestaurantFilters _filters = widget.initialFilters;
  RestaurantSort _sort = RestaurantSort.relevance;
  String? _tab;

  List<Restaurant> get _baseResults {
    final cuisine = widget.cuisine;
    var base = cuisine == null
        ? RestaurantRepo.all
        : RestaurantRepo.forCuisine(cuisine);
    final q = widget.query?.trim().toLowerCase() ?? '';
    if (q.isNotEmpty) {
      base = [
        for (final r in base)
          if (r.name.toLowerCase().contains(q) ||
              r.cuisines.any((c) => c.toLowerCase().contains(q)) ||
              r.menu.any(
                (section) =>
                    section.dishes.any((d) => d.name.toLowerCase().contains(q)),
              ))
            r,
      ];
    }
    return sortRestaurants(filterRestaurants(base, _filters), _sort);
  }

  List<Restaurant> get _results {
    final tab = _tab;
    final base = _baseResults;
    if (tab == null) return base;
    final q = tab.toLowerCase();
    return [
      for (final r in base)
        if (r.menu.any(
          (section) => section.dishes.any(
            (d) => d.name.toLowerCase().contains(q),
          ),
        ))
          r,
    ];
  }

  List<Product> get _allDishes => [
    for (final r in _baseResults) ...r.dishes,
  ]..sort((a, b) => b.reviews.compareTo(a.reviews));

  List<_ListingTab> _tabsFor(List<Product> pool) {
    final cuisine = widget.cuisine;
    final subcats = cuisine == null
        ? const <String>[]
        : subcategoriesFor(cuisine);
    final labels = <String>[];
    if (subcats.isNotEmpty) {
      for (final sub in subcats) {
        if (labels.length >= 6) break;
        labels.add(sub);
      }
    } else {
      for (final dish in pool) {
        if (labels.length >= 6) break;
        final name = dish.name.trim();
        if (name.isEmpty || labels.contains(name)) continue;
        labels.add(name);
      }
    }
    return [
      if (pool.isNotEmpty) _ListingTab('All', dish: pool.first),
      for (final label in labels)
        _ListingTab(label, dish: _matchDish(pool, label)),
    ];
  }

  Product? _matchDish(List<Product> pool, String label) {
    final q = label.toLowerCase();
    for (final dish in pool) {
      if (dish.name.toLowerCase().contains(q)) return dish;
    }
    return null;
  }

  Widget _buildTabs(BuildContext context, List<_ListingTab> tabs) {
    final selectedLabel = _tab ?? 'All';
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          key: const ValueKey('listing_tabs'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 4),
          itemCount: tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final tab = tabs[i];
            final selected = selectedLabel == tab.label;
            final dish = tab.dish;
            return GestureDetector(
              key: ValueKey('listing_tab_$i'),
              onTap: () => setState(() {
                _tab = tab.label == 'All' ? null : tab.label;
              }),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 68,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OxroColors.pageBg,
                        border: Border.all(
                          color: selected
                              ? OxroColors.coral
                              : OxroColors.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: dish != null
                          ? FoodImage(
                              imageUrl: dish.imageUrl,
                              colors: dish.colors,
                              icon: dish.icon,
                              width: 58,
                              height: 58,
                              radius: 29,
                            )
                          : Icon(
                              foodCategoryFor(widget.cuisine ?? '')?.icon ??
                                  Icons.restaurant_menu,
                              size: 23,
                              color: OxroColors.muted,
                            ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? OxroColors.coral
                            : OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: selected ? 26 : 0,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: OxroColors.coral,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = _allDishes;
    final tabs = _tabsFor(pool);
    final results = _results;
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: OxroColors.charcoal,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${results.length} restaurants',
              key: const ValueKey('restaurant_count'),
              style: const TextStyle(
                fontSize: 11,
                color: OxroColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<RestaurantSort>(
            key: const ValueKey('restaurant_sort'),
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final entry in restaurantSortLabels.entries)
                PopupMenuItem<RestaurantSort>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (tabs.isNotEmpty) _buildTabs(context, tabs),
          ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.padX, 4, 0, 10),
              child: FilterChipRow(
                padding: EdgeInsets.only(right: context.padX),
                chips: [
                  if (_filters.foodPreference != null)
                    OxroFilterChip(
                      key: const ValueKey('restaurant_filter_food_preference'),
                      label: _filters.foodPreference == FoodPreference.veg
                          ? 'Veg only'
                          : 'Non-Veg only',
                      icon: _filters.foodPreference == FoodPreference.veg
                          ? Icons.eco_rounded
                          : Icons.local_fire_department_rounded,
                      selected: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(clearFoodPreference: true);
                      }),
                    ),
                  OxroFilterChip(
                    key: const ValueKey('restaurant_filter_veg'),
                    label: 'Pure Veg',
                    icon: Icons.eco_outlined,
                    selected: _filters.pureVeg,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(pureVeg: !_filters.pureVeg);
                    }),
                  ),
                  OxroFilterChip(
                    key: const ValueKey('restaurant_filter_fast'),
                    label: 'Near & Fast',
                    icon: Icons.bolt_rounded,
                    selected: _filters.under30,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(under30: !_filters.under30);
                    }),
                  ),
                  if (_filters.maxCostForTwo != null)
                    OxroFilterChip(
                      key: const ValueKey('restaurant_filter_budget'),
                      label: 'Under ₹${_filters.maxCostForTwo}',
                      icon: Icons.currency_rupee,
                      selected: true,
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(clearMaxCost: true);
                      }),
                    ),
                  OxroFilterChip(
                    key: const ValueKey('restaurant_filter_rating'),
                    label: 'Rating 4.0+',
                    icon: Icons.star_outline,
                    selected: _filters.rating4,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(rating4: !_filters.rating4);
                    }),
                  ),
                  OxroFilterChip(
                    key: const ValueKey('restaurant_filter_offers'),
                    label: 'Offers',
                    icon: Icons.local_offer_outlined,
                    selected: _filters.offers,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(offers: !_filters.offers);
                    }),
                  ),
                  if (_filters.isActive || _sort != RestaurantSort.relevance)
                    OxroResetChip(
                      key: const ValueKey('restaurant_filter_reset'),
                      onTap: () => setState(() {
                        _filters = const RestaurantFilters();
                        _sort = RestaurantSort.relevance;
                      }),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No restaurants match these filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: OxroColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.cuisine != null &&
                              foodCategoryFor(widget.cuisine!) != null) ...[
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              key: const ValueKey(
                                'restaurant_listing_browse_dishes',
                              ),
                              onPressed: () => pushScreen(
                                context,
                                SubCategoryScreen(
                                  category: foodCategoryFor(widget.cuisine!)!,
                                ),
                              ),
                              icon: const Icon(Icons.restaurant_menu, size: 18),
                              label: Text('Browse ${widget.cuisine} dishes'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('restaurant_list'),
                    padding: EdgeInsets.fromLTRB(
                      context.padX,
                      12,
                      context.padX,
                      28,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: DashedDivider(),
                    ),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: context.maxContentW,
                          ),
                          child: RestaurantMenuSection(
                            restaurant: r,
                            onOpen: () => pushScreen(
                              context,
                              RestaurantScreen(restaurantId: r.id),
                            ),
                            onAddDish: (dish) => quickAddProduct(context, dish),
                            onViewCart: () => pushScreen(
                              context,
                              BagScreen(
                                onShopNow: () =>
                                    Navigator.of(context).maybePop(),
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
}
