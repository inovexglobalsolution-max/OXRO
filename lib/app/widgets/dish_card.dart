import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// Shared image-first dish card used across PLP, Search and Wishlist.
///
/// The card owns the product image, offer badge, wishlist/share overlay,
/// price block and ADD button so every browse surface stays identical.
class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.product,
    required this.onTap,
    this.cardKeyPrefix = 'dish_card',
    this.wishlistKeyPrefix = 'dish_wish',
    this.wishlistKeyIncludesState = true,
  });

  final Product product;
  final VoidCallback onTap;

  /// Prefix for the card tap key (e.g. `plp_card_123`).
  final String cardKeyPrefix;

  /// Prefix for the heart key. Wishlist uses `wish_remove_123`.
  final String wishlistKeyPrefix;

  /// PLP keeps state in the key (`plp_wish_123_true`); Wishlist needs a
  /// stable `wish_remove_123` so tests and removal taps stay deterministic.
  final bool wishlistKeyIncludesState;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final imageHeight = MediaQuery.sizeOf(context).width < 360 ? 100.0 : 110.0;

    return PressScale(
      key: ValueKey('${cardKeyPrefix}_${p.id}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'pdp_image_${p.id}',
                      child: FoodImage(
                        imageUrl: p.imageUrl,
                        colors: p.colors,
                        icon: p.icon,
                        width: double.infinity,
                        height: imageHeight,
                        radius: 0,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Color(0x00000000),
                            Color(0x66000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OxroColors.green,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${p.off}% OFF',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _wishButton(context, p),
                          const SizedBox(height: 5),
                          ProductShareButton(product: p, size: 14),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: VegMark(veg: p.veg, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: OxroColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                        height: 1.22,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        RatingChip(rating: p.rating, compact: true),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '(${_ratingCount(p.reviews)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: OxroColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            Product.inr(p.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            Product.inr(p.mrp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: OxroColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
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
    );
  }

  Widget _wishButton(BuildContext context, Product p) {
    return ListenableBuilder(
      listenable: WishlistStore.instance,
      builder: (context, _) {
        final wished = WishlistStore.instance.contains(p.id);
        final key = wishlistKeyIncludesState
            ? '${wishlistKeyPrefix}_${p.id}_$wished'
            : '${wishlistKeyPrefix}_${p.id}';
        return GestureDetector(
          key: ValueKey(key),
          onTap: () => WishlistStore.instance.toggle(p),
          behavior: HitTestBehavior.opaque,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('${wishlistKeyPrefix}_pop_${p.id}_$wished'),
            tween: Tween(begin: wished ? 1.3 : 0.8, end: 1.0),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x22000000), blurRadius: 6),
                  ],
                ),
                child: Icon(
                  wished ? Icons.favorite : Icons.favorite_outline,
                  size: 14,
                  color: wished ? Colors.red : OxroColors.muted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _ratingCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}
