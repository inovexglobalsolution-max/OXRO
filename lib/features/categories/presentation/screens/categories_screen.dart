import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/categories/data/category_style.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// 07 Categories — premium: 8 gradient identities, pop entrance,
/// press scale + hero icon (for 08 listing).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.onBack, this.onOpen});

  /// In-tab back goes to Home tab; standalone push pops.
  final VoidCallback? onBack;

  /// Category tap (08 listing wires later).
  final void Function(HomeCategory c)? onOpen;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cols = context.isTablet ? 3 : 2;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: widget.onBack ??
                    () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back,
                    color: OxroColors.charcoal),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('All Categories',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: OxroColors.gradient,
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${homeCategories.length}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => pushScreen(
                        context, const SearchScreen()),
                    style: IconButton.styleFrom(
                      backgroundColor: OxroColors.pageBg,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        side: const BorderSide(
                            color: OxroColors.border),
                      ),
                    ),
                    icon: const Icon(Icons.search,
                        color: OxroColors.charcoal),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  context.padX,
                  context.rs(6),
                  context.padX,
                  context.rs(20)),
              sliver: SliverGrid(
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: context.rs(12),
                  crossAxisSpacing: context.rs(12),
                  childAspectRatio: 1.02,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _entrance(
                    i,
                    _CatCard(
                      cat: homeCategories[i],
                      index: i,
                      onTap: () {
                        final cat = homeCategories[i];
                        if (widget.onOpen != null) {
                          widget.onOpen!(cat);
                        } else {
                          pushScreen(
                            context,
                            SubCategoryScreen(
                                category: cat),
                          );
                        }
                      },
                    ),
                  ),
                  childCount: homeCategories.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pop + fade + slide stagger (scale uses back-ease for bounce).
  Widget _entrance(int i, Widget child) {
    final n = homeCategories.length;
    final start = (i / n) * 0.6;
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((_entry.value - start) / (1 - start)).clamp(0.0, 1.0),
        );
        final pop = Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - t)),
            child: Transform.scale(
              scale: (0.85 + 0.15 * pop).clamp(0.85, 1.05),
              child: child,
            ),
          ),
        );
      },
    );
  }
}



class _CatCard extends StatefulWidget {
  const _CatCard(
      {required this.cat,
      required this.index,
      required this.onTap});

  final HomeCategory cat;
  final int index;
  final VoidCallback onTap;

  @override
  State<_CatCard> createState() => _CatCardState();
}

class _CatCardState extends State<_CatCard>
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
    final g = catGradient(widget.index);
    final glow = g.last;
    return GestureDetector(
      key: ValueKey('cat_card_${widget.cat.short}'),
      onTapDown: (_) => _press.value = 0.94,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _press,
        child: Container(
          padding: EdgeInsets.all(context.rs(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OxroColors.border),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Tint wash blob (top-right).
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: g),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                          alpha: 0.82),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'cat_${widget.cat.label}',
                        child: Container(
                          width: context.rs(48),
                          height: context.rs(48),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: g),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glow.withValues(
                                    alpha: 0.35),
                                blurRadius: 10,
                                offset:
                                    const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(widget.cat.icon,
                              size: 24,
                              color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.pageBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: OxroColors.border),
                        ),
                        child: const Icon(
                            Icons.chevron_right,
                            size: 17,
                            color: OxroColors.muted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(widget.cat.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: context.font(14),
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                          height: 1.25)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: glow.withValues(
                          alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(7),
                    ),
                    child: Text(widget.cat.items,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize:
                                context.font(11.5),
                            fontWeight: FontWeight.w700,
                            color: glow)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
