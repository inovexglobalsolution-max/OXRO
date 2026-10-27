import 'package:flutter/material.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';

/// 19 My Orders — Active (left) + Past Orders (right).
/// Mobile: stacked sections. Tablet (≥600): side-by-side Row.
/// Past cards carry Reorder → bag + Track → 18 Tracking.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.onShopNow, this.onBag});

  /// Empty-state CTA → Home tab.
  final VoidCallback onShopNow;

  /// Optional route to the Bag after reordering.
  final VoidCallback? onBag;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _filter = 0; // 0 All · 1 Active · 2 Past

  static const _filters = ['All', 'Active', 'Past'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 8),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Orders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.padX),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = i == _filter;
                  return GestureDetector(
                    key: ValueKey('orders_filter_$i'),
                    onTap: () => setState(() => _filter = i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? OxroColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? Colors.transparent : OxroColors.border,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : OxroColors.charcoal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: context.rs(8)),
            Expanded(
              child: ListenableBuilder(
                listenable: OrderStore.instance,
                builder: (context, _) {
                  final store = OrderStore.instance;
                  final showActive = _filter == 0 || _filter == 1;
                  final showPast = _filter == 0 || _filter == 2;
                  final active = store.active;
                  final past = store.past;
                  if (active.isEmpty && past.isEmpty) {
                    return _empty();
                  }
                  if (_filter == 1 && active.isEmpty) {
                    return _miniEmpty('No active orders');
                  }
                  if (_filter == 2 && past.isEmpty) {
                    return _miniEmpty('No past orders yet');
                  }
                  final body = context.isTablet
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showActive)
                              Expanded(child: _section('Active', active, true)),
                            if (showActive && showPast)
                              const VerticalDivider(
                                width: 1,
                                color: OxroColors.border,
                              ),
                            if (showPast)
                              Expanded(
                                child: _section('Past Orders', past, false),
                              ),
                          ],
                        )
                      : ListView(
                          key: const ValueKey('orders_list'),
                          padding: EdgeInsets.fromLTRB(
                            context.padX,
                            4,
                            context.padX,
                            16,
                          ),
                          children: [
                            if (showActive) _section('Active', active, true),
                            if (showActive && showPast)
                              SizedBox(height: context.rs(8)),
                            if (showPast) _section('Past Orders', past, false),
                            if (showPast)
                              Center(
                                child: GestureDetector(
                                  key: const ValueKey('past_all_btn'),
                                  onTap: () => setState(() => _filter = 2),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'View All Past >',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: OxroColors.royalBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                  if (context.isTablet) {
                    return SingleChildScrollView(
                      key: const ValueKey('orders_list'),
                      padding: EdgeInsets.fromLTRB(
                        context.padX,
                        4,
                        context.padX,
                        16,
                      ),
                      child: Column(
                        children: [
                          body,
                          if (showPast)
                            Center(
                              child: GestureDetector(
                                key: const ValueKey('past_all_btn'),
                                onTap: () => setState(() => _filter = 2),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'View All Past >',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OxroColors.royalBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  return body;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<MockOrder> items, bool isActive) {
    return Column(
      key: ValueKey(isActive ? 'orders_active_list' : 'orders_past_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: OxroColors.muted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          _stagger(i, _orderCard(items[i], isActive)),
      ],
    );
  }

  Widget _stagger(int i, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (i % 8) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _orderCard(MockOrder o, bool isActive) {
    final past = !isActive;
    final dot = switch (o.status) {
      OrderStatus.delivered => Colors.green,
      OrderStatus.cancelled => Colors.red,
      OrderStatus.shipped || OrderStatus.outForDelivery => OxroColors.royalBlue,
      OrderStatus.processing => OxroColors.primary,
    };
    final statusLabel = o.status.label;
    return GestureDetector(
      onTap: () => pushScreen(context, OrderDetailsScreen(orderId: o.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: ValueKey('order_card_${o.id}'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OxroColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dot,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (o.kitchenName != null)
              Text(
                o.kitchenName!,
                key: ValueKey('order_kitchen_${o.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OxroColors.charcoal,
                ),
              ),
            Text(
              '${o.date} • ${Money.inr(o.payablePaise)}',
              style: const TextStyle(fontSize: 12, color: OxroColors.muted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < o.products.take(3).length; i++)
                  Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: o.products[i].colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      o.products[i].icon,
                      size: 20,
                      color: OxroColors.muted,
                    ),
                  ),
                if (o.products.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '+${o.products.length - 3}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                  ),
                const Spacer(),
                if (past)
                  GestureDetector(
                    key: ValueKey('reorder_${o.id}'),
                    onTap: () => _reorder(o),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Reorder',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    key: ValueKey('track_btn_${o.id}'),
                    onTap: () =>
                        pushScreen(context, TrackingScreen(orderId: o.id)),
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Track >',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.royalBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorder(MockOrder o) async {
    if (o.products.isEmpty) return;
    final cart = CartStore.instance;
    if (cart.belongsToOtherRestaurant(o.products.first)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace bag?'),
          content: Text(
            'Your bag has items from '
            '${cart.restaurantName ?? 'another restaurant'}. '
            'Reordering from ${o.kitchenName ?? 'this restaurant'} '
            'will clear it.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('reorder_replace_no'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep bag'),
            ),
            TextButton(
              key: const ValueKey('reorder_replace_yes'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final n = OrderStore.instance.reorder(o.id);
    if (!mounted) return;
    showOxroSnack(
      context,
      'Added back to Bag ($n)',
      actionLabel: widget.onBag == null ? null : 'VIEW BAG',
      onAction: widget.onBag,
    );
  }

  Widget _empty() {
    return Center(
      key: const ValueKey('orders_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OxroColors.royalBlue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining,
              size: 36,
              color: OxroColors.royalBlue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No orders yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Track your orders here',
            style: TextStyle(fontSize: 13, color: OxroColors.muted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('orders_shop_now'),
            onTap: widget.onShopNow,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Shop Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniEmpty(String msg) {
    return Center(
      child: Text(
        msg,
        style: const TextStyle(fontSize: 13, color: OxroColors.muted),
      ),
    );
  }
}
