import 'dart:async';

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/animated_search_hint.dart';
import 'package:oxro/app/widgets/dish_card.dart';
import 'package:oxro/app/widgets/floating_cart_bar.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/app/widgets/restaurant_card.dart';
import 'package:oxro/app/widgets/section_header.dart';
import 'package:oxro/app/widgets/shimmer.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';
import 'package:oxro/features/search/data/search_repo.dart';

/// 09 Search — autofocus field + trending / recent chips + results grid.
/// Matches product name + brand + leaf / group / tab / category via
/// [SearchRepo]. Result cards reuse the PLP pattern (Hero image,
/// full-width ADD, tap → PDP). Entry uses the app-wide slide+fade.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-fill query (e.g. from voice sheet) and auto-search.
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin, AutoHideNavState {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Product> _results = const [];
  bool _searching = false;
  bool _submitted = false;
  String _lastQuery = '';
  SearchSort _sort = SearchSort.relevance;
  double _minRating = 0;
  int _minOff = 0;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _focus.addListener(_onFocusChanged);
    SearchRepo.loadRecents().then((_) {
      if (mounted) setState(() {});
    });
    final seed = widget.initialQuery?.trim() ?? '';
    if (seed.isNotEmpty) {
      _ctrl.text = seed;
      _lastQuery = seed;
      _searching = true;
      SearchRepo.pushRecent(seed);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _applyFiltersTo(SearchRepo.searchProducts(seed));
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    _entry.dispose();
    cancelNavTimer();
    super.dispose();
  }

  void _applyFiltersTo(List<Product> raw) {
    setState(() {
      _results = SearchRepo.applyFilters(
        raw,
        sort: _sort,
        minRating: _minRating,
        minOff: _minOff,
      );
      _searching = false;
      _submitted = true;
    });
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _submitted = false;
        _lastQuery = '';
      });
      return;
    }
    _lastQuery = v;
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _applyFiltersTo(SearchRepo.searchProducts(v));
    });
  }

  void _refilter() {
    if (_lastQuery.trim().isEmpty) return;
    _applyFiltersTo(SearchRepo.searchProducts(_lastQuery));
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<SearchSort>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in SearchSort.values)
              ListTile(
                key: ValueKey('sort_opt_${s.name}'),
                title: Text(searchSortLabels[s]!),
                trailing: _sort == s
                    ? const Icon(Icons.check, color: OxroColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _sort = picked);
      _refilter();
    }
  }

  void _runQuery(String q) {
    _ctrl.text = q;
    _onChanged(q);
    _focus.unfocus();
  }

  void _submit(String q) {
    SearchRepo.pushRecent(q);
    _runQuery(q);
    setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _pickSuggestion(Product product) {
    _focus.unfocus();
    _submit(product.name);
  }

  /// Set by the recent-row delete X so the wrapping chip tap is eaten.
  bool _eatChipTap = false;

  Widget _stagger(int i, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + i * 50),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Floating bar opens the Bag (hidden from Bag/Checkout onwards).
  void _goBag() => pushScreen(
    context,
    BagScreen(onShopNow: () => Navigator.of(context).maybePop()),
  );

  @override
  Widget build(BuildContext context) {
    final cols = context.isTablet ? 3 : 2;
    final showResults = _submitted || _searching;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: HideableOxroBottomNav(
        visible: navVisible,
        currentIndex: 0,
        onTap: (i) => handleShopNav(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: handleNavScroll,
          child: Stack(
            children: [
              Column(
                children: [
                  // Search header (pops in).
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Transform.scale(
                      scale: v,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rs(8),
                          4,
                          context.rs(8),
                          4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: OxroColors.charcoal,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: OxroColors.lightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search,
                                      size: 20,
                                      color: OxroColors.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          if (_ctrl.text.isEmpty)
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: AnimatedSearchHint(
                                                  key: const ValueKey(
                                                    'search_hint',
                                                  ),
                                                  hintKey: 'search_hint',
                                                  items: [
                                                    for (final name
                                                        in SearchRepo.dishNames)
                                                      'Search "$name"',
                                                  ],
                                                  fallback:
                                                      'Search dishes, kitchens…',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: OxroColors.muted,
                                                  ),
                                                  emphasisStyle: const TextStyle(
                                                    fontSize: 14,
                                                    color: OxroColors.dark,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          TextField(
                                            key: const ValueKey('search_field'),
                                            controller: _ctrl,
                                            focusNode: _focus,
                                            autofocus: true,
                                            textInputAction:
                                                TextInputAction.search,
                                            onChanged: _onChanged,
                                            onSubmitted: _submit,
                                            decoration:
                                                const InputDecoration.collapsed(
                                                  hintText: null,
                                                ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _ctrl.text.isEmpty
                                          ? const SizedBox.shrink()
                                          : GestureDetector(
                                              key: const ValueKey(
                                                'search_clear',
                                              ),
                                              onTap: () {
                                                _ctrl.clear();
                                                _onChanged('');
                                                _focus.requestFocus();
                                                setState(() {});
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: const Icon(
                                                Icons.clear,
                                                size: 20,
                                                color: OxroColors.muted,
                                              ),
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
                  ),
                  // Result count ticker.
                  if (showResults)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.padX,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _searching
                                  ? 'Searching…'
                                  : '${_results.length} dishes',
                              key: ValueKey(
                                _searching
                                    ? 'searching'
                                    : 'count_${_results.length}',
                              ),
                              style: TextStyle(
                                fontSize: context.font(12),
                                color: OxroColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Filter bar (results only).
                  if (showResults && !_searching)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      child: Row(
                        children: [
                          _filterChip(
                            key: const ValueKey('filter_sort'),
                            label: 'Sort: ${searchSortLabels[_sort]}',
                            active: _sort != SearchSort.relevance,
                            onTap: _pickSort,
                          ),
                          _filterChip(
                            key: const ValueKey('filter_rating'),
                            label: '4+ rating',
                            active: _minRating >= 4,
                            onTap: () {
                              setState(
                                () => _minRating = _minRating >= 4 ? 0 : 4,
                              );
                              _refilter();
                            },
                          ),
                          _filterChip(
                            key: const ValueKey('filter_off'),
                            label: '50%+ off',
                            active: _minOff >= 50,
                            onTap: () {
                              setState(() => _minOff = _minOff >= 50 ? 0 : 50);
                              _refilter();
                            },
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.12, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: !showResults
                          ? _idleBody()
                          : _searching && _results.isEmpty
                          ? _loadingGrid(cols)
                          : _results.isEmpty && _restaurantMatches.isEmpty
                          ? _emptyBody()
                          : _resultsView(cols),
                    ),
                  ),
                ],
              ),
              _suggestionsOverlay(context),
              // Floating cart bar until Bag (hidden when empty).
              // Home-match gap: same 10px above the nav as Home.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FloatingCartBar(onTap: _goBag),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionsOverlay(BuildContext context) {
    final query = _ctrl.text.trim();
    final active = _focus.hasFocus && query.isNotEmpty && _searching;
    final items = active
        ? SearchRepo.dishSuggestions(query, limit: 7)
        : const <Product>[];
    return Positioned(
      left: context.padX,
      right: context.padX,
      top: 58,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: items.isEmpty
            ? const SizedBox.shrink(key: ValueKey('search_suggestions_hidden'))
            : _suggestionPanel(context, query, items),
      ),
    );
  }

  Widget _suggestionPanel(
    BuildContext context,
    String query,
    List<Product> items,
  ) {
    return ConstrainedBox(
      key: const ValueKey('search_suggestions'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
      ),
      child: Material(
        color: Colors.white,
        elevation: 12,
        shadowColor: const Color(0x33051D47),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: OxroColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Dish suggestions',
                    style: TextStyle(
                      fontSize: context.font(12),
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to search',
                    style: TextStyle(
                      fontSize: context.font(10.5),
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OxroColors.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 66,
                  color: Color(0xFFF0F3F7),
                ),
                itemBuilder: (context, i) =>
                    _suggestionRow(context, items[i], query, i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionRow(
    BuildContext context,
    Product product,
    String query,
    int index,
  ) {
    final match = product.name.toLowerCase().indexOf(query.toLowerCase());
    return InkWell(
      key: ValueKey('search_suggestion_$index'),
      onTap: () => _pickSuggestion(product),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            FoodImage(
              imageUrl: product.imageUrl,
              colors: product.colors,
              icon: product.icon,
              width: 42,
              height: 42,
              radius: 11,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        if (match < 0) ...[
                          TextSpan(text: product.name),
                        ] else ...[
                          TextSpan(text: product.name.substring(0, match)),
                          TextSpan(
                            text: product.name.substring(
                              match,
                              match + query.length,
                            ),
                            style: const TextStyle(
                              color: OxroColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: product.name.substring(match + query.length),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.font(13),
                      color: OxroColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.kitchen} · ₹${product.price}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.font(10.5),
                      color: OxroColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.north_west_rounded,
              size: 15,
              color: OxroColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    Key? key,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? OxroColors.primary : OxroColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : OxroColors.charcoal,
          ),
        ),
      ),
    );
  }

  Widget _idleBody() {
    return ListView(
      key: const ValueKey('search_idle'),
      padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 20),
      children: [
        const Text(
          'Trending',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: OxroColors.charcoal,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < homeCategories.length; i++)
              _stagger(
                i,
                GestureDetector(
                  onTap: () => _runQuery(homeCategories[i].label),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: OxroColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      homeCategories[i].short,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Recent',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
            const Spacer(),
            if (SearchRepo.recents.isNotEmpty)
              GestureDetector(
                onTap: () => setState(SearchRepo.clearRecents),
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.royalBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (SearchRepo.recents.isEmpty)
          const Text(
            'No recent searches yet',
            style: TextStyle(fontSize: 13, color: OxroColors.muted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < SearchRepo.recents.length; i++)
                GestureDetector(
                  key: ValueKey('recent_chip_$i'),
                  onTap: () {
                    if (_eatChipTap) {
                      _eatChipTap = false;
                      return;
                    }
                    _runQuery(SearchRepo.recents[i]);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OxroColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history,
                          size: 15,
                          color: OxroColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          SearchRepo.recents[i],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          key: ValueKey('recent_del_$i'),
                          onTap: () {
                            _eatChipTap = true;
                            setState(() => SearchRepo.removeRecentAt(i));
                          },
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: OxroColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _loadingGrid(int cols) {
    return GridView.builder(
      key: const ValueKey('search_loading'),
      padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => const ShimmerBox(radius: 14),
    );
  }

  Widget _emptyBody() {
    final popular = homeDeals.take(4).toList();
    return SingleChildScrollView(
      key: const ValueKey('search_empty'),
      padding: EdgeInsets.fromLTRB(context.padX, 16, context.padX, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 56,
            color: OxroColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No dishes for "${_ctrl.text.trim()}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              _onChanged('');
              setState(() {});
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Popular right now',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            key: const ValueKey('search_empty_popular'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: popular.length,
            itemBuilder: (_, i) => _SearchCard(
              product: popular[i],
              onTap: () =>
                  pushScreen(context, ProductDetailScreen(product: popular[i])),
            ),
          ),
        ],
      ),
    );
  }

  List<Restaurant> get _restaurantMatches {
    final q = _lastQuery.trim();
    if (q.isEmpty) return const [];
    return RestaurantRepo.search(q).take(4).toList();
  }

  Widget _resultsView(int cols) {
    final restaurants = _restaurantMatches;
    return CustomScrollView(
      key: const ValueKey('search_results'),
      slivers: [
        if (_results.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.padX, 14, context.padX, 4),
              child: SectionHeader(
                title: 'Dishes',
                subtitle: '${_results.length} matches',
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 12),
            sliver: SliverGrid(
              key: const ValueKey('search_grid'),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 8,
                crossAxisSpacing: 12,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _stagger(
                  i % 10,
                  _SearchCard(
                    product: _results[i],
                    onTap: () => pushScreen(
                      context,
                      ProductDetailScreen(product: _results[i]),
                    ),
                  ),
                ),
                childCount: _results.length,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        if (restaurants.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 8),
              child: const SectionHeader(title: 'Restaurants'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(context.padX, 0, context.padX, 88),
            sliver: SliverList.separated(
              key: const ValueKey('search_restaurants'),
              itemCount: restaurants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = restaurants[i];
                return RestaurantCard(
                  restaurant: r,
                  onTap: () =>
                      pushScreen(context, RestaurantScreen(restaurantId: r.id)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DishCard(
    product: product,
    onTap: onTap,
    cardKeyPrefix: 'search_card',
    wishlistKeyPrefix: 'search_wish',
  );
}
