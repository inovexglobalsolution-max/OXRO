import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/address/presentation/widgets/address_required_dialog.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_gateway.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/coupons/presentation/screens/coupons_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/widgets/schedule_sheet.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

// Warm-white checkout palette — orange is an accent, not a flood.
const _ckCanvas = Color(0xFFFFFBF6);
const _ckSurface = Colors.white;
const _ckInk = Color(0xFF102A43);
const _ckMuted = Color(0xFF62758A);
const _ckAccent = Color(0xFFFF6A00);
const _ckAccentDeep = Color(0xFFE85D00);
const _ckTint = Color(0xFFFFF1E6);
const _ckLine = Color(0xFFFFD9BE);

/// 15 Checkout — warm-white premium shell: orange stays an accent on the
/// CTA, selected states and key numbers. Collapsible payment methods,
/// cascading entrance, press-scale and an animated total.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _press;
  bool _placing = false;
  bool _paymentsOpen = true;
  Timer? _paymentsTimer;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _paymentsTimer?.cancel();
    _entry.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _togglePayments() {
    _paymentsTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _paymentsOpen = !_paymentsOpen);
  }

  void _selectMethod(PaymentMethod m) {
    HapticFeedback.selectionClick();
    PaymentStore.instance.select(m);
    setState(() {});
    _paymentsTimer?.cancel();
    _paymentsTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _paymentsOpen = false);
    });
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
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openOffers() async {
    final applied = await pushScreen<bool>(context, const CouponsScreen());
    if (!mounted || applied != true) return;
    setState(() {});
  }

  void _removeCoupon() {
    PaymentStore.instance.clearCoupon();
    setState(() {});
    showOxroSnack(context, 'Coupon removed');
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    // Empty-bag guard: never charge shipping on zero items.
    if (CartStore.instance.count == 0) {
      if (!mounted) return;
      showOxroSnack(context, 'Your bag is empty — add items first');
      return;
    }
    // Address guard: specific popup, then 14 screen on confirmation.
    final issue = AddressStore.instance.issue;
    if (issue != AddressIssue.none) {
      final go = await showAddressRequiredDialog(context, issue);
      if (!mounted) return;
      if (go) pushScreen(context, const AddressSelectionScreen());
      return;
    }
    setState(() => _placing = true);
    final method = PaymentStore.instance.method;
    final pay = PaymentStore.instance;
    if (method != PaymentMethod.cod && method != PaymentMethod.wallet) {
      final paid = await PaymentGateway.instance.charge(method, pay.toPayPaise);
      if (!paid) {
        if (!mounted) return;
        setState(() => _placing = false);
        await _showPaymentFailure();
        return;
      }
    }
    if (method == PaymentMethod.wallet && pay.toPayPaise > 0) {
      final ok = WalletStore.instance.deductPaise(
        pay.toPayPaise,
        label: 'Order payment',
      );
      if (!ok) {
        if (!mounted) return;
        setState(() => _placing = false);
        showOxroSnack(context, 'Insufficient wallet balance — top up');
        return;
      }
    }
    if (!mounted) return;
    final id = 'OXRO${DateTime.now().millisecondsSinceEpoch % 1000000}';
    // Snapshot items BEFORE clearing (qty-expanded for bill parity).
    final cart = CartStore.instance;
    final restaurantId = cart.restaurantId;
    final restaurantName = cart.restaurantName;
    final instructions = cart.instructions.isEmpty ? null : cart.instructions;
    final cutleryOptIn = cart.cutleryOptIn;
    final snapshot = [
      for (final l in cart.lines)
        for (var i = 0; i < l.qty; i++) l.product,
    ];
    final q = pay.quote;
    final bill = OrderBill(
      itemSubtotalPaise: q.itemSubtotalPaise,
      packagingPaise: q.packagingPaise,
      deliveryPaise: q.deliveryFeePaise,
      platformFeePaise: q.platformFeePaise,
      smallCartFeePaise: q.smallCartFeePaise,
      taxPaise: q.taxPaise,
      tipPaise: q.tipPaise,
      discountPaise: q.discountPaise,
      grandTotalPaise: q.grandTotalPaise,
      configVersion: q.configVersion,
    );
    OrderStore.instance.placeOrder(
      id: id,
      products: snapshot,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      instructions: instructions,
      cutleryOptIn: cutleryOptIn,
      bill: bill,
    );
    cart.clear();
    // Stale-coupon guard: next order starts with no promo.
    PaymentStore.instance.clearCoupon();
    PaymentStore.instance.setTipPaise(0);
    setState(() => _placing = false);
    replaceScreen(context, _PaymentResult(orderId: id));
  }

  Future<void> _showPaymentFailure() async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('payment_failed'),
        title: const Text('Payment failed'),
        content: const Text(
          'Your payment could not be completed. No money was deducted. '
          'Try again or choose another method.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('payment_change_method'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Change method'),
          ),
          FilledButton(
            key: const ValueKey('payment_retry'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
    if (retry == true && mounted) await _placeOrder();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, _ckCanvas],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      CartStore.instance,
                      AddressStore.instance,
                      PaymentStore.instance,
                      WalletStore.instance,
                      PricingConfigStore.instance,
                    ]),
                    builder: (context, _) {
                      final pay = PaymentStore.instance;
                      final addr = AddressStore.instance;
                      final quote = pay.quote;
                      final scheduled = [
                        for (final line in CartStore.instance.lines)
                          if (line.schedule != null) line,
                      ];
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: context.maxContentW,
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              context.padX,
                              2,
                              context.padX,
                              20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _in(0.15, _summaryCard(pay, quote)),
                                SizedBox(height: context.rs(12)),
                                _in(0.3, _addressCard(addr)),
                                if (scheduled.isNotEmpty) ...[
                                  SizedBox(height: context.rs(12)),
                                  _in(0.38, _scheduleCard(scheduled)),
                                ],
                                SizedBox(height: context.rs(12)),
                                _in(0.45, _paymentSection(pay)),
                                SizedBox(height: context.rs(12)),
                                _in(0.5, _tipCard(pay)),
                                SizedBox(height: context.rs(12)),
                                _in(0.55, _couponCard(pay)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _bottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return _in(
      0,
      Padding(
        padding: EdgeInsets.fromLTRB(
          context.rs(8),
          context.rs(20),
          context.padX,
          12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('checkout_back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: _ckSurface,
                    foregroundColor: _ckInk,
                    side: const BorderSide(color: _ckLine),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    key: const ValueKey('checkout_header'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SECURE CHECKOUT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: _ckAccentDeep,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Checkout',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(23),
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: _ckInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 26,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _ckAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: const ValueKey('checkout_secure_badge'),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rs(8),
                    vertical: context.rs(5),
                  ),
                  decoration: BoxDecoration(
                    color: _ckSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _ckLine),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 11,
                        color: _ckAccentDeep,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'SECURE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: _ckMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _progressRail(context),
          ],
        ),
      ),
    );
  }

  Widget _progressRail(BuildContext context) {
    return Container(
      key: const ValueKey('checkout_progress'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(14),
        vertical: context.rs(10),
      ),
      decoration: BoxDecoration(
        color: _ckSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ckLine),
      ),
      child: Row(
        children: [
          _progressStep('ADDRESS', Icons.check_rounded, done: true),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 0.6),
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(height: 4, color: _ckLine),
                      FractionallySizedBox(
                        widthFactor: t,
                        child: Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_ckAccent, OxroColors.orangeBottom],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          _progressStep('PAYMENT', Icons.lock_outline_rounded, active: true),
        ],
      ),
    );
  }

  Widget _progressStep(
    String label,
    IconData icon, {
    bool done = false,
    bool active = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.rs(18),
          height: context.rs(18),
          decoration: BoxDecoration(
            color: done
                ? _ckAccent.withValues(alpha: 0.12)
                : active
                ? _ckTint
                : _ckSurface,
            shape: BoxShape.circle,
            border: Border.all(color: done || active ? _ckAccent : _ckLine),
          ),
          child: Icon(
            icon,
            size: 11,
            color: done || active ? _ckAccentDeep : _ckMuted,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: done
                ? _ckMuted
                : active
                ? _ckInk
                : _ckMuted,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _ckTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: _ckAccentDeep),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: _ckInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({Key? key, required Widget child, EdgeInsets? padding}) {
    return Container(
      key: key,
      padding: padding ?? EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        color: _ckSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ckLine),
        boxShadow: [
          BoxShadow(
            color: _ckInk.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryCard(PaymentStore pay, OrderQuote quote) {
    final itemLabel =
        '${pay.itemsCount} ${pay.itemsCount == 1 ? 'ITEM' : 'ITEMS'}';
    final restaurant = RestaurantRepo.byId(
      CartStore.instance.restaurantId ?? '',
    );
    final distance = restaurant?.distanceLabel;
    final deliveryLabel = distance == null
        ? 'Delivery partner fee'
        : 'Delivery partner fee · $distance';
    final hasCoupon = quote.discountPaise > 0;
    final productSavings =
        CartStore.instance.totalMrp - CartStore.instance.totalPrice;
    return Container(
      key: const ValueKey('checkout_summary'),
      decoration: BoxDecoration(
        color: _ckSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ckLine),
        boxShadow: [
          BoxShadow(
            color: _ckInk.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.rs(15),
                context.rs(14),
                context.rs(15),
                context.rs(13),
              ),
              decoration: const BoxDecoration(color: _ckSurface),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: context.rs(36),
                        height: context.rs(36),
                        decoration: const BoxDecoration(
                          color: _ckTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: _ckAccentDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Bill Summary',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: _ckInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _ckTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          itemLabel,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: _ckAccentDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _billRow('Item total', Money.inr(quote.itemSubtotalPaise)),
                  if (productSavings > 0)
                    _billRow(
                      'Product discount',
                      '−${Money.inr(productSavings * 100)}',
                      note: 'Already applied to the item total.',
                      valueColor: OxroColors.green,
                    ),
                  if (quote.packagingPaise > 0)
                    _billRow(
                      'Restaurant packaging charges',
                      Money.inr(quote.packagingPaise),
                      note: 'This is decided & charged by the restaurant.',
                    ),
                  _billRow(
                    deliveryLabel,
                    quote.deliveryFeePaise == 0
                        ? 'FREE'
                        : Money.inr(quote.deliveryFeePaise),
                    note: 'Goes to them for their time and effort.',
                    valueColor: quote.deliveryFeePaise == 0
                        ? OxroColors.green
                        : null,
                  ),
                  _billRow(
                    'Small cart fee',
                    quote.smallCartFeePaise == 0
                        ? 'FREE'
                        : Money.inr(quote.smallCartFeePaise),
                    note: 'Waived on carts of ₹99 or more.',
                    valueColor: quote.smallCartFeePaise == 0
                        ? OxroColors.green
                        : null,
                  ),
                  if (quote.smallCartFeePaise > 0)
                    _smallCartFeeHint(quote.itemSubtotalPaise),
                  _billRow(
                    'Platform fee',
                    quote.platformFeePaise == 0
                        ? 'FREE'
                        : Money.inr(quote.platformFeePaise),
                    valueColor: quote.platformFeePaise == 0
                        ? OxroColors.green
                        : null,
                  ),
                  _billRow('GST (govt. taxes)', Money.inr(quote.taxPaise)),
                  if (quote.tipPaise > 0)
                    _billRow('Delivery partner tip', Money.inr(quote.tipPaise)),
                  if (hasCoupon)
                    _billRow(
                      'Coupon ${pay.coupon}',
                      '−${Money.inr(quote.discountPaise)}',
                      valueColor: OxroColors.green,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 1, color: _ckLine),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(
                context.rs(12),
                0,
                context.rs(12),
                context.rs(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(15),
                vertical: context.rs(13),
              ),
              decoration: const BoxDecoration(
                color: _ckInk,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'To pay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: quote.grandTotalPaise.toDouble(),
                        ),
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Text(
                            Money.inr(value.round()),
                            key: const ValueKey('checkout_total'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: OxroColors.orangeBottom,
                            ),
                          );
                        },
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

  Widget _scheduleCard(List<CartLine> lines) {
    return _surfaceCard(
      key: const ValueKey('checkout_schedules'),
      padding: EdgeInsets.fromLTRB(
        context.rs(14),
        context.rs(12),
        context.rs(10),
        context.rs(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.rs(30),
                height: context.rs(30),
                decoration: const BoxDecoration(
                  color: _ckTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: _ckAccentDeep,
                ),
              ),
              SizedBox(width: context.rs(9)),
              const Expanded(
                child: Text(
                  'Scheduled items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                    color: _ckInk,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(2)),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: _ckLine.withValues(alpha: 0.65),
              ),
            _scheduleRow(lines[i]),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(CartLine line) {
    final p = line.product;
    final sfx = line.size == null ? '' : '_${line.size}';
    final schedule = line.schedule!;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('checkout_schedule_${p.id}$sfx'),
        onTap: () => _editSchedule(line),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.rs(7)),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: _ckAccentDeep,
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _ckInk,
                            ),
                          ),
                        ),
                        if (line.qty > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '×${line.qty}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _ckMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (line.size != null)
                      Text(
                        '${p.restaurantId == null ? 'Size' : 'Choice'}: ${line.size}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.8,
                          fontWeight: FontWeight.w600,
                          color: _ckMuted,
                        ),
                      ),
                    Text(
                      schedule.chipLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.3,
                        fontWeight: FontWeight.w800,
                        color: _ckAccentDeep,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rs(4)),
              GestureDetector(
                key: ValueKey('checkout_schedule_clear_${p.id}$sfx'),
                onTap: () => CartStore.instance.setSchedule(
                  p.id,
                  size: line.size,
                  schedule: null,
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(context.rs(4)),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: _ckMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSchedule(CartLine line) async {
    final picked = await showScheduleSheet(context, initial: line.schedule);
    if (picked == null || !mounted) return;
    CartStore.instance.setSchedule(
      line.product.id,
      size: line.size,
      schedule: picked,
    );
  }

  Widget _addressCard(AddressStore addr) {
    final lines = addr.displayLine.split('\n');
    final title = lines.isNotEmpty ? lines.first : '';
    final subtitle = lines.length > 1 ? lines.skip(1).join(' ') : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DELIVER TO', icon: Icons.location_on_outlined),
        GestureDetector(
          key: const ValueKey('checkout_addr_row'),
          onTap: () async {
            pushScreen(context, const AddressSelectionScreen());
          },
          behavior: HitTestBehavior.opaque,
          child: _surfaceCard(
            padding: EdgeInsets.all(context.rs(13)),
            child: Row(
              children: [
                Container(
                  width: context.rs(42),
                  height: context.rs(42),
                  decoration: const BoxDecoration(
                    color: _ckTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: _ckAccentDeep,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addr.hasValid ? title : 'Add delivery address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(13),
                          fontWeight: FontWeight.w800,
                          color: _ckInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        addr.hasValid
                            ? subtitle
                            : 'Tap to choose where we deliver',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: OxroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: context.rs(30),
                  height: context.rs(30),
                  decoration: BoxDecoration(
                    color: _ckTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    addr.hasValid
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    size: 17,
                    color: _ckAccentDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentSection(PaymentStore pay) {
    final open = _paymentsOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('payment_toggle_row'),
          onTap: _togglePayments,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _surfaceCard(
              padding: EdgeInsets.all(context.rs(13)),
              child: Row(
                children: [
                  Container(
                    width: context.rs(36),
                    height: context.rs(36),
                    decoration: const BoxDecoration(
                      color: _ckTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: _ckAccentDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'PAYMENT METHOD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: _ckInk,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _ckTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      paymentLabels[pay.method]!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: _ckAccentDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    expanded: open,
                    label: open
                        ? 'Hide payment methods'
                        : 'Show payment methods',
                    child: AnimatedRotation(
                      key: const ValueKey('payment_toggle'),
                      turns: open ? 0.5 : 0,
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _ckTint,
                          shape: BoxShape.circle,
                          border: Border.all(color: open ? _ckAccent : _ckLine),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: _ckAccentDeep,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    children: [
                      for (final m in PaymentMethod.values)
                        _payCard(m, pay.method == m, () => _selectMethod(m)),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  Widget _couponCard(PaymentStore pay) {
    final applied = pay.coupon.isNotEmpty;
    final saved = pay.discount;
    final benefit = saved > 0
        ? 'You save ${Money.inr(saved * 100)}'
        : pay.freeShip
        ? 'Free delivery applied'
        : 'Not eligible for this cart';
    return _surfaceCard(
      key: const ValueKey('checkout_offers_card'),
      padding: EdgeInsets.all(context.rs(13)),
      child: Column(
        children: [
          GestureDetector(
            key: const ValueKey('coupon_offers_link'),
            onTap: _openOffers,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: context.rs(36),
                  height: context.rs(36),
                  decoration: const BoxDecoration(
                    color: _ckTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    size: 17,
                    color: _ckAccentDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'View all offers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: _ckInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        applied
                            ? 'Swap or explore more savings'
                            : 'Tap to see coupons for this order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OxroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _ckAccentDeep.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: applied
                ? Column(
                    children: [
                      const SizedBox(height: 11),
                      Container(
                        key: const ValueKey('checkout_applied_coupon'),
                        padding: EdgeInsets.fromLTRB(
                          context.rs(10),
                          context.rs(8),
                          context.rs(8),
                          context.rs(8),
                        ),
                        decoration: BoxDecoration(
                          color: _ckTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _ckLine),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 17,
                              color: _ckAccentDeep,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Coupon ${pay.coupon}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: _ckAccentDeep,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    benefit,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: saved > 0 || pay.freeShip
                                          ? OxroColors.green
                                          : OxroColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              key: const ValueKey('checkout_coupon_remove'),
                              onTap: _removeCoupon,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: context.rs(28),
                                height: context.rs(28),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _ckSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _ckLine),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: context.rs(15),
                                  color: _ckAccentDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return _in(
      0.7,
      Container(
        padding: EdgeInsets.fromLTRB(
          context.padX,
          context.rs(9),
          context.padX,
          context.rs(9),
        ),
        decoration: BoxDecoration(
          color: _ckSurface,
          border: const Border(top: BorderSide(color: _ckLine)),
          boxShadow: [
            BoxShadow(
              color: _ckInk.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: PaymentStore.instance,
                  builder: (context, _) {
                    final pay = PaymentStore.instance;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'To Pay',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: _ckMuted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              Money.inr(pay.toPayPaise),
                              key: ValueKey('checkout_bar_${pay.toPayPaise}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font(20),
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: _ckInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('checkout_place_order'),
                  onTapDown: (_) => _press.value = 0.96,
                  onTapUp: (_) => _press.value = 1.0,
                  onTapCancel: () => _press.value = 1.0,
                  onTap: () {
                    _press.value = 1.0;
                    HapticFeedback.mediumImpact();
                    _placeOrder();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ScaleTransition(
                    scale: _press,
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(10),
                        vertical: context.rs(14),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_ckAccent, OxroColors.orangeBottom],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _ckAccent.withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: _placing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Place Order',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: context.font(13.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipCard(PaymentStore pay) {
    const presets = [0, 20, 30, 50];
    final custom = !presets.contains(pay.tip);
    return _surfaceCard(
      key: const ValueKey('checkout_tip_card'),
      padding: EdgeInsets.all(context.rs(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'GRATITUDE CORNER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _ckAccentDeep,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _ckTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'OPTIONAL',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: _ckAccentDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tip your delivery partner',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ckInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "They'll get notified instantly. The full tip is "
                      'sent after delivery.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: _ckMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: context.rs(6)),
                child: const _GratitudeArt(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            children: [
              for (final r in presets)
                _tipChip(
                  key: ValueKey('tip_$r'),
                  label: r == 0 ? 'No tip' : '₹$r',
                  selected: pay.tip == r,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    pay.setTipPaise(r * 100);
                    setState(() {});
                  },
                ),
              _tipChip(
                key: const ValueKey('tip_other'),
                label: custom ? '₹${pay.tip}' : 'Other',
                selected: custom,
                onTap: () => _openCustomTip(pay),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomTip(PaymentStore pay) async {
    const presets = [0, 20, 30, 50];
    final initial = presets.contains(pay.tip) ? 0 : pay.tip;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _CustomTipDialog(initial: initial),
    );
    if (amount == null || !mounted) return;
    HapticFeedback.selectionClick();
    pay.setTipPaise(amount * 100);
    setState(() {});
  }

  Widget _tipChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_ckAccent, OxroColors.orangeBottom],
                )
              : null,
          color: selected ? null : _ckSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _ckAccent : _ckLine),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _ckInk,
          ),
        ),
      ),
    );
  }

  Widget _smallCartFeeHint(int itemSubtotalPaise) {
    final remaining = PricingEngine.smallCartFeeWaiverRemainingPaise(
      itemSubtotalPaise,
    );
    if (remaining <= 0) return const SizedBox.shrink();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      key: const ValueKey('checkout_smallcart_hint'),
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.local_offer_outlined,
              size: 13,
              color: _ckAccentDeep,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: Text(
                'Add ${Money.inr(remaining)} more to remove the small cart fee!',
                key: ValueKey('checkout_smallcart_hint_$remaining'),
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: _ckAccentDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(
    String label,
    String value, {
    String? note,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _ckInk,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.3,
                      color: _ckMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _ckInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _payCard(PaymentMethod m, bool sel, VoidCallback onTap) {
    final icons = {
      PaymentMethod.upi: Icons.smartphone_outlined,
      PaymentMethod.card: Icons.credit_card_outlined,
      PaymentMethod.wallet: Icons.account_balance_wallet_outlined,
      PaymentMethod.cod: Icons.payments_outlined,
    };
    final sub = m == PaymentMethod.wallet
        ? 'Balance ${Product.inr(WalletStore.instance.balance)}'
        : paymentSubs[m]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        key: ValueKey('pay_${m.name}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(context.rs(12)),
          decoration: BoxDecoration(
            color: sel ? _ckTint : _ckSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sel ? _ckAccent : _ckLine,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: _ckAccent.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: context.rs(40),
                height: context.rs(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_ckAccent, OxroColors.orangeBottom],
                        )
                      : null,
                  color: sel ? null : _ckTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icons[m],
                  size: 20,
                  color: sel ? Colors.white : _ckAccentDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentLabels[m]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _ckInk,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _ckMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  sel ? Icons.radio_button_checked : Icons.radio_button_off,
                  key: ValueKey(sel),
                  color: sel ? _ckAccent : _ckMuted.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 16 Payment Result — premium burst: elastic pop + expanding rings +
/// hand-drawn tick + confetti + staggered text/buttons (ref 16 1:1).
class _PaymentResult extends StatefulWidget {
  const _PaymentResult({required this.orderId});

  final String orderId;

  @override
  State<_PaymentResult> createState() => _PaymentResultState();
}

class _PaymentResultState extends State<_PaymentResult>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _ambient;
  late final Animation<double> _pop;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _tick;
  late final Animation<double> _confetti;
  late final Animation<double> _confetti2;
  late final Animation<double> _text;
  late final Animation<double> _shine;
  late final Animation<Offset> _btnSlide;
  Timer? _auto;
  bool _moved = false;

  static const _confettiColors = [
    OxroColors.primary,
    OxroColors.royalBlue,
    Colors.green,
    Color(0xFFFFC107),
    Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );
    _ring1 = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    );
    _ring2 = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
    );
    _tick = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
    );
    _confetti = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _confetti2 = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _shine = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _text = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
    );
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _c,
            curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    // Splash-style: 2s only, then auto → live tracking.
    _auto = Timer(const Duration(milliseconds: 2000), _openTracking);
  }

  void _openTracking() {
    if (_moved || !mounted) return;
    _moved = true;
    // Keep only the app root + tracking: back from tracking must not
    // land on this auto-advancing splash or the checkout/address flow.
    Navigator.of(context).pushAndRemoveUntil(
      OxroPageRoute(builder: (_) => TrackingScreen(orderId: widget.orderId)),
      (route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _auto?.cancel();
    _c.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) =>
                    CustomPaint(painter: _ResultBgPainter(_ambient.value)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.padX + 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      key: const ValueKey('payment_success_tick'),
                      animation: _c,
                      builder: (context, _) {
                        final circle = context.rs(96);
                        return SizedBox(
                          width: circle + 130,
                          height: circle + 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: circle + 44,
                                height: circle + 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              _ring(96 + 90 * _ring1.value, 1 - _ring1.value),
                              _ring(96 + 90 * _ring2.value, 1 - _ring2.value),
                              for (var i = 0; i < 22; i++)
                                _dot(i, _confetti.value, wide: true),
                              for (var i = 0; i < 10; i++)
                                _dot(
                                  i + 100,
                                  _confetti2.value * 0.9,
                                  wide: false,
                                ),
                              Transform.scale(
                                scale: _pop.value.clamp(0.01, 1.4),
                                child: Container(
                                  width: circle,
                                  height: circle,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x5566BB6A),
                                        blurRadius: 30,
                                        offset: Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              CustomPaint(
                                size: Size.square(context.rs(52)),
                                painter: _CheckPainter(_tick.value),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    FadeTransition(
                      opacity: _text,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(_text),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Payment Successful!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _text,
                              builder: (context, _) => Container(
                                height: 4,
                                width: 64 * _text.value,
                                decoration: BoxDecoration(
                                  gradient: OxroColors.gradient,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: OxroColors.pageBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: OxroColors.border),
                              ),
                              child: Text(
                                'Order ID: ${widget.orderId}',
                                key: const ValueKey('payment_order_id'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: OxroColors.charcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SlideTransition(
                      position: _btnSlide,
                      child: FadeTransition(
                        opacity: _text,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Auto-advance progress (2s splash feel).
                            TweenAnimationBuilder<double>(
                              key: const ValueKey('result_auto_bar'),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 2000),
                              curve: Curves.linear,
                              builder: (context, v, _) => Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: OxroColors.border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: v,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: OxroColors.gradient,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ShineBtn(
                              key: const ValueKey('result_track'),
                              label: 'Track Order',
                              shine: _shine,
                              onTap: () {
                                _auto?.cancel();
                                _openTracking();
                              },
                            ),
                          ],
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

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.5 * opacity),
          width: 3,
        ),
      ),
    );
  }

  Widget _dot(int i, double t, {required bool wide}) {
    final n = wide ? 22 : 10;
    final angle = (i / n) * math.pi * 2 + (wide ? 0.3 : 0.6);
    final dist = (wide ? 62 : 46) + (wide ? 70 : 50) * t;
    final color = _confettiColors[i % _confettiColors.length];
    return Positioned(
      left: 115 + dist * math.cos(angle) - 5,
      top: 115 + dist * math.sin(angle) - 5,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Container(
          width: 10 - (i % 3) * 2,
          height: 10 - (i % 3) * 2,
          decoration: BoxDecoration(
            color: color,
            shape: i.isEven ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: i.isEven ? null : BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Draws the check stroke progressively (0..1).
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.30);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var drawn = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (drawn <= 0) break;
      final len = math.min(drawn, m.length);
      canvas.drawPath(m.extractPath(0, len), paint);
      drawn -= len;
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

/// Press-scale solid primary button with shine sweep.
class _ShineBtn extends StatefulWidget {
  const _ShineBtn({
    super.key,
    required this.label,
    required this.shine,
    required this.onTap,
  });

  final String label;
  final Animation<double> shine;
  final VoidCallback onTap;

  @override
  State<_ShineBtn> createState() => _ShineBtnState();
}

class _ShineBtnState extends State<_ShineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.value = 0.96,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: () {
        _press.value = 1.0;
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedBuilder(
          animation: widget.shine,
          builder: (context, _) => Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: OxroColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40051D47),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Transform.translate(
                      offset: Offset(-220 + 440 * widget.shine.value, 0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 46,
                          color: Colors.white.withValues(
                            alpha: 0.30 * (1 - widget.shine.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient bg for 16 (pairs with 17): peach glow + dot grid +
/// navy wave.
class _ResultBgPainter extends CustomPainter {
  _ResultBgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = Colors.green.withValues(alpha: 0.08 + 0.02 * t);
    canvas.drawCircle(Offset(size.width * 0.5, 120), 150, glow);
    final dot = Paint()..color = OxroColors.royalBlue.withValues(alpha: 0.10);
    for (double x = 16; x < size.width; x += 26) {
      for (double y = 190; y < 300; y += 26) {
        canvas.drawCircle(Offset(x, y + 4 * t), 1.6, dot);
      }
    }
    final wave = Paint()..color = OxroColors.navyDark.withValues(alpha: 0.05);
    final path = Path()
      ..moveTo(0, size.height - 90)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height - 110 - 8 * t,
        size.width,
        size.height - 90,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant _ResultBgPainter old) => old.t != t;
}

class _CustomTipDialog extends StatefulWidget {
  const _CustomTipDialog({required this.initial});

  /// Pre-filled amount in rupees; 0 starts empty.
  final int initial;

  @override
  State<_CustomTipDialog> createState() => _CustomTipDialogState();
}

class _CustomTipDialogState extends State<_CustomTipDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial > 0 ? '${widget.initial}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final value = int.tryParse(_controller.text.trim()) ?? 0;
    if (value < 1 || value > 2000) {
      setState(() => _error = 'Enter an amount between ₹1 and ₹2000');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('tip_custom_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _ckSurface,
      title: const Text(
        'Add a tip',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _ckInk,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '100% of your tip goes to the delivery partner.',
            style: TextStyle(fontSize: 12, color: _ckMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('tip_custom_field'),
            controller: _controller,
            autofocus: true,
            cursorColor: _ckAccent,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: 'Enter amount',
              errorText: _error,
              filled: true,
              fillColor: _ckTint,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ckLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ckAccent, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _apply(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('tip_custom_clear'),
          style: TextButton.styleFrom(foregroundColor: _ckMuted),
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('No tip'),
        ),
        FilledButton(
          key: const ValueKey('tip_custom_apply'),
          style: FilledButton.styleFrom(
            backgroundColor: _ckAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _apply,
          child: const Text('Add tip'),
        ),
      ],
    );
  }
}

class _GratitudeArt extends StatefulWidget {
  const _GratitudeArt();

  @override
  State<_GratitudeArt> createState() => _GratitudeArtState();
}

class _GratitudeArtState extends State<_GratitudeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
      _idle.value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(context.rs(14));
    return Semantics(
      image: true,
      label: 'Delivery partner illustration',
      child: RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('gratitude_art'),
          width: context.rs(74),
          height: context.rs(90),
          child: AnimatedBuilder(
            animation: _idle,
            builder: (context, child) {
              final wave = reduceMotion
                  ? 0.0
                  : math.sin(_idle.value * math.pi * 2);
              final glow = reduceMotion
                  ? 0.18
                  : 0.12 + 0.06 * (0.5 + 0.5 * wave);
              return Transform.translate(
                offset: Offset(0, -2.2 * wave),
                child: Transform.scale(
                  scale: 1.006 + 0.006 * wave,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: _ckAccent.withValues(alpha: glow),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/delivery_boy_icon.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                  if (!reduceMotion)
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _SheenPainter(progress: _idle),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft diagonal light sweep, visible for a short slice of each idle loop.
class _SheenPainter extends CustomPainter {
  _SheenPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = ((progress.value - 0.55) / 0.30).clamp(0.0, 1.0);
    if (phase <= 0 || phase >= 1) return;
    final alpha = math.sin(phase * math.pi) * 0.16;
    if (alpha <= 0.001) return;

    final transparent = Colors.white.withValues(alpha: 0);
    final highlight = Colors.white.withValues(alpha: alpha);
    final p = phase;
    final stops = <double>[
      0,
      (p - 0.18).clamp(0.0, 1.0),
      p,
      (p + 0.18).clamp(0.0, 1.0),
      1,
    ];
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [transparent, transparent, highlight, transparent, transparent],
        stops: stops,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) => false;
}
