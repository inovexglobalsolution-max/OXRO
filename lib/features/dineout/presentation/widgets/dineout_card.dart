import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/features/dineout/data/dineout_repo.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

class DineoutCard extends StatelessWidget {
  const DineoutCard({super.key, required this.restaurant, required this.onTap});

  final DineoutRestaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('dineout_card_${restaurant.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OxroColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10051D47),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              child: Stack(
                children: [
                  FoodImage(
                    imageUrl: restaurant.imageUrl,
                    colors: const [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
                    icon: Icons.restaurant_outlined,
                    width: double.infinity,
                    height: context.isSmallPhone ? 132 : 156,
                    radius: 0,
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x22000000),
                            Color(0x00000000),
                            Color(0x88000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (restaurant.hasOffer)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      right: 10,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: OxroColors.primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            restaurant.offerText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (restaurant.pureVeg)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.eco_rounded,
                              size: 11,
                              color: OxroColors.vegGreen,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'PURE VEG',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: OxroColors.vegGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: OxroColors.charcoal,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RatingChip(rating: restaurant.rating, compact: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.cuisineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: OxroColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${restaurant.area} • ${restaurant.distanceLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: OxroColors.muted,
                          ),
                        ),
                      ),
                      Text(
                        '${Money.inr(restaurant.costForTwo * 100)} for two',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ],
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
