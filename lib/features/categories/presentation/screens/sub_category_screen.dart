import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/floating_cart_bar.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/categories/data/category_style.dart';
import 'package:oxro/features/categories/data/food_taxonomy.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';

/// L2 Sub-category — flat food taxonomy.
/// Category → Sub-category (e.g. Biryani → Chicken Biryani). Tapping a
/// sub-category opens the dish listing (PLP).
class SubCategoryScreen extends StatefulWidget {
  const SubCategoryScreen({super.key, required this.category, this.heroTag});

  final FoodCategory category;

  /// Hero tag for the header icon. Home cards pass `home_cat_*`,
  /// Categories grid uses the default `cat_*` — keeps tags unique
  /// per source so IndexedStack tabs never collide.
  final String? heroTag;

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen>
    with AutoHideNavState {
  late final List<String> _subs;

  @override
  void initState() {
    super.initState();
    _subs = subcategoriesFor(widget.category.label);
  }

  @override
  void dispose() {
    cancelNavTimer();
    super.dispose();
  }

  /// Floating bar opens the Bag (hidden from Bag/Checkout onwards).
  void _goBag() => pushScreen(
    context,
    BagScreen(onShopNow: () => Navigator.of(context).maybePop()),
  );

  void _openSub(String name) => pushScreen(
    context,
    ProductListingScreen(
      title: '${widget.category.label} · $name',
      leafs: [name],
      icon: widget.category.icon,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = catGradientForLabel(widget.category.label);
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
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
                        Hero(
                          tag: widget.heroTag ?? 'cat_${widget.category.label}',
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: g),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: g.last.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.category.icon,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: context.font(17),
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
                  Expanded(
                    child: _subs.isEmpty
                        ? const Center(child: Text('No sub-categories yet'))
                        : ListView(
                            key: const ValueKey('sub_category_scroll'),
                            padding: EdgeInsets.all(context.rs(10)),
                            children: [
                              _collectionBanner(context, g),
                              SizedBox(height: context.rs(10)),
                              _ShowAllCard(
                                categoryLabel: widget.category.label,
                                subs: _subs,
                                icon: widget.category.icon,
                                onTap: () => pushScreen(
                                  context,
                                  ProductListingScreen(
                                    title: '${widget.category.label} — All',
                                    leafs: _subs,
                                    icon: widget.category.icon,
                                  ),
                                ),
                              ),
                              SizedBox(height: context.rs(8)),
                              for (var i = 0; i < _subs.length; i++)
                                _TabStagger(
                                  index: i,
                                  child: _SubCard(
                                    key: ValueKey(
                                      'sub_${widget.category.label}_$i',
                                    ),
                                    name: _subs[i],
                                    categoryLabel: widget.category.label,
                                    icon: widget.category.icon,
                                    onTap: () => _openSub(_subs[i]),
                                  ),
                                ),
                              SizedBox(height: context.rs(88)),
                            ],
                          ),
                  ),
                ],
              ),
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

  Widget _collectionBanner(BuildContext context, List<Color> g) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        gradient: OxroColors.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30051D47),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.category.label} Collection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(15),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_subs.length} sub-categories · up to 40% OFF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 2,
              ),
            ),
            child: FoodImage(
              imageUrl: FoodMedia.forCategory(widget.category.label),
              colors: g,
              icon: widget.category.icon,
              width: 50,
              height: 50,
              radius: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered slide-up entrance for sub-category rows.
class _TabStagger extends StatelessWidget {
  const _TabStagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SubCard extends StatefulWidget {
  const _SubCard({
    super.key,
    required this.name,
    required this.categoryLabel,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String categoryLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<_SubCard>
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
    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(8)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.value = 0.96,
        onTapUp: (_) => _press.value = 1.0,
        onTapCancel: () => _press.value = 1.0,
        onTap: () {
          _press.value = 1.0;
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _press,
          child: Container(
            padding: EdgeInsets.all(context.rs(10)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OxroColors.lightGrey),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10051D47),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'group_${widget.categoryLabel}_${widget.name}',
                  child: FoodImage(
                    imageUrl: FoodMedia.forDish(
                      widget.name,
                      category: widget.categoryLabel,
                    ),
                    colors: [
                      OxroColors.primary.withValues(alpha: 0.16),
                      OxroColors.primary.withValues(alpha: 0.06),
                    ],
                    icon: widget.icon,
                    width: context.rs(46),
                    height: context.rs(46),
                    radius: 12,
                  ),
                ),
                SizedBox(width: context.rs(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(14),
                          fontWeight: FontWeight.w700,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const Text(
                        'Explore dishes',
                        style: TextStyle(fontSize: 12, color: OxroColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: OxroColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Show-All card on top of the L2 panel.
/// Opens one PLP with every sub-category of the category.
class _ShowAllCard extends StatelessWidget {
  const _ShowAllCard({
    required this.categoryLabel,
    required this.subs,
    required this.icon,
    required this.onTap,
  });

  final String categoryLabel;
  final List<String> subs;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = catGradientForLabel(categoryLabel);
    return GestureDetector(
      key: const ValueKey('show_all_products'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(context.rs(10)),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: g),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: g.last.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 5),
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
              child: Icon(Icons.grid_view_rounded, size: 22, color: g.last),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show All $categoryLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Full menu in one view',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
