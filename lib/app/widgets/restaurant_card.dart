import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/offer_badge.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

class RestaurantCard extends StatefulWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  final PageController _galleryCtrl = PageController();
  int _page = 0;

  Restaurant get restaurant => widget.restaurant;

  @override
  void didUpdateWidget(covariant RestaurantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurant.id != restaurant.id) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _galleryCtrl.hasClients) _galleryCtrl.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _galleryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = restaurant.photos;
    return GestureDetector(
      key: ValueKey('restaurant_card_${restaurant.id}'),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OxroColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12051D47),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: SizedBox(
                height: 178,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PageView.builder(
                        key: ValueKey('restaurant_gallery_${restaurant.id}'),
                        controller: _galleryCtrl,
                        itemCount: photos.length,
                        onPageChanged: (page) {
                          if (page != _page) setState(() => _page = page);
                        },
                        itemBuilder: (context, i) => FoodImage(
                          imageUrl: photos[i],
                          colors: const [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
                          icon: Icons.restaurant_outlined,
                          width: double.infinity,
                          height: 178,
                          radius: 0,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x33000000),
                                Color(0x00000000),
                                Color(0x99000000),
                              ],
                              stops: [0.0, 0.48, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (photos.length > 1)
                      Positioned(
                        top: 11,
                        right: 11,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < photos.length; i++)
                                  AnimatedContainer(
                                    key: ValueKey(
                                      'restaurant_gallery_dot_${restaurant.id}_$i',
                                    ),
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    width: i == _page ? 10 : 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: i == _page
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (restaurant.pureVeg)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
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
                                  letterSpacing: 0.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 11,
                      right: 11,
                      bottom: 11,
                      child: Row(
                        children: [
                          if (restaurant.hasOffer)
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OfferBadge(text: restaurant.offerText),
                              ),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  restaurant.etaLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
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
                  const SizedBox(height: 5),
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
                  const SizedBox(height: 4),
                  Text(
                    '${restaurant.locality}  •  ${Product.inr(restaurant.costForTwo)} for two',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: OxroColors.muted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.pageBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_rounded,
                          size: 14,
                          color: OxroColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            restaurant.hasOffer
                                ? restaurant.offerText
                                : 'Free delivery on orders above ₹199',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: OxroColors.muted,
                        ),
                      ],
                    ),
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
