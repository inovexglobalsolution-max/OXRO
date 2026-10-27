import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

/// Reference-style restaurant block used on the food listing screen:
/// big name + rating badge, green ETA/delivery meta, a horizontal dish
/// carousel and a "View full menu" pill.
class RestaurantMenuSection extends StatelessWidget {
  const RestaurantMenuSection({
    super.key,
    required this.restaurant,
    required this.onOpen,
    required this.onAddDish,
    required this.onViewCart,
    this.dishLimit = 5,
  });

  final Restaurant restaurant;
  final VoidCallback onOpen;
  final ValueChanged<Product> onAddDish;
  final VoidCallback onViewCart;
  final int dishLimit;

  static const _offerBlue = Color(0xFF2F6FE0);

  List<Product> get _topDishes {
    final dishes = [...restaurant.dishes]
      ..sort((a, b) => b.reviews.compareTo(a.reviews));
    return dishes.take(dishLimit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dishes = _topDishes;
    return GestureDetector(
      key: ValueKey('restaurant_card_${restaurant.id}'),
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: OxroColors.charcoal,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RatingBadge(rating: restaurant.rating),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 15,
                color: OxroColors.vegGreen,
              ),
              const SizedBox(width: 1),
              Text(
                restaurant.etaRangeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.vegGreen,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 11,
                color: OxroColors.border,
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.delivery_dining_rounded,
                size: 15,
                color: OxroColors.vegGreen,
              ),
              const SizedBox(width: 2),
              const Text(
                'Free',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.vegGreen,
                ),
              ),
            ],
          ),
          if (dishes.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 252,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: dishes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final dish = dishes[i];
                  return _DishCard(
                    restaurantId: restaurant.id,
                    dish: dish,
                    hasRestaurantOffer: restaurant.hasOffer,
                    onTap: () => onAddDish(dish),
                    onViewCart: onViewCart,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              key: ValueKey('restaurant_view_menu_${restaurant.id}'),
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: OxroColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View full menu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: OxroColors.charcoal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.restaurantId,
    required this.dish,
    required this.hasRestaurantOffer,
    required this.onTap,
    required this.onViewCart,
  });

  final String restaurantId;
  final Product dish;
  final bool hasRestaurantOffer;
  final VoidCallback onTap;
  final VoidCallback onViewCart;

  bool get _hasOffer => dish.off > 0 || hasRestaurantOffer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('restaurant_dish_${restaurantId}_${dish.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 232,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OxroColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F051D47),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(
              imageUrl: dish.imageUrl,
              colors: dish.colors,
              icon: dish.icon,
              width: 232,
              height: 156,
              radius: 0,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VegMark(veg: dish.veg, egg: dish.egg, size: 13),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            dish.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  Product.inr(dish.price),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: OxroColors.charcoal,
                                  ),
                                ),
                              ),
                              if (dish.mrp > dish.price) ...[
                                const SizedBox(width: 5),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    Product.inr(dish.mrp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: OxroColors.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ViewCartPill(
                          dishKey:
                              'restaurant_dish_cart_${restaurantId}_${dish.id}',
                          onTap: onViewCart,
                        ),
                      ],
                    ),
                    if (_hasOffer) ...[
                      const SizedBox(height: 3),
                      const Text(
                        'Best offer applied',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: RestaurantMenuSection._offerBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewCartPill extends StatelessWidget {
  const _ViewCartPill({required this.dishKey, required this.onTap});

  final String dishKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey(dishKey),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OxroColors.coral, width: 1.2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View cart',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: OxroColors.coral,
              ),
            ),
            SizedBox(width: 1),
            Icon(
              Icons.play_arrow_rounded,
              size: 13,
              color: OxroColors.coral,
            ),
          ],
        ),
      ),
    );
  }
}
