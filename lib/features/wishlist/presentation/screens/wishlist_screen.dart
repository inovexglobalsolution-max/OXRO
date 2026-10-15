import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// Wishlist tab — saved styles grid (premium, PLP tokens).
/// Live from [WishlistStore]: hearts tapped anywhere land here;
/// untoggle removes with a shrink-out. Empty → Discover → Home tab.
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key, required this.onDiscover});

  /// Empty-state CTA → Home tab.
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final cols = context.isTablet ? 3 : 2;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: WishlistStore.instance,
          builder: (context, _) {
            final store = WishlistStore.instance;
            final items = store.items;
            return Column(
              children: [
                // Header.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.padX, 12, context.padX, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Wishlist',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.charcoal)),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(
                            milliseconds: 200),
                        child: Container(
                          key: ValueKey(
                              'wish_count_${store.count}'),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red
                                .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                              '${store.count} saved',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body swaps empty ↔ grid.
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
                    child: items.isEmpty
                        ? _emptyBody(context)
                        : _gridBody(context, cols, items),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyBody(BuildContext context) {
    return Center(
      key: const ValueKey('wish_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration:
                const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, v, _) =>
                Transform.scale(
              scale: v,
              child: const Icon(
                  Icons.favorite_outline,
                  size: 72,
                  color: OxroColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Nothing saved yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Tap ♥ on any style to keep it here',
              style: TextStyle(
                  fontSize: 13, color: OxroColors.muted)),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('wish_discover'),
            onTap: onDiscover,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40051D47),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Text('Discover Styles',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridBody(BuildContext context, int cols,
      List<Product> items) {
    return GridView.builder(
      key: const ValueKey('wish_grid'),
      padding:
          EdgeInsets.fromLTRB(context.padX, 4, context.padX, 16),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration:
            Duration(milliseconds: 250 + (i % 10) * 50),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          final t = v.clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: _WishCard(product: items[i]),
            ),
          );
        },
        child: _WishCard(product: items[i]),
      ),
    );
  }
}

/// Saved card — filled heart untoggles (shrinks out of the grid).
class _WishCard extends StatefulWidget {
  const _WishCard({required this.product});

  final Product product;

  @override
  State<_WishCard> createState() => _WishCardState();
}

class _WishCardState extends State<_WishCard>
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
      key: ValueKey('wish_card_${p.id}'),
      onTapDown: (_) => _press.value = 0.96,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: () {
        _press.value = 1.0;
        pushScreen(
            context, ProductDetailScreen(product: p));
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
                    child: GestureDetector(
                      key: ValueKey(
                          'wish_remove_${p.id}'),
                      onTap: () => WishlistStore.instance
                          .toggle(p),
                      behavior: HitTestBehavior.opaque,
                      child: TweenAnimationBuilder<
                          double>(
                        tween:
                            Tween(begin: 1.3, end: 1.0),
                        duration: const Duration(
                            milliseconds: 250),
                        curve: Curves.easeOutBack,
                        builder: (context, v, _) =>
                            Transform.scale(
                          scale: v,
                          child: Container(
                            padding:
                                const EdgeInsets.all(6),
                            decoration:
                                const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              size: 15,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
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
