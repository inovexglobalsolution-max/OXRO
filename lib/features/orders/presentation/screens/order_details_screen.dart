import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/invoice_screen.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/reviews/data/review_repo.dart';
import 'package:oxro/features/reviews/data/review_store.dart';

const _odCanvas = Color(0xFFFFFBF6);
const _odSurface = Color(0xFFFFFFFF);
const _odInk = Color(0xFF102A43);
const _odMuted = Color(0xFF62758A);
const _odAccent = Color(0xFFFF6A00);
const _odAccentDeep = Color(0xFFE85D00);
const _odTint = Color(0xFFFFF1E6);
const _odLine = Color(0xFFFFD9BE);
const _odHeroTop = Color(0xFF071C33);
const _odHeroBottom = Color(0xFF102A43);
const _odDelivered = Color(0xFF16A34A);
const _odCancelled = Color(0xFFE5484D);

/// 20 Order Details — premium warm receipt with an ink status hero,
/// staggered entrance, PREMIUM ad slot and Track/Help actions.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _fx;
  bool _fxStarted = false;
  bool _reduceMotion = false;
  bool _adDismissed = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..forward();
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _entry.value = 1;
      _fx.value = 1;
    } else if (!_fxStarted) {
      _fxStarted = true;
      _fx.forward();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _fx.dispose();
    super.dispose();
  }

  void _haptic() {
    if (!_reduceMotion) HapticFeedback.lightImpact();
  }

  void _openPremium() {
    _haptic();
    pushScreen(context, const PremiumScreen());
  }

  void _dismissAd() {
    _haptic();
    setState(() => _adDismissed = true);
  }

  Widget _in(double start, Widget child) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((_entry.value - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - t)),
            child: Transform.scale(scale: 0.985 + 0.015 * t, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final matches = store.all.where((o) => o.id == widget.orderId);
    final order = matches.isEmpty ? null : matches.first;
    final status = store.statusOf(widget.orderId);
    final products = order?.products ?? const <Product>[];
    final bill = order?.bill;
    final itemsTotalPaise =
        bill?.itemSubtotalPaise ??
        products.fold(0, (s, p) => s + p.price) * 100;
    final toPayPaise = order?.payablePaise ?? itemsTotalPaise;
    final statusColor = status == OrderStatus.delivered
        ? _odDelivered
        : status == OrderStatus.cancelled
        ? _odCancelled
        : _odAccent;
    final kitchen = order?.kitchenName;
    final instructions = order?.instructions;
    final cutleryOptIn = order?.cutleryOptIn;
    final restaurant = order == null
        ? null
        : RestaurantRepo.byId(order.restaurantId ?? '');
    final eta = store.etaFor(widget.orderId);
    final orderDate = order?.date ?? 'Today';

    return Scaffold(
      backgroundColor: _odCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, _odCanvas],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.padX,
                  context.rs(6),
                  context.padX,
                  context.rs(6),
                ),
                child: Row(
                  children: [
                    PressScale(
                      onTap: () {
                        _haptic();
                        Navigator.of(context).maybePop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _odLine),
                          boxShadow: [
                            BoxShadow(
                              color: _odInk.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: _odInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: _odInk,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Receipt & live updates',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _odMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('details_screen'),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                  padding: EdgeInsets.fromLTRB(
                    context.padX,
                    context.rs(4),
                    context.padX,
                    context.rs(18),
                  ),
                  children: [
                    _in(
                      0.02,
                      _heroCard(
                        context,
                        itemCount: products.length,
                        toPayPaise: toPayPaise,
                        statusLabel: status.label,
                        statusColor: statusColor,
                        eta: eta,
                        date: orderDate,
                      ),
                    ),
                    SizedBox(height: context.rs(12)),
                    if (kitchen != null) ...[
                      _in(
                        0.16,
                        _restaurantCard(
                          context,
                          kitchen: kitchen,
                          restaurant: restaurant,
                        ),
                      ),
                      SizedBox(height: context.rs(12)),
                    ],
                    if (instructions != null || cutleryOptIn != null) ...[
                      _in(
                        0.24,
                        _prefsCard(
                          context,
                          instructions: instructions,
                          cutleryOptIn: cutleryOptIn,
                        ),
                      ),
                      SizedBox(height: context.rs(12)),
                    ],
                    _in(0.32, _itemsSection(context, products)),
                    SizedBox(height: context.rs(12)),
                    if (!_adDismissed) ...[
                      _in(0.46, _premiumAdBanner(context)),
                      SizedBox(height: context.rs(12)),
                    ],
                    _in(0.55, _addressCard(context)),
                    SizedBox(height: context.rs(12)),
                    _in(
                      0.64,
                      _billCard(
                        context,
                        bill: bill,
                        itemsTotalPaise: itemsTotalPaise,
                        toPayPaise: toPayPaise,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    context.padX,
                    context.rs(10),
                    context.padX,
                    context.rs(10),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(top: BorderSide(color: _odLine)),
                    boxShadow: [
                      BoxShadow(
                        color: _odInk.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: PressScale(
                          key: const ValueKey('details_return'),
                          onTap: () {
                            _haptic();
                            pushScreen(
                              context,
                              HelpScreen(orderId: widget.orderId),
                            );
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _odInk.withValues(alpha: 0.7),
                                width: 1.4,
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.headset_mic_outlined,
                                    size: 17,
                                    color: _odInk,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Help',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: _odInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: PressScale(
                          key: const ValueKey('details_track'),
                          onTap: () {
                            _haptic();
                            pushScreen(
                              context,
                              TrackingScreen(orderId: widget.orderId),
                            );
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_odAccent, _odAccentDeep],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _odAccent.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_shipping_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Track Order',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }

  Widget _heroCard(
    BuildContext context, {
    required int itemCount,
    required int toPayPaise,
    required String statusLabel,
    required Color statusColor,
    required String eta,
    required String date,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_odHeroTop, _odHeroBottom],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _odHeroBottom.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -58,
            right: -44,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _odAccent.withValues(alpha: 0.42),
                    _odAccent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -58,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OxroColors.royalBlue.withValues(alpha: 0.6),
                    OxroColors.royalBlue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fx,
                builder: (context, _) => CustomPaint(
                  painter: _OdShinePainter(
                    progress: _fx.value,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.rs(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ORDER',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: Color(0x8AFFFFFF),
                        ),
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      label: 'Order status $statusLabel',
                      child: AnimatedSwitcher(
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: Container(
                          key: ValueKey('details_status_$statusLabel'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _pulseDot(statusColor),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rs(12)),
                Text(
                  widget.orderId,
                  key: const ValueKey('details_id'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: toPayPaise.toDouble(),
                      ),
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        Money.inr(value.round()),
                        key: const ValueKey('details_total'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: OxroColors.premiumCream,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        eta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseDot(Color color) {
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 7),
        ],
      ),
    );
    if (_reduceMotion) return dot;
    return AnimatedBuilder(
      animation: _fx,
      builder: (context, _) {
        final t = (_fx.value / 0.4).clamp(0.0, 1.0);
        return SizedBox(
          width: 17,
          height: 17,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (t < 1)
                Container(
                  width: 7 + 10 * t,
                  height: 7 + 10 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.45 * (1 - t)),
                    ),
                  ),
                ),
              dot,
            ],
          ),
        );
      },
    );
  }

  Widget _restaurantCard(
    BuildContext context, {
    required String kitchen,
    Restaurant? restaurant,
  }) {
    return _card(
      key: const ValueKey('details_restaurant'),
      context: context,
      padding: EdgeInsets.all(context.rs(12)),
      child: Row(
        children: [
          _iconChip(Icons.storefront_rounded),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kitchen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _odInk,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  restaurant == null
                      ? 'Kitchen partner'
                      : '${restaurant.locality} • ${restaurant.etaMinutes} mins away',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _odMuted),
                ),
              ],
            ),
          ),
          if (restaurant != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _odTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: _odAccentDeep,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    restaurant.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: _odAccentDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _prefsCard(
    BuildContext context, {
    String? instructions,
    bool? cutleryOptIn,
  }) {
    return _card(
      key: const ValueKey('details_food_prefs'),
      context: context,
      padding: EdgeInsets.all(context.rs(13)),
      child: Column(
        children: [
          if (instructions != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconChip(Icons.edit_note_rounded, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Restaurant note',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _odMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        instructions,
                        key: const ValueKey('details_note'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _odInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (instructions != null && cutleryOptIn != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Divider(height: 1, color: _odLine),
            ),
          if (cutleryOptIn != null)
            Row(
              children: [
                _iconChip(Icons.restaurant_rounded, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cutleryOptIn ? 'Cutlery opted in' : 'No cutlery requested',
                    key: const ValueKey('details_cutlery'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _odInk,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _itemsSection(BuildContext context, List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Row(
            children: [
              const Text(
                'ITEMS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: _odMuted,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _odTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${products.length} ${products.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _odAccentDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (products.isEmpty)
          _card(
            context: context,
            padding: const EdgeInsets.all(14),
            child: const Text(
              'Order snapshot unavailable',
              style: TextStyle(fontSize: 13, color: _odMuted),
            ),
          )
        else
          for (var i = 0; i < products.length; i++)
            _itemCard(context, products[i], i),
      ],
    );
  }

  Widget _itemCard(BuildContext context, Product p, int i) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('details_item_${p.id}_$i'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + i * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _odSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _odLine),
                boxShadow: [
                  BoxShadow(
                    color: _odInk.withValues(alpha: 0.035),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Icon(
                          p.icon,
                          size: 25,
                          color: _odInk.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _odMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _odInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              Product.inr(p.price),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: _odAccentDeep,
                              ),
                            ),
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
                      if (ReviewStore.instance.hasReviewed(p.id)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Row(
                            children: [
                              const Spacer(),
                              Container(
                                key: ValueKey('details_reviewed_${p.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reviewed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Row(
                          children: [
                            const Spacer(),
                            PressScale(
                              key: ValueKey('details_review_${p.id}'),
                              onTap: () {
                                _haptic();
                                pushScreen(
                                  context,
                                  ProductDetailScreen(
                                    product: p,
                                    autoOpenReview: true,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _odTint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _odLine),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_outline_rounded,
                                      size: 14,
                                      color: _odAccentDeep,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Write Review',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _odAccentDeep,
                                      ),
                                    ),
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

  Widget _premiumAdBanner(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumStore.instance,
      builder: (context, _) {
        final member = PremiumStore.instance.isMember;
        return Container(
          key: const ValueKey('details_ad_banner'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [OxroColors.premiumDeep, OxroColors.premiumWine],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OxroColors.premiumChampagne.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: OxroColors.premiumDeep.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -46,
                right: -28,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        OxroColors.premiumChampagne.withValues(alpha: 0.2),
                        OxroColors.premiumChampagne.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -16,
                bottom: -20,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 110,
                  color: OxroColors.premiumChampagne.withValues(alpha: 0.07),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) => CustomPaint(
                      painter: _OdShinePainter(
                        progress: value,
                        color: OxroColors.premiumChampagne,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: OxroColors.premiumChampagne.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'AD',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: OxroColors.premiumChampagne,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 15,
                          color: OxroColors.premiumChampagne,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'OXRO PREMIUM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                              color: OxroColors.premiumChampagne,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Dismiss ad',
                          child: PressScale(
                            key: const ValueKey('details_ad_dismiss'),
                            scale: 0.86,
                            onTap: _dismissAd,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: OxroColors.premiumCream.withValues(
                                  alpha: 0.86,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(
                      member ? 'PREMIUM ACTIVE' : 'FREE DELIVERY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1.05,
                        color: OxroColors.premiumCream,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      member
                          ? 'Free delivery is active on orders above ₹199.'
                          : 'On every order above ₹199.',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: OxroColors.premiumCream.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PressScale(
                      key: const ValueKey('details_ad_cta'),
                      onTap: _openPremium,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: OxroColors.premiumCream,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              member ? 'Manage PREMIUM' : 'Explore PREMIUM',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: OxroColors.premiumInk,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
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
        );
      },
    );
  }

  Widget _addressCard(BuildContext context) {
    return _card(
      key: const ValueKey('details_address'),
      context: context,
      padding: EdgeInsets.all(context.rs(13)),
      child: Row(
        children: [
          _iconChip(Icons.location_on_rounded, size: 38),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _odInk,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '123, Anna Nagar, Chennai — 600040',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: _odMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billCard(
    BuildContext context, {
    required OrderBill? bill,
    required int itemsTotalPaise,
    required int toPayPaise,
  }) {
    return _card(
      context: context,
      padding: EdgeInsets.fromLTRB(
        context.rs(14),
        context.rs(13),
        context.rs(14),
        context.rs(11),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BILL DETAILS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: _odMuted,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              PressScale(
                key: const ValueKey('details_invoice'),
                onTap: () {
                  _haptic();
                  pushScreen(context, InvoiceScreen(orderId: widget.orderId));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _odTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Invoice',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _odAccentDeep,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: _odAccentDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _billRow('Items Total', Money.inr(itemsTotalPaise)),
          if (bill != null) ...[
            if (bill.packagingPaise > 0)
              _billRow('Packaging', Money.inr(bill.packagingPaise)),
            _billRow(
              'Delivery Fee',
              bill.deliveryPaise == 0 ? 'FREE' : Money.inr(bill.deliveryPaise),
            ),
            if (bill.smallCartFeePaise > 0)
              _billRow(
                'Small Cart Fee',
                Money.inr(bill.smallCartFeePaise),
              ),
            _billRow(
              'Platform Fee',
              bill.platformFeePaise == 0
                  ? 'FREE'
                  : Money.inr(bill.platformFeePaise),
            ),
            _billRow('Taxes (5% GST)', Money.inr(bill.taxPaise)),
            if (bill.tipPaise > 0)
              _billRow('Delivery Tip', Money.inr(bill.tipPaise)),
            if (bill.discountPaise > 0)
              _billRow('Discount', '−${Money.inr(bill.discountPaise)}'),
          ] else
            _billRow('Delivery fee', Money.inr(4000)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _odLine),
          ),
          _billRow('Total Amount', Money.inr(toPayPaise), bold: true),
        ],
      ),
    );
  }

  Widget _card({
    required BuildContext context,
    required Widget child,
    Key? key,
    EdgeInsets? padding,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(context.rs(13)),
      decoration: BoxDecoration(
        color: _odSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _odLine),
        boxShadow: [
          BoxShadow(
            color: _odInk.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconChip(IconData icon, {double size = 36}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _odTint,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: _odLine),
      ),
      child: Icon(icon, size: size * 0.5, color: _odAccentDeep),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: bold ? _odInk : _odMuted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bold ? 15.5 : 12.5,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
                color: bold ? _odAccentDeep : _odInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OdShinePainter extends CustomPainter {
  const _OdShinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final band = size.width * 0.38;
    final x = -band * 1.4 + progress * (size.width + band * 2.4);
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x + band * 0.35, 0)
      ..lineTo(x + band * 0.55, size.height)
      ..lineTo(x + band * 0.2, size.height)
      ..close();
    final shader = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.16),
        color.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawPath(path, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _OdShinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
