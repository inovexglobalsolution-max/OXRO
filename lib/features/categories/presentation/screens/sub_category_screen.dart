import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/floating_cart_bar.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/categories/data/category_style.dart';
import 'package:oxro/features/categories/data/category_tree.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';

/// L2 Sub-category — Myntra left-tab rail + right groups panel.
/// Category → Tabs (Women/Men/…) → Groups (Topwear/…) → L3 leafs.
class SubCategoryScreen extends StatefulWidget {
  const SubCategoryScreen(
      {super.key, required this.category, this.heroTag});

  final HomeCategory category;

  /// Hero tag for the header icon. Home cards pass `home_cat_*`,
  /// Categories grid uses the default `cat_*` — keeps tags unique
  /// per source so IndexedStack tabs never collide.
  final String? heroTag;

  @override
  State<SubCategoryScreen> createState() =>
      _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  late final List<CatTab> _tabs;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = tabsFor(widget.category.label);
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
    final railW = context.isTablet ? 120.0 : 96.0;
    final tab = _tabs.isEmpty ? null : _tabs[_tab];
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
            // Header.
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  Builder(builder: (context) {
                    final g = catGradientForLabel(
                        widget.category.label);
                    return Hero(
                      tag: widget.heroTag ??
                          'cat_${widget.category.label}',
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: g),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: g.last.withValues(
                                  alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(widget.category.icon,
                            size: 19, color: Colors.white),
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                  IconButton(
                    onPressed: () => pushScreen(
                        context, const SearchScreen()),
                    icon: const Icon(Icons.search,
                        color: OxroColors.charcoal),
                  ),
                ],
              ),
            ),
            // Body: rail + panel.
            Expanded(
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Left rail.
                  Container(
                    width: railW,
                    color: OxroColors.lightGrey,
                    child: ListView.builder(
                      itemCount: _tabs.length,
                      itemBuilder: (_, i) {
                        final t = _tabs[i];
                        final sel = i == _tab;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                                vertical: context.rs(10),
                                horizontal: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: sel
                                      ? OxroColors.primary
                                      : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: sel ? 1.18 : 1.0,
                                  duration: const Duration(
                                      milliseconds: 200),
                                  curve: Curves.easeOutBack,
                                  child: Icon(t.icon,
                                      size: 24,
                                      color: sel
                                          ? OxroColors.primary
                                          : OxroColors.muted),
                                ),
                                const SizedBox(height: 4),
                                Text(t.name,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: sel
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: sel
                                            ? OxroColors.primary
                                            : OxroColors.muted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Right panel.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(
                          milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder:
                          (child, animation) {
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
                      child: tab == null
                          ? const Center(
                              child: Text(
                                  'No sub-categories yet'))
                          : ListView(
                              key: ValueKey(tab.name),
                              padding: EdgeInsets.all(
                                  context.rs(8)),
                              children: [
                                // Offer banner per tab (pops on tab change).
                                TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                      'banner_${tab.name}'),
                                  tween: Tween(
                                      begin: 0.92, end: 1.0),
                                  duration:
                                      const Duration(
                                          milliseconds:
                                              260),
                                  curve:
                                      Curves.easeOutCubic,
                                  builder: (context, v,
                                          _) =>
                                      Transform.scale(
                                    scale: v,
                                    child: Opacity(
                                      opacity: v
                                          .clamp(0.0, 1.0),
                                      child: Container(
                                        width:
                                            double.infinity,
                                        padding: EdgeInsets.all(
                                            context.rs(
                                                10)),
                                        decoration:
                                            BoxDecoration(
                                          gradient: OxroColors
                                              .gradient,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      14),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(
                                                  0x30051D47),
                                              blurRadius:
                                                  12,
                                              offset: Offset(
                                                  0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                                '${tab.name} Collection',
                                                maxLines:
                                                    1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style: TextStyle(
                                                    fontSize: context.font(
                                                        15),
                                                    fontWeight:
                                                        FontWeight
                                                            .w800,
                                                    color: Colors
                                                        .white)),
                                            const SizedBox(
                                                height:
                                                    2),
                                            const Text(
                                                'Up to 40% OFF',
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color: Colors
                                                        .white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    height: context.rs(8)),
                                // Show-All: full tab collection in one PLP.
                                _ShowAllCard(
                                  tabName: tab.name,
                                  categoryLabel:
                                      widget.category.label,
                                  leafs: [
                                    for (final gr
                                        in tab.groups)
                                      for (final l
                                          in gr.leafs)
                                        l.name,
                                  ],
                                  icon:
                                      widget.category.icon,
                                ),
                                SizedBox(
                                    height: context.rs(8)),
                                for (var gi = 0;
                                    gi < tab.groups.length;
                                    gi++)
                                  _TabStagger(
                                    index: gi,
                                    child: _GroupCard(
                                      group: tab
                                          .groups[gi],
                                      tabName: tab.name,
                                      categoryLabel: widget
                                          .category.label,
                                    ),
                                  ),
                                SizedBox(
                                    height: context.rs(88)),
                              ],
                            ),
                    ),
                  ),
                ],
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
}

/// Staggered slide-up entrance for right-panel rows.
/// Delay = index * 60ms so groups cascade after the panel slides in.
class _TabStagger extends StatelessWidget {
  const _TabStagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + index * 60),
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

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.tabName,
    required this.categoryLabel,
  });

  final CatGroup group;
  final String tabName;
  final String categoryLabel;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard>
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
          pushScreen(
            context,
            ProductListingScreen(
              title: '${widget.tabName} · ${widget.group.name}',
              leafs: [
                for (final l in widget.group.leafs) l.name,
              ],
              icon: widget.group.icon,
            ),
          );
        },
        child: ScaleTransition(
          scale: _press,
          child: Container(
          padding: EdgeInsets.all(context.rs(10)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: OxroColors.lightGrey),
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
                tag:
                    'group_${widget.categoryLabel}_${widget.tabName}_${widget.group.name}',
                child: Container(
                  width: context.rs(44),
                  height: context.rs(44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OxroColors.primary
                        .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.group.icon,
                      size: 22, color: OxroColors.primary),
                ),
              ),
              SizedBox(width: context.rs(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(widget.group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(14),
                            fontWeight: FontWeight.w700,
                            color: OxroColors.charcoal)),
                    Text('${widget.group.leafs.length} styles',
                        style: TextStyle(
                            fontSize: context.font(12),
                            color: OxroColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: OxroColors.muted),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Show-All Products card on top of the L2 panel.
/// Opens one PLP with every leaf of the tab (PLP "All" mixes them).
class _ShowAllCard extends StatelessWidget {
  const _ShowAllCard({
    required this.tabName,
    required this.categoryLabel,
    required this.leafs,
    required this.icon,
  });

  final String tabName;
  final String categoryLabel;
  final List<String> leafs;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final g = catGradientForLabel(categoryLabel);
    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(8)),
      child: GestureDetector(
        key: const ValueKey('show_all_products'),
        onTap: () => pushScreen(
          context,
          ProductListingScreen(
            title: '$categoryLabel · $tabName — All',
            leafs: leafs,
            icon: icon,
          ),
        ),
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
                  color:
                      Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grid_view_rounded,
                    size: 22, color: g.last),
              ),
              SizedBox(width: context.rs(12)),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Show All Products',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text('Full collection in one view',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
