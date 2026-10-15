import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Coupons & Offers — browse promos, apply one to the cart.
/// Applies straight into PaymentStore; pops true when applied.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                  const Expanded(
                    child: Text('Coupons & Offers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  CartStore.instance,
                  PaymentStore.instance,
                ]),
                builder: (context, _) {
                  final total =
                      CartStore.instance.totalPrice;
                  final applied =
                      PaymentStore.instance.coupon;
                  final best = CouponStore.eligibleFor(
                          total,
                          shipValue:
                              PaymentStore.shippingFee)
                      .map((c) => c.code)
                      .toSet();
                  // Best = first of eligible ranking.
                  final top = best.isEmpty
                      ? null
                      : CouponStore.eligibleFor(total,
                              shipValue: PaymentStore
                                  .shippingFee)
                          .first
                          .code;
                  return ListView(
                    key: const ValueKey('coupons_scroll'),
                    padding: EdgeInsets.fromLTRB(
                        context.padX, 6, context.padX, 20),
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                            context.rs(12)),
                        decoration: BoxDecoration(
                          color: OxroColors.pageBg,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: OxroColors.border),
                        ),
                        child: Text(
                            'Cart total ${Product.inr(total)} — ${best.length} offer${best.length == 1 ? '' : 's'} for you',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.charcoal)),
                      ),
                      SizedBox(height: context.rs(10)),
                      for (final c in CouponStore.coupons)
                        _card(context, c, total, applied,
                            isBest: c.code == top),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Coupon c, int total,
      String applied,
      {required bool isBest}) {
    final ok = total >= c.minOrder;
    final saving =
        c.discountFor(total) + (c.freeShip ? PaymentStore.shippingFee : 0);
    final isApplied = applied == c.code;
    return Container(
      key: ValueKey('coupon_card_${c.code}'),
      margin: EdgeInsets.only(bottom: context.rs(10)),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: isApplied
            ? OxroColors.primary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isApplied ? OxroColors.primary : OxroColors.border,
          width: isApplied ? 1.8 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: OxroColors.royalBlue
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: OxroColors.royalBlue
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Text(c.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.royalBlue)),
            ),
          ),
          SizedBox(width: context.rs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.charcoal)),
                    ),
                    if (isBest && ok && !isApplied) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: const Text('BEST',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                Text(
                    ok
                        ? (isApplied
                            ? 'Applied — you save ${Product.inr(saving)}'
                            : '${c.sub} — saves ${Product.inr(saving)}')
                        : '${c.sub} (add ${Product.inr(c.minOrder - total)} more)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: OxroColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: ValueKey('coupon_apply_${c.code}'),
            onTap: () {
              if (!ok || isApplied) return;
              final good =
                  PaymentStore.instance.applyCoupon(c.code);
              if (!context.mounted) return;
              if (good) {
                showOxroSnack(
                    context, '${c.code} applied');
                Navigator.of(context).pop(true);
              } else {
                showOxroSnack(
                    context, '${c.code} not eligible yet');
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: (!ok || isApplied)
                    ? OxroColors.lightGrey
                    : OxroColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(isApplied ? 'Applied' : 'Apply',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: (!ok || isApplied)
                          ? OxroColors.muted
                          : Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
