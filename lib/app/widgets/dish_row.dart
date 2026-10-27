import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/add_stepper.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.dish,
    this.badge,
    this.reordered = false,
    this.onTap,
    this.onAdd,
  });

  final Product dish;
  final String? badge;

  /// Shows the green "Highly reordered" popularity bar.
  final bool reordered;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('dish_row_${dish.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    _DishBadge(label: badge!, dishId: dish.id),
                    const SizedBox(height: 5),
                  ],
                  Row(
                    children: [
                      VegMark(veg: dish.veg, egg: dish.egg, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          dish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.charcoal,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reordered) ...[
                    const SizedBox(height: 6),
                    const _ReorderBadge(),
                  ],
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Product.inr(dish.price),
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal,
                          ),
                        ),
                        if (dish.mrp > dish.price) ...[
                          const SizedBox(width: 5),
                          Text(
                            Product.inr(dish.mrp),
                            style: const TextStyle(
                              fontSize: 13,
                              color: OxroColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        RatingChip(rating: dish.rating, compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: OxroColors.muted,
                      height: 1.35,
                    ),
                  ),
                  if (dish.options.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    const Text(
                      'Customisable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ListenableBuilder(
                        listenable: WishlistStore.instance,
                        builder: (context, _) {
                          final saved = WishlistStore.instance.contains(
                            dish.id,
                          );
                          return _RoundIconButton(
                            key: ValueKey('dish_bookmark_${dish.id}'),
                            icon: saved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: saved
                                ? OxroColors.coral
                                : OxroColors.muted,
                            onTap: () => WishlistStore.instance.toggle(dish),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        key: ValueKey('dish_share_${dish.id}'),
                        icon: Icons.ios_share_outlined,
                        onTap: () => shareProduct(dish),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 156,
              height: 152,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  FoodImage(
                    imageUrl: dish.imageUrl,
                    colors: dish.colors,
                    icon: dish.icon,
                    width: 148,
                    height: 140,
                    radius: 14,
                  ),
                  Positioned(
                    bottom: 0,
                    child: AddStepper(product: dish, width: 118, onAdd: onAdd),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderBadge extends StatelessWidget {
  const _ReorderBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 5,
          decoration: BoxDecoration(
            color: OxroColors.vegGreen.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2.5),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.62,
            child: Container(
              decoration: BoxDecoration(
                color: OxroColors.vegGreen,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Highly reordered',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OxroColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = OxroColors.muted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: OxroColors.border),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }
}

class _DishBadge extends StatelessWidget {
  const _DishBadge({required this.label, required this.dishId});

  final String label;
  final int dishId;

  @override
  Widget build(BuildContext context) {
    final bestseller = label == 'Bestseller';
    final fg = bestseller ? const Color(0xFFB45309) : OxroColors.primary;
    final bg = bestseller
        ? const Color(0xFFFFF3D6)
        : OxroColors.primary.withValues(alpha: 0.09);
    return Container(
      key: ValueKey('dish_badge_$dishId'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bestseller
                ? Icons.local_fire_department_rounded
                : Icons.thumb_up_alt_rounded,
            size: 9,
            color: fg,
          ),
          const SizedBox(width: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: fg,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}
