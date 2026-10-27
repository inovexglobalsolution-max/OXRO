import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

/// A dish paired with the restaurant that serves it.
class RestaurantDish {
  const RestaurantDish({required this.restaurant, required this.dish});

  final Restaurant restaurant;
  final Product dish;
}

/// Premium mint carousel for dishes from kitchens delivering in 30 minutes.
class FastDishRail extends StatefulWidget {
  const FastDishRail({super.key, required this.items, required this.onTap});

  final List<RestaurantDish> items;
  final ValueChanged<RestaurantDish> onTap;

  @override
  State<FastDishRail> createState() => _FastDishRailState();
}

class _FastDishRailState extends State<FastDishRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce == _reduced) return;
    _reduced = reduce;
    if (reduce) {
      _ambient.stop();
      _ambient.value = 0.35;
    } else {
      _ambient.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(context.padX, 18, context.padX, 18),
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final t = _reduced ? 0.35 : _ambient.value;
          final wave = (math.sin(t * math.pi * 2) + 1) / 2;
          final glow = 0.10 + 0.05 * wave;
          return Container(
            key: const ValueKey('home_fast_dishes'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + 0.16 * wave, -1),
                end: Alignment(1, 1 - 0.12 * wave),
                colors: const [
                  Color(0xFFE6F8EF),
                  Color(0xFFF7FCF9),
                  Color(0xFFEAF8F1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFD3EEDF),
                  const Color(0xFFB9E5CC),
                  wave,
                )!,
              ),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.vegGreen.withValues(alpha: glow),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80 + 12 * wave,
                  right: -45,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          OxroColors.vegGreen.withValues(
                            alpha: 0.13 + 0.05 * wave,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -90,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1 + 0.05 * math.sin(t * math.pi * 2),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2BB673),
                                    OxroColors.vegGreen,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: OxroColors.vegGreen.withValues(
                                      alpha: 0.28 + 0.10 * wave,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                  letterSpacing: -0.2,
                                ),
                                children: [
                                  TextSpan(text: 'Deliveries under '),
                                  TextSpan(
                                    text: '30 minutes',
                                    style: TextStyle(
                                      color: OxroColors.vegGreen,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            child: const Icon(
                              Icons.local_shipping_outlined,
                              size: 17,
                              color: OxroColors.vegGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 41),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Hot, fresh and lightning fast',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: OxroColors.muted,
                                ),
                              ),
                            ),
                            if (widget.items.length > 6)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: OxroColors.vegGreen.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  '${widget.items.length} picks',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: OxroColors.vegGreen,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 238,
                        child: ListView.separated(
                          key: const ValueKey('home_fast_dishes_rail'),
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.hardEdge,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 10),
                          itemCount: widget.items.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final item = widget.items[i];
                            final duration = _reduced
                                ? Duration.zero
                                : Duration(milliseconds: 380 + (i % 4) * 55);
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              builder: (context, v, child) {
                                return Opacity(
                                  opacity: v,
                                  child: Transform.translate(
                                    offset: Offset(18 * (1 - v), 0),
                                    child: child,
                                  ),
                                );
                              },
                              child: _FastDishCard(
                                item: item,
                                onTap: () => widget.onTap(item),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FastDishCard extends StatelessWidget {
  const _FastDishCard({required this.item, required this.onTap});

  final RestaurantDish item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dish = item.dish;
    return PressScale(
      key: ValueKey('home_fast_dish_${item.restaurant.id}_${dish.id}'),
      onTap: onTap,
      child: Container(
        width: 158,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2F2E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14051D47),
              blurRadius: 14,
              offset: Offset(0, 6),
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
              child: SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      imageUrl: dish.imageUrl,
                      colors: dish.colors,
                      icon: dish.icon,
                      width: 158,
                      height: 120,
                      radius: 0,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x00000000),
                            Color(0x5C000000),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A000000), blurRadius: 5),
                          ],
                        ),
                        child: VegMark(veg: dish.veg, size: 11),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: RatingChip(rating: dish.rating, compact: true),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: OxroColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: OxroColors.vegGreen.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                size: 11,
                                color: OxroColors.vegGreen,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                '${item.restaurant.etaMinutes} mins',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.vegGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Product.inr(dish.price),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ],
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
}
