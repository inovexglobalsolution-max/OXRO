import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/dish_card.dart';
import 'package:oxro/app/widgets/floating_cart_bar.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/app/widgets/shimmer.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';

/// 08 Product Listing — 2-col infinite grid + leaf chips + sort.
/// Opened from L2 groups (L3 text list removed).
class ProductListingScreen extends StatefulWidget {
  const ProductListingScreen({
    super.key,
    required this.title,
    required this.leafs,
    this.initialLeaf,
    this.icon = Icons.shopping_bag_outlined,
  });

  /// e.g. "Men · Men's Clothing".
  final String title;

  /// Leaf buttons on top (All + these).
  final List<String> leafs;
  final String? initialLeaf;
  final IconData icon;

  @override
  State<ProductListingScreen> createState() => _ProductListingScreenState();
}

class _ProductListingScreenState extends State<ProductListingScreen>
    with AutoHideNavState {
  static const _all = 'All';

  late String _selected;
  PlpSort _sort = PlpSort.popularity;
  PlpFilters _filters = const PlpFilters();
  final _shown = <Product>[];
  int _page = 0;
  bool _firstLoad = true;
  bool _loadingMore = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLeaf ?? _all;
    _scroll.addListener(_onScroll);
    _initialLoad();
  }

  @override
  void dispose() {
    _scroll.dispose();
    cancelNavTimer();
    super.dispose();
  }

  List<Product> get _pool => _selected == _all
      ? ProductRepo.allMixed(widget.title, widget.leafs, widget.icon)
      : ProductRepo.allFor(widget.title, _selected, icon: widget.icon);

  Future<void> _initialLoad() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _shown.addAll(_pageOf(0));
      _page = 1;
      _firstLoad = false;
    });
  }

  List<Product> _pageOf(int page) {
    final sorted = sortProducts(filterProducts(_pool, _filters), _sort);
    final start = page * ProductRepo.pageSize;
    if (start >= sorted.length) return const [];
    final end = (start + ProductRepo.pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  bool get _hasMore =>
      _shown.length <
      sortProducts(filterProducts(_pool, _filters), _sort).length;

  List<Product> get _filtered => filterProducts(_pool, _filters);

  void _reload() {
    setState(() {
      _shown.clear();
      _page = 0;
      _firstLoad = true;
      _loadingMore = false;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _initialLoad();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || _firstLoad) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _shown.addAll(_pageOf(_page));
      _page++;
      _loadingMore = false;
    });
  }

  void _selectLeaf(String leaf) {
    if (leaf == _selected) return;
    setState(() {
      _selected = leaf;
      _shown.clear();
      _page = 0;
      _firstLoad = true;
      _loadingMore = false;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _initialLoad();
  }

  void _openSort() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            RadioGroup<PlpSort>(
              groupValue: _sort,
              onChanged: (v) {
                Navigator.of(context).pop();
                if (v != null && v != _sort) {
                  setState(() {
                    _sort = v;
                    _shown.clear();
                    _page = 0;
                    _firstLoad = true;
                  });
                  _initialLoad();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in PlpSort.values)
                    RadioListTile<PlpSort>(
                      value: s,
                      activeColor: OxroColors.primary,
                      title: Text(
                        plpSortLabels[s]!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 10 Filters — brand multi-select + price buckets + min rating +
  /// min discount. Temp state commits only on Apply; dismiss discards.
  void _openFilter() {
    final pool = _pool;
    final brands = {for (final p in pool) p.brand}.toList()..sort();
    var temp = _filters;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          final n = filterProducts(pool, temp).length;
          void update(PlpFilters f) => setSheet(() => temp = f);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OxroColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                      child: Row(
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (temp.isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: OxroColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${temp.count}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => update(const PlpFilters()),
                            behavior: HitTestBehavior.opaque,
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.royalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filterLabel(
                              'BRAND',
                              temp.brands.isEmpty
                                  ? null
                                  : '${temp.brands.length}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final b in brands)
                                  _brandChip(b, temp.brands.contains(b), () {
                                    final next = Set<String>.of(temp.brands);
                                    if (next.contains(b)) {
                                      next.remove(b);
                                    } else {
                                      next.add(b);
                                    }
                                    update(temp.copyWith(brands: next));
                                  }),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _filterLabel('PRICE', null),
                            RadioGroup<PlpPrice>(
                              groupValue: temp.price,
                              onChanged: (v) {
                                if (v != null) {
                                  update(temp.copyWith(price: v));
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final pp in PlpPrice.values)
                                    RadioListTile<PlpPrice>(
                                      value: pp,
                                      activeColor: OxroColors.primary,
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        plpPriceLabels[pp]!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _filterLabel('RATING', null),
                            const SizedBox(height: 8),
                            _segment(
                              ['Any', '3★+', '4★+'],
                              temp.minRating == 0
                                  ? 0
                                  : temp.minRating >= 4
                                  ? 2
                                  : 1,
                              (i) => update(
                                temp.copyWith(
                                  minRating: [0, 3, 4][i].toDouble(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _filterLabel('DISCOUNT', null),
                            const SizedBox(height: 8),
                            _segment(
                              ['Any', '10%+', '30%+', '50%+'],
                              {0: 0, 10: 1, 30: 2, 50: 3}[temp.minOff]!,
                              (i) => update(
                                temp.copyWith(minOff: [0, 10, 30, 50][i]),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        12 + context.rs(4),
                      ),
                      child: GestureDetector(
                        key: const ValueKey('filter_apply'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _filters = temp;
                          _reload();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: OxroColors.gradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40051D47),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              'Apply ($n dishes)',
                              key: ValueKey('apply_$n'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterLabel(String text, String? badge) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: OxroColors.muted,
            letterSpacing: 1.1,
          ),
        ),
        if (badge != null)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: OxroColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: OxroColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _brandChip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      key: ValueKey('filter_brand_$label'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: sel ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? OxroColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? OxroColors.primary : OxroColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : OxroColors.charcoal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(List<String> options, int sel, ValueChanged<int> onPick) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onPick(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9),
                margin: EdgeInsets.only(right: i == options.length - 1 ? 0 : 8),
                decoration: BoxDecoration(
                  color: sel == i ? OxroColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel == i ? OxroColors.primary : OxroColors.border,
                  ),
                ),
                child: Text(
                  options[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel == i ? Colors.white : OxroColors.charcoal,
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final chips = [_all, ...widget.leafs];
    final skeletonCount = _firstLoad ? 6 : (_loadingMore ? 2 : 0);
    final itemCount = _shown.length + skeletonCount;

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
                  // Header.
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(8),
                      vertical: 4,
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
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: context.font(16),
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              pushScreen(context, const SearchScreen()),
                          icon: const Icon(
                            Icons.search,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Leaf buttons row.
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: context.padX),
                      itemCount: chips.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = chips[i];
                        final sel = c == _selected;
                        return GestureDetector(
                          onTap: () => _selectLeaf(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: sel ? OxroColors.gradient : null,
                              color: sel ? null : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : OxroColors.border,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : OxroColors.charcoal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                  // Sort + filter bar (flexible texts — safe at 320).
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.padX),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_filtered.length} dishes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: context.font(12),
                              color: OxroColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openSort,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sort_outlined,
                                size: 17,
                                color: OxroColors.charcoal,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  plpSortLabels[_sort]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openFilter,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tune_outlined,
                                size: 17,
                                color: OxroColors.charcoal,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    _filters.isActive
                                        ? 'Filter (${_filters.count})'
                                        : 'Filter',
                                    key: ValueKey(
                                      'filter_${_filters.count}_${_filters.isActive}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _filters.isActive
                                          ? OxroColors.primary
                                          : OxroColors.charcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                  // Grid (infinite).
                  Expanded(
                    child: _firstLoad && _shown.isEmpty
                        ? GridView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.padX,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.56,
                                ),
                            itemCount: 6,
                            itemBuilder: (context, _) => const _SkeletonCard(),
                          )
                        : _shown.isEmpty && !_loadingMore
                        ? _empty()
                        : GridView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              context.padX,
                              0,
                              context.padX,
                              context.rs(88),
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.56,
                                ),
                            itemCount: itemCount,
                            itemBuilder: (_, i) {
                              if (i >= _shown.length) {
                                return const _SkeletonCard();
                              }
                              return _ProductCard(
                                product: _shown[i],
                                onTap: () {
                                  pushScreen(
                                    context,
                                    ProductDetailScreen(product: _shown[i]),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
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

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 56,
            color: OxroColors.muted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No dishes found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              _filters = const PlpFilters();
              if (_selected == _all) {
                _reload();
              } else {
                _selectLeaf(_all);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DishCard(
    product: product,
    onTap: onTap,
    cardKeyPrefix: 'plp_card',
    wishlistKeyPrefix: 'plp_wish',
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

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
