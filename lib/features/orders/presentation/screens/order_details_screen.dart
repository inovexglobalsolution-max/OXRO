import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';
import 'package:oxro/features/reviews/data/review_repo.dart';
import 'package:oxro/features/reviews/data/review_store.dart';

/// 20 Order Details — ref 1:1 + premium: status hero + staggered
/// item cards + address card + bill card + Track/Return actions.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState
    extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Widget _in(double start, Widget child) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((_entry.value - start) / (1 - start))
              .clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final matches =
        store.all.where((o) => o.id == widget.orderId);
    final order = matches.isEmpty ? null : matches.first;
    final status = store.statusOf(widget.orderId);
    final products = order?.products ?? const <Product>[];
    final itemsTotal =
        products.fold(0, (s, p) => s + p.price);
    const ship = 40;
    final toPay = itemsTotal + ship;
    final heroColor = status == OrderStatus.delivered
        ? Colors.green
        : status == OrderStatus.cancelled
            ? Colors.red
            : OxroColors.royalBlue;
    final heroLabel = switch (status) {
      OrderStatus.processing => 'Processing',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.outForDelivery => 'Out for delivery',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
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
                  Expanded(
                    child: Text('Order Details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('details_screen'),
                padding: EdgeInsets.fromLTRB(
                    context.padX, 4, context.padX, 16),
                children: [
                  _in(
                    0.1,
                    Container(
                      padding: EdgeInsets.all(
                          context.rs(14)),
                      decoration: BoxDecoration(
                        gradient: OxroColors.gradient,
                        borderRadius:
                            BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30051D47),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(widget.orderId,
                                    key: const ValueKey(
                                        'details_id'),
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        color:
                                            Colors.white)),
                                const SizedBox(height: 2),
                                Text(
                                    '${products.length} items • ${Product.inr(toPay)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(
                                                alpha:
                                                    0.85))),
                              ],
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(
                                      16),
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: heroColor,
                                      shape:
                                          BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(heroLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        color: heroColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  _in(
                    0.3,
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('ITEMS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w800,
                                color: OxroColors.muted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        if (products.isEmpty)
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                      14),
                              border: Border.all(
                                  color:
                                      OxroColors.border),
                            ),
                            child: const Text(
                                'Order snapshot unavailable',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        OxroColors.muted)),
                          )
                        else
                          for (var i = 0;
                              i < products.length;
                              i++)
                            _itemCard(
                                context, products[i], i),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  _in(
                    0.5,
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                          context.rs(12)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                            color: OxroColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                              Icons
                                  .location_on_outlined,
                              size: 20,
                              color: OxroColors
                                  .royalBlue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text('Delivery Address',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight
                                                .w700)),
                                Text(
                                    '123, Anna Nagar, Chennai — 600040',
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: OxroColors
                                            .muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  _in(
                    0.6,
                    Container(
                      padding: EdgeInsets.all(
                          context.rs(14)),
                      decoration: BoxDecoration(
                        color: OxroColors.pageBg,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                            color: OxroColors.border),
                      ),
                      child: Column(
                        children: [
                          _billRow('Items Total',
                              Product.inr(itemsTotal)),
                          const SizedBox(height: 6),
                          _billRow('Shipping Fee',
                              Product.inr(ship)),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 10),
                            child: Divider(
                                height: 1,
                                color:
                                    OxroColors.border),
                          ),
                          _billRow(
                              'Total Amount',
                              Product.inr(toPay),
                              bold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    context.padX, 8, context.padX, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(
                          color: OxroColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey(
                            'details_return'),
                        onTap: () => showOxroSnack(
                            context,
                            'Return — coming next'),
                        behavior:
                            HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(
                                    12),
                            border: Border.all(
                                color: OxroColors
                                    .royalBlue,
                                width: 1.5),
                          ),
                          child: const Text(
                              'Return',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.w800,
                                  color: OxroColors
                                      .royalBlue)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey(
                            'details_track'),
                        onTap: () => pushScreen(
                            context,
                            TrackingScreen(
                                orderId:
                                    widget.orderId)),
                        behavior:
                            HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 13),
                          decoration: BoxDecoration(
                            color: OxroColors.primary,
                            borderRadius:
                                BorderRadius.circular(
                                    12),
                          ),
                          child: const Text(
                              'Track Order',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w800)),
                        ),
                      ),
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

  Widget _itemCard(
      BuildContext context, Product p, int i) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('details_item_${p.id}_$i'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + i * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                    color: OxroColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: p.colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Icon(p.icon,
                            size: 26,
                            color: OxroColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(p.brand,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: OxroColors.muted,
                                    fontWeight:
                                        FontWeight.w600)),
                            Text(p.name,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(Product.inr(p.price),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Past-order review entry: visible only while the
                  // 48h window is open (expired -> full hide).
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      OrderStore.instance,
                      ReviewStore.instance,
                    ]),
                    builder: (context, _) {
                      final access = ReviewRepo.canReview(
                        productId: p.id,
                        orders: OrderStore.instance.all,
                      );
                      if (access != ReviewAccess.ok) {
                        return const SizedBox.shrink();
                      }
                      if (ReviewStore.instance
                          .hasReviewed(p.id)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Spacer(),
                              Container(
                                key: ValueKey(
                                    'details_reviewed_${p.id}'),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(
                                      alpha: 0.10),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 14,
                                        color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Reviewed',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w800,
                                            color: Colors.green)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Spacer(),
                            GestureDetector(
                              key: ValueKey(
                                  'details_review_${p.id}'),
                              onTap: () => pushScreen(
                                context,
                                ProductDetailScreen(
                                  product: p,
                                  autoOpenReview: true,
                                ),
                              ),
                              behavior:
                                  HitTestBehavior.opaque,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: OxroColors
                                          .primary),
                                ),
                                child: const Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_outline,
                                        size: 14,
                                        color: OxroColors
                                            .primary),
                                    SizedBox(width: 4),
                                    Text('Write Review',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w800,
                                            color: OxroColors
                                                .primary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _billRow(String label, String value,
      {bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: bold
                    ? OxroColors.charcoal
                    : OxroColors.muted,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w500)),
        const Spacer(),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: FontWeight.w800,
                  color: bold
                      ? OxroColors.primary
                      : OxroColors.charcoal)),
        ),
      ],
    );
  }
}
