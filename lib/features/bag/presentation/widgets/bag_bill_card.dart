import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

class BagBillCard extends StatefulWidget {
  const BagBillCard({
    super.key,
    required this.store,
    required this.quote,
    required this.lines,
  });

  final CartStore store;
  final OrderQuote quote;
  final List<CartLine> lines;

  @override
  State<BagBillCard> createState() => _BagBillCardState();
}

class _BagBillCardState extends State<BagBillCard> {
  bool _open = false;

  void _toggle() {
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final quote = widget.quote;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + widget.lines.length * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: Container(
              padding: EdgeInsets.all(context.rs(14)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OxroColors.border),
                boxShadow: [
                  BoxShadow(
                    color: OxroColors.royalBlue.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('bag_bill_toggle'),
                      onTap: _toggle,
                      borderRadius: BorderRadius.circular(10),
                      child: Semantics(
                        button: true,
                        expanded: _open,
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: OxroColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.receipt_outlined,
                                size: 17,
                                color: OxroColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'TOTAL BILL',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: OxroColors.muted,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${store.count} items',
                                          key: ValueKey(
                                            'bag_bill_count_${store.count}',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: OxroColors.charcoal,
                                          ),
                                        ),
                                      ),
                                      if (store.savings > 0) ...[
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'saved ${Product.inr(store.savings)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: OxroColors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                Money.inr(quote.grandTotalPaise),
                                key: ValueKey(
                                  'bag_bill_total_${quote.grandTotalPaise}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              _open
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 21,
                              color: OxroColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (store.savings > 0) ...[
                    const SizedBox(height: 9),
                    Container(
                      key: const ValueKey('bag_bill_saved'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.green.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: OxroColors.green.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'You saved ${Product.inr(store.savings)} on this order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.green,
                        ),
                      ),
                    ),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _open
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              key: const ValueKey('bag_bill_details'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...widget.lines.map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _dishRow(context, line),
                                  ),
                                ),
                                const Divider(
                                  height: 14,
                                  color: OxroColors.border,
                                ),
                                _billRow(
                                  context,
                                  'Item total',
                                  Money.inr(quote.itemSubtotalPaise),
                                  null,
                                  'items_${quote.itemSubtotalPaise}',
                                ),
                                if (store.savings > 0) ...[
                                  const SizedBox(height: 2),
                                  _billRow(
                                    context,
                                    'Product discount',
                                    '-${Product.inr(store.savings)}',
                                    Colors.green,
                                    'productdisc_${store.savings}',
                                  ),
                                ],
                                if (quote.packagingPaise > 0) ...[
                                  const SizedBox(height: 2),
                                  _billRow(
                                    context,
                                    'Packaging',
                                    Money.inr(quote.packagingPaise),
                                    null,
                                    'pack_${quote.packagingPaise}',
                                  ),
                                ],
                                const SizedBox(height: 2),
                                _billRow(
                                  context,
                                  'Delivery fee',
                                  quote.deliveryFeePaise == 0
                                      ? 'FREE'
                                      : Money.inr(quote.deliveryFeePaise),
                                  quote.deliveryFeePaise == 0
                                      ? Colors.green
                                      : null,
                                  'delivery_${quote.deliveryFeePaise}',
                                ),
                                const SizedBox(height: 2),
                                _billRow(
                                  context,
                                  'Small cart fee',
                                  quote.smallCartFeePaise == 0
                                      ? 'FREE'
                                      : Money.inr(quote.smallCartFeePaise),
                                  quote.smallCartFeePaise == 0
                                      ? Colors.green
                                      : null,
                                  'smallcart_${quote.smallCartFeePaise}',
                                ),
                                const SizedBox(height: 2),
                                _billRow(
                                  context,
                                  'Platform fee',
                                  quote.platformFeePaise == 0
                                      ? 'FREE'
                                      : Money.inr(quote.platformFeePaise),
                                  quote.platformFeePaise == 0
                                      ? Colors.green
                                      : null,
                                  'platform_${quote.platformFeePaise}',
                                ),
                                const SizedBox(height: 2),
                                _billRow(
                                  context,
                                  'GST (5%)',
                                  Money.inr(quote.taxPaise),
                                  null,
                                  'tax_${quote.taxPaise}',
                                ),
                                if (quote.tipPaise > 0) ...[
                                  const SizedBox(height: 2),
                                  _billRow(
                                    context,
                                    'Delivery tip',
                                    Money.inr(quote.tipPaise),
                                    null,
                                    'tip_${quote.tipPaise}',
                                  ),
                                ],
                                if (quote.discountPaise > 0) ...[
                                  const SizedBox(height: 2),
                                  _billRow(
                                    context,
                                    'Coupon',
                                    '-${Money.inr(quote.discountPaise)}',
                                    Colors.green,
                                    'coupon_${quote.discountPaise}',
                                  ),
                                ],
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    color: OxroColors.border,
                                  ),
                                ),
                                SizedBox(
                                  height: 26,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'To Pay',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: OxroColors.charcoal,
                                        ),
                                      ),
                                      const Spacer(),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        transitionBuilder: (child, anim) =>
                                            ScaleTransition(
                                              scale: anim,
                                              child: child,
                                            ),
                                        child: Text(
                                          Money.inr(quote.grandTotalPaise),
                                          key: ValueKey(
                                            'bag_total_${quote.grandTotalPaise}',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: OxroColors.charcoal,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dishRow(BuildContext context, CartLine line) {
    final suffix = line.size == null ? '' : '_${line.size}';
    final name = line.size == null
        ? line.product.name
        : '${line.product.name} - ${line.size}';
    return Row(
      key: ValueKey('bag_bill_dish_${line.product.id}$suffix'),
      children: [
        Expanded(
          child: Text(
            '${line.qty} x $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: OxroColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          Product.inr(line.product.price * line.qty),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: OxroColors.charcoal,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _billRow(
    BuildContext context,
    String label,
    String value,
    Color? color,
    String flashKey,
  ) {
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OxroColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('billflash_$flashKey'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, v, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OxroColors.primary.withValues(alpha: 0.16 * (1 - v)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Text(
                    value,
                    key: ValueKey('billval_$flashKey'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: color ?? OxroColors.charcoal,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
