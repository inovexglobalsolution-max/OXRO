import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/section_header.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';
import 'package:oxro/features/detail/data/product_sizes.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/cart/presentation/quick_add.dart';

class BagReveal extends StatelessWidget {
  const BagReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 55),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class BagPremiumOfferCard extends StatefulWidget {
  const BagPremiumOfferCard({
    super.key,
    required this.total,
    required this.member,
    required this.onOpen,
  });

  final int total;
  final bool member;
  final VoidCallback onOpen;

  @override
  State<BagPremiumOfferCard> createState() => _BagPremiumOfferCardState();
}

class _BagPremiumOfferCardState extends State<BagPremiumOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threshold = PremiumStore.freeDeliveryMinOrder;
    final eligible = widget.member && widget.total >= threshold;
    final missing = (threshold - widget.total).clamp(0, threshold);
    final progress = (widget.total / threshold).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      key: const ValueKey('bag_premium_card'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            OxroColors.premiumDeep,
            OxroColors.premiumBurgundy,
            OxroColors.premiumWine,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: OxroColors.premiumDeep.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shine,
                  builder: (context, _) {
                    if (reduce) return const SizedBox.shrink();
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final x = -width + (width * 2.6) * _shine.value;
                        return Transform.translate(
                          offset: Offset(x, 0),
                          child: Transform.rotate(
                            angle: -0.35,
                            child: Container(
                              width: width * 0.42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.rs(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.premiumCream.withValues(
                            alpha: 0.10,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OxroColors.premiumChampagne.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 25,
                          color: OxroColors.premiumChampagne,
                        ),
                      ),
                      SizedBox(width: context.rs(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member
                                  ? 'OXRO PREMIUM'
                                  : 'SPECIAL OFFER FOR YOU',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.premiumChampagne,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.member
                                  ? 'PREMIUM ACTIVE'
                                  : 'FREE DELIVERY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: OxroColors.premiumCream,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.member
                                  ? (eligible
                                        ? 'Your delivery fee is on us today.'
                                        : 'Add ${Product.inr(missing)} more to unlock free delivery.')
                                  : 'Join PREMIUM and make delivery free on orders above ${Product.inr(threshold)}.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: OxroColors.premiumCream.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.member) ...[
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(
                          OxroColors.premiumChampagne,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (eligible)
                          Container(
                            key: const ValueKey('bag_premium_active'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: OxroColors.green.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: OxroColors.green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Color(0xFF7BE3A4),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'FREE DELIVERY APPLIED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 0.7,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB8F5D0),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            '${(progress * 100).round()}% of the way there',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.premiumCream.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 13),
                  PressScale(
                    key: const ValueKey('bag_premium_cta'),
                    onTap: widget.onOpen,
                    child: Container(
                      width: double.infinity,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OxroColors.premiumCream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.member
                                ? 'MANAGE MEMBERSHIP'
                                : 'JOIN PREMIUM AT ${Product.inr(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w900,
                              color: OxroColors.premiumInk,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: OxroColors.premiumInk,
                          ),
                        ],
                      ),
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

class BagCouponCard extends StatelessWidget {
  const BagCouponCard({
    super.key,
    required this.store,
    required this.payment,
    required this.onViewAll,
  });

  final CartStore store;
  final PaymentStore payment;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final applied = CouponStore.byCode(payment.coupon);
    final eligible = CouponStore.eligibleFor(
      store.totalPrice,
      shipValue: PaymentStore.shippingFee,
    );
    final best = eligible.isEmpty ? null : eligible.first;

    return Container(
      key: const ValueKey('bag_coupons'),
      padding: EdgeInsets.all(context.rs(13)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OxroColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A051D47),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OxroColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 16,
                  color: OxroColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'COUPONS & OFFERS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.muted,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('bag_coupon_view_all'),
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const _PerforatedDivider(),
          const SizedBox(height: 11),
          if (applied != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OxroColors.green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: OxroColors.green,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applied.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        payment.discount > 0
                            ? '${applied.code} applied - ${Product.inr(payment.discount)} saved'
                            : '${applied.code} applied - free delivery',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: OxroColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('bag_coupon_remove'),
                  onPressed: payment.clearCoupon,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: OxroColors.muted,
                    ),
                  ),
                ),
              ],
            )
          else if (best != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: OxroColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'BEST',
                    style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9A6A16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Use ${best.code} - ${best.sub}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: OxroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  key: ValueKey('bag_coupon_apply_${best.code}'),
                  onTap: () {
                    final ok = payment.applyCoupon(best.code);
                    showOxroSnack(
                      context,
                      ok
                          ? '${best.code} applied'
                          : 'This coupon is no longer available',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: OxroColors.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Text(
                      'APPLY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'No coupons available for this cart yet.',
              style: TextStyle(
                fontSize: 11.5,
                color: OxroColors.muted.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }
}

class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 10,
          decoration: BoxDecoration(
            color: OxroColors.bgWarm,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(99),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dash = 5.0;
              const gap = 5.0;
              final count = (constraints.maxWidth / (dash + gap)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  count,
                  (_) => Container(
                    width: dash,
                    height: 1,
                    color: OxroColors.border,
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 6,
          height: 10,
          decoration: BoxDecoration(
            color: OxroColors.bgWarm,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(99),
            ),
          ),
        ),
      ],
    );
  }
}

class BagDeliveryAddressCard extends StatelessWidget {
  const BagDeliveryAddressCard({
    super.key,
    required this.address,
    required this.eta,
    required this.onTap,
  });

  final Address? address;
  final String? eta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('bag_address'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(context.rs(13)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OxroColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OxroColors.royalBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: OxroColors.royalBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a == null
                                ? 'Add delivery address'
                                : 'Delivery at ${a.label.isEmpty ? a.name : a.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        if (eta != null && eta!.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: OxroColors.green.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                eta!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: OxroColors.green,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a == null
                          ? 'We will deliver your order here'
                          : '${a.line}, ${a.city} - ${a.pin}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: OxroColors.muted,
                      ),
                    ),
                    if (a == null) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to add your address',
                        key: ValueKey('bag_address_add'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OxroColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BagCancellationNote extends StatelessWidget {
  const BagCancellationNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('bag_cancellation'),
      padding: EdgeInsets.all(context.rs(13)),
      decoration: BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.policy_outlined, size: 18, color: OxroColors.muted),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancellation policy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Cancel before the restaurant starts preparing for a full refund. '
                  'Once packed, the order cannot be cancelled.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: OxroColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BagMealRail extends StatelessWidget {
  const BagMealRail({super.key, required this.restaurant, required this.store});

  final Restaurant restaurant;
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final dishes = restaurant.dishes
        .where((dish) => !store.contains(dish.id))
        .take(6)
        .toList();
    if (dishes.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('bag_meal_rail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Complete your meal',
          subtitle: 'Add something extra from the kitchen',
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: dishes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return _MealCard(dish: dish);
            },
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.dish});

  final Product dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('bag_meal_${dish.id}'),
      width: 146,
      padding: EdgeInsets.all(context.rs(7)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OxroColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A051D47),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodImage(
            imageUrl: dish.imageUrl,
            colors: dish.colors,
            icon: dish.icon,
            width: double.infinity,
            height: 82,
            radius: 11,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              VegMark(veg: dish.veg, egg: dish.egg, size: 11),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
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
                child: Text(
                  Product.inr(dish.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
              PressScale(
                key: ValueKey('bag_meal_add_${dish.id}'),
                onTap: () => quickAddProduct(
                  context,
                  dish,
                  size: defaultSizeFor(dish),
                  customize: false,
                ),
                child: Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OxroColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: OxroColors.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 17,
                    color: OxroColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
