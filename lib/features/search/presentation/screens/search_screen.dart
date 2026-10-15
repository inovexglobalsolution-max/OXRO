import 'dart:async';

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/floating_cart_bar.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/app/widgets/shimmer.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// 09 Search — autofocus field + trending / recent chips + results grid.
/// Matches product name + brand + leaf / group / tab / category via
/// [SearchRepo]. Result cards reuse the PLP pattern (Hero image,
/// full-width ADD, tap → PDP). Entry uses the app-wide slide+fade.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
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
    SearchRepo.loadRecents().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _entry.dispose();
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
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
                    ? const Icon(Icons.check,
                        color: OxroColors.primary)
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
        BagScreen(
            onShopNow: () =>
                Navigator.of(context).maybePop()),
      );

  @override
  Widget build(BuildContext context) {
    final cols = context.isTablet ? 3 : 2;
    final showResults = _submitted || _searching;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: OxroBottomNav(
        currentIndex: 1,
        onTap: (i) => handleShopNav(context, i),
      ),
      body: SafeArea(
        bottom: false,
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
                      context.rs(8), 4, context.rs(8), 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back,
                            color: OxroColors.charcoal),
                      ),
                      Expanded(
                        child: Container(
                          height: 44,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12),
                          decoration: BoxDecoration(
                            color: OxroColors.lightGrey,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  size: 20,
                                  color: OxroColors.muted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                      'search_field'),
                                  controller: _ctrl,
                                  focusNode: _focus,
                                  autofocus: true,
                                  textInputAction:
                                      TextInputAction.search,
                                  onChanged: _onChanged,
                                  onSubmitted: _submit,
                                  decoration:
                                      const InputDecoration
                                          .collapsed(
                                    hintText:
                                        'Search products, brands…',
                                    hintStyle: TextStyle(
                                        fontSize: 14,
                                        color:
                                            OxroColors.muted),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 14),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(
                                    milliseconds: 180),
                                child: _ctrl.text.isEmpty
                                    ? const SizedBox.shrink()
                                    : GestureDetector(
                                        key: const ValueKey(
                                            'search_clear'),
                                        onTap: () {
                                          _ctrl.clear();
                                          _onChanged('');
                                          _focus.requestFocus();
                                          setState(() {});
                                        },
                                        behavior:
                                            HitTestBehavior
                                                .opaque,
                                        child: const Icon(
                                            Icons.clear,
                                            size: 20,
                                            color: OxroColors.muted),
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
                    vertical: 4),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(
                          milliseconds: 200),
                      child: Text(
                        _searching
                            ? 'Searching…'
                            : '${_results.length} styles',
                        key: ValueKey(_searching
                            ? 'searching'
                            : 'count_${_results.length}'),
                        style: TextStyle(
                            fontSize: context.font(12),
                            color: OxroColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            // Filter bar (results only).
            if (showResults && !_searching)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                    horizontal: context.padX),
                child: Row(
                  children: [
                    _filterChip(
                      key: const ValueKey('filter_sort'),
                      label:
                          'Sort: ${searchSortLabels[_sort]}',
                      active:
                          _sort != SearchSort.relevance,
                      onTap: _pickSort,
                    ),
                    _filterChip(
                      key: const ValueKey('filter_rating'),
                      label: '4+ rating',
                      active: _minRating >= 4,
                      onTap: () {
                        setState(() => _minRating =
                            _minRating >= 4 ? 0 : 4);
                        _refilter();
                      },
                    ),
                    _filterChip(
                      key: const ValueKey('filter_off'),
                      label: '50%+ off',
                      active: _minOff >= 50,
                      onTap: () {
                        setState(() => _minOff =
                            _minOff >= 50 ? 0 : 50);
                        _refilter();
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 260),
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
                        : _results.isEmpty
                            ? _emptyBody()
                            : _resultsGrid(cols),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? OxroColors.primary
              : OxroColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active
                    ? Colors.white
                    : OxroColors.charcoal)),
      ),
    );
  }

  Widget _idleBody() {
    return ListView(
      key: const ValueKey('search_idle'),
      padding:
          EdgeInsets.fromLTRB(context.padX, 8, context.padX, 20),
      children: [
        const Text('Trending',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0;
                i < homeCategories.length;
                i++)
              _stagger(
                i,
                GestureDetector(
                  onTap: () =>
                      _runQuery(homeCategories[i].label),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: OxroColors.primary
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: OxroColors.primary
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text(
                        homeCategories[i].short,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.primary)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Recent',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal)),
            const Spacer(),
            if (SearchRepo.recents.isNotEmpty)
              GestureDetector(
                onTap: () => setState(
                    SearchRepo.clearRecents),
                behavior: HitTestBehavior.opaque,
                child: const Text('Clear',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.royalBlue)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (SearchRepo.recents.isEmpty)
          const Text('No recent searches yet',
              style: TextStyle(
                  fontSize: 13, color: OxroColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0;
                  i < SearchRepo.recents.length;
                  i++)
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
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: OxroColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history,
                            size: 15,
                            color: OxroColors.muted),
                        const SizedBox(width: 6),
                        Text(SearchRepo.recents[i],
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        GestureDetector(
                          key: ValueKey(
                              'recent_del_$i'),
                          onTap: () {
                            _eatChipTap = true;
                            setState(() => SearchRepo
                                .removeRecentAt(i));
                          },
                          behavior:
                              HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(
                                left: 6),
                            child: Icon(
                                Icons.close,
                                size: 15,
                                color: OxroColors.muted),
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
      padding: EdgeInsets.fromLTRB(
          context.padX, 8, context.padX, 16),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
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
      padding:
          EdgeInsets.fromLTRB(context.padX, 16, context.padX, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_outlined,
              size: 56, color: OxroColors.muted),
          const SizedBox(height: 12),
          Text('No styles for "${_ctrl.text.trim()}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              _onChanged('');
              setState(() {});
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Clear',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Popular right now',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal)),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            key: const ValueKey('search_empty_popular'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: popular.length,
            itemBuilder: (_, i) => _SearchCard(
              product: popular[i],
              onTap: () => pushScreen(
                context,
                ProductDetailScreen(product: popular[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsGrid(int cols) {
    return GridView.builder(
      key: const ValueKey('search_grid'),
      padding:
          EdgeInsets.fromLTRB(context.padX, 8, context.padX, 88),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) => _stagger(
        i % 10,
        _SearchCard(
          product: _results[i],
          onTap: () => pushScreen(
            context,
            ProductDetailScreen(product: _results[i]),
          ),
        ),
      ),
    );
  }
}

class _SearchCard extends StatefulWidget {
  const _SearchCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
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
    final p = widget.product;
    return GestureDetector(
      key: ValueKey('search_card_${p.id}'),
      onTapDown: (_) => _press.value = 0.96,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: () {
        _press.value = 1.0;
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _press,
        child: Container(
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
                      height: 100,
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
                          size: 52, color: OxroColors.muted),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
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
                      listenable:
                          WishlistStore.instance,
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
                          child: Container(
                            padding:
                                const EdgeInsets.all(6),
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
                              size: 15,
                              color: wished
                                  ? Colors.red
                                  : OxroColors.muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(p.brand,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10,
                              color: OxroColors.muted,
                              fontWeight:
                                  FontWeight.w600)),
                      Text(p.name,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                                Product.inr(p.price),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w800)),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                                Product.inr(p.mrp),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
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
                                  BorderRadius.circular(
                                      4),
                            ),
                            child: Text('${p.rating}★',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: Colors.green)),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('(${p.reviews})',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
