import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/order_success_screen.dart';
import 'package:oxro/features/coupons/presentation/screens/coupons_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

/// 15 Checkout — premium: steps pill + summary + address + payment
/// radios + coupon + sticky Place Order. Cascading entrance,
/// press-scale, AnimatedSwitcher totals.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _press;
  final _couponCtrl = TextEditingController();
  bool _placing = false;

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
    _entry.dispose();
    _press.dispose();
    _couponCtrl.dispose();
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

  void _applyCoupon() {
    final ok = PaymentStore.instance
        .applyCoupon(_couponCtrl.text);
    if (!mounted) return;
    final pay = PaymentStore.instance;
    showOxroSnack(
        context,
        ok
            ? 'Coupon ${pay.coupon} applied'
            : 'Invalid coupon — tap View all offers');
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    // Empty-bag guard: never charge shipping on zero items.
    if (CartStore.instance.count == 0) {
      if (!context.mounted) return;
      showOxroSnack(context, 'Your bag is empty — add items first');
      return;
    }
    // Address guard: block + popup, go to 14 screen.
    if (!AddressStore.instance.hasValid) {
      if (!context.mounted) return;
      showOxroSnack(
          context, 'First fill your address');
      pushScreen(
          context, const AddressSelectionScreen());
      return;
    }
    setState(() => _placing = true);
    final method = PaymentStore.instance.method;
    final pay = PaymentStore.instance;
    if (method == PaymentMethod.wallet && pay.toPay > 0) {
      final ok = WalletStore.instance
          .deduct(pay.toPay, label: 'Order payment');
      if (!ok) {
        if (!context.mounted) return;
        setState(() => _placing = false);
        showOxroSnack(context, 'Insufficient wallet balance — top up');
        return;
      }
    } else if (method != PaymentMethod.cod) {
      // Mock gateway (Razorpay TODO with live keys).
      await Future.delayed(
          const Duration(milliseconds: 1000));
    }
    if (!context.mounted) return;
    final id =
        'OXRO${DateTime.now().millisecondsSinceEpoch % 1000000}';
    // Snapshot items BEFORE clearing (qty-expanded for bill parity).
    final snapshot = [
      for (final l in CartStore.instance.lines)
        for (var i = 0; i < l.qty; i++) l.product,
    ];
    OrderStore.instance
        .placeOrder(id: id, products: snapshot);
    CartStore.instance.clear();
    // Stale-coupon guard: next order starts with no promo.
    PaymentStore.instance.clearCoupon();
    setState(() => _placing = false);
    replaceScreen(context, _PaymentResult(orderId: id));
  }

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
                  Expanded(
                    child: Text('Checkout',
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
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.padX),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: OxroColors.pageBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: OxroColors.border),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Address',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Divider(height: 1)),
                    SizedBox(width: 8),
                    Icon(Icons.payments_outlined,
                        size: 16,
                        color: OxroColors.primary),
                    SizedBox(width: 6),
                    Text('Payment',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.primary)),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rs(10)),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  CartStore.instance,
                  AddressStore.instance,
                  PaymentStore.instance,
                  WalletStore.instance,
                ]),
                builder: (context, _) {
                  final cart = CartStore.instance;
                  final pay = PaymentStore.instance;
                  final addr = AddressStore.instance;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                        context.padX, 4, context.padX, 16),
                    children: [
                      _in(
                        0.15,
                        Container(
                          key: const ValueKey(
                              'checkout_summary'),
                          padding: EdgeInsets.all(
                              context.rs(14)),
                          decoration: BoxDecoration(
                            color: OxroColors.pageBg,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                                color: OxroColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('ORDER SUMMARY',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: OxroColors.muted,
                                      letterSpacing: 1.1)),
                              const SizedBox(height: 10),
                              _row('Items (${cart.count})',
                                  Product.inr(
                                      cart.totalPrice)),
                              const SizedBox(height: 6),
                              _row('Shipping Fee',
                                  Product.inr(
                                      PaymentStore
                                          .shippingFee)),
                              const SizedBox(height: 6),
                              _row(
                                  pay.discount > 0
                                      ? 'Coupon ${pay.coupon}'
                                      : 'Coupon Discount',
                                  pay.discount > 0
                                      ? '−${Product.inr(pay.discount)}'
                                      : '—',
                                  valueColor:
                                      pay.discount > 0
                                          ? Colors.green
                                          : null),
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                        vertical: 10),
                                child: Divider(
                                    height: 1,
                                    color:
                                        OxroColors.border),
                              ),
                              Row(
                                children: [
                                  const Text('Total Amount',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .w800)),
                                  const Spacer(),
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(
                                            milliseconds:
                                                200),
                                    child: Text(
                                      Product.inr(
                                          pay.toPay),
                                      key: ValueKey(
                                          'checkout_total_${pay.toPay}'),
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color: OxroColors
                                              .primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: context.rs(10)),
                      _in(
                        0.3,
                        GestureDetector(
                          key: const ValueKey(
                              'checkout_addr_row'),
                          onTap: () async {
                            pushScreen(
                                context,
                                const AddressSelectionScreen());
                          },
                          behavior:
                              HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(
                                context.rs(12)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(
                                      14),
                              border: Border.all(
                                  color: addr.hasValid
                                      ? Colors.green
                                      : OxroColors.border,
                                  width: addr.hasValid
                                      ? 1.5
                                      : 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment:
                                      Alignment.center,
                                  decoration:
                                      BoxDecoration(
                                    color: OxroColors
                                        .royalBlue
                                        .withValues(
                                            alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons
                                          .location_on_outlined,
                                      size: 20,
                                      color: OxroColors
                                          .royalBlue),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: addr.hasValid
                                      ? Text(
                                          addr.displayLine,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight
                                                      .w600))
                                      : const Text(
                                          'Add delivery address',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight
                                                      .w700)),
                                ),
                                const Icon(
                                    Icons.chevron_right,
                                    color:
                                        OxroColors.muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: context.rs(10)),
                      _in(
                        0.45,
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'PAYMENT METHOD',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        OxroColors.muted,
                                    letterSpacing: 1.1)),
                            const SizedBox(height: 8),
                            for (final m
                                in PaymentMethod.values)
                              _payCard(m,
                                  pay.method == m, () {
                                pay.select(m);
                                setState(() {});
                              }),
                          ],
                        ),
                      ),
                      SizedBox(height: context.rs(10)),
                      _in(
                        0.55,
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              key: const ValueKey(
                                  'coupon_offers_link'),
                              onTap: () async {
                                final applied =
                                    await pushScreen<bool>(
                                  context,
                                  const CouponsScreen(),
                                );
                                if (!mounted) return;
                                if (applied == true) {
                                  _couponCtrl.text =
                                      PaymentStore.instance
                                          .coupon;
                                  setState(() {});
                                }
                              },
                              behavior:
                                  HitTestBehavior.opaque,
                              child: const Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                      Icons
                                          .local_offer_outlined,
                                      size: 15,
                                      color: OxroColors
                                          .primary),
                                  SizedBox(width: 6),
                                  Text(
                                      'View all offers',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color: OxroColors
                                              .primary)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                        'coupon_field'),
                                controller: _couponCtrl,
                                textCapitalization:
                                    TextCapitalization
                                        .characters,
                                textInputAction:
                                    TextInputAction.done,
                                onSubmitted: (_) =>
                                    _applyCoupon(),
                                decoration: InputDecoration(
                                  hintText:
                                      'Coupon (try OXRO500)',
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal: 12,
                                          vertical: 12),
                                  border:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    borderSide:
                                        const BorderSide(
                                            color: OxroColors
                                                .border),
                                  ),
                                  enabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    borderSide:
                                        const BorderSide(
                                            color: OxroColors
                                                .border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              key: const ValueKey(
                                  'coupon_apply'),
                              onTap: _applyCoupon,
                              behavior: HitTestBehavior
                                  .opaque,
                              child: Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 18,
                                        vertical: 13),
                                decoration: BoxDecoration(
                                  color: OxroColors
                                      .royalBlue,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                                child: const Text('Apply',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight
                                                .w800)),
                              ),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: _entry,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(
                  ((_entry.value - 0.7) / 0.3)
                      .clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - t)),
                    child: SafeArea(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                            context.padX, 8,
                            context.padX, 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              top: BorderSide(
                                  color: OxroColors
                                      .border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: PaymentStore
                                    .instance,
                                builder: (context, _) {
                                  final pay =
                                      PaymentStore
                                          .instance;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      const Text('To Pay',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: OxroColors
                                                  .muted,
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(
                                                milliseconds:
                                                    200),
                                        child: Text(
                                          Product.inr(
                                              pay.toPay),
                                          key: ValueKey(
                                              'bar_${pay.toPay}'),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                                  fontSize:
                                                      17,
                                                  fontWeight:
                                                      FontWeight
                                                          .w800),
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
                                key: const ValueKey(
                                    'checkout_place_order'),
                                onTapDown: (_) =>
                                    _press.value = 0.96,
                                onTapUp: (_) =>
                                    _press.value = 1.0,
                                onTapCancel: () =>
                                    _press.value = 1.0,
                                onTap: () {
                                  _press.value = 1.0;
                                  _placeOrder();
                                },
                                behavior: HitTestBehavior
                                    .opaque,
                                child: ScaleTransition(
                                  scale: _press,
                                  child: Container(
                                    alignment:
                                        Alignment.center,
                                    padding: const EdgeInsets
                                        .symmetric(
                                        vertical: 13),
                                    decoration: BoxDecoration(
                                      color:
                                          OxroColors.primary,
                                      borderRadius:
                                          BorderRadius.circular(
                                              12),
                                    ),
                                    child: _placing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2.5,
                                              color: Colors
                                                  .white,
                                            ),
                                          )
                                        : const Text(
                                            'Place Order',
                                            style: TextStyle(
                                                color: Colors
                                                    .white,
                                                fontWeight:
                                                    FontWeight
                                                        .w800,
                                                fontSize:
                                                    14)),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: OxroColors.muted)),
        const Spacer(),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ??
                      OxroColors.charcoal)),
        ),
      ],
    );
  }

  Widget _payCard(
      PaymentMethod m, bool sel, VoidCallback onTap) {
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
        child: AnimatedScale(
          scale: sel ? 1.02 : 1.0,
          duration:
              const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel
                  ? OxroColors.primary
                      .withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel
                    ? OxroColors.primary
                    : OxroColors.border,
                width: sel ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel
                        ? OxroColors.primary
                        : OxroColors.royalBlue
                            .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icons[m],
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(paymentLabels[m]!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(sub,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: OxroColors.muted)),
                    ],
                  ),
                ),
                Icon(
                    sel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: sel
                        ? OxroColors.primary
                        : OxroColors.muted),
              ],
            ),
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
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut));
    _ring1 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut));
    _ring2 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut));
    _tick = CurvedAnimation(
        parent: _c,
        curve:
            const Interval(0.35, 0.7, curve: Curves.easeOutCubic));
    _confetti = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut));
    _confetti2 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut));
    _shine = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut));
    _text = CurvedAnimation(
        parent: _c,
        curve:
            const Interval(0.5, 0.8, curve: Curves.easeOutCubic));
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _c,
        curve:
            const Interval(0.6, 0.9, curve: Curves.easeOutCubic)));
    // Splash-style: 2s only, then auto → 17 Order Placed.
    _auto = Timer(const Duration(milliseconds: 2000), _go17);
  }

  void _go17() {
    if (_moved || !mounted) return;
    _moved = true;
    // Replace (not push): back from Success must not land
    // on this auto-advancing result screen again.
    replaceScreen(
        context, OrderSuccessScreen(orderId: widget.orderId));
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
                builder: (context, _) => CustomPaint(
                  painter: _ResultBgPainter(
                      _ambient.value),
                ),
              ),
            ),
            Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.padX + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  key: const ValueKey(
                      'payment_success_tick'),
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
                              color: Colors.green
                                  .withValues(
                                      alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                          ),
                          _ring(96 + 90 * _ring1.value,
                              1 - _ring1.value),
                          _ring(96 + 90 * _ring2.value,
                              1 - _ring2.value),
                          for (var i = 0; i < 22; i++)
                            _dot(i, _confetti.value,
                                wide: true),
                          for (var i = 0; i < 10; i++)
                            _dot(i + 100,
                                _confetti2.value * 0.9,
                                wide: false),
                          Transform.scale(
                            scale: _pop.value
                                .clamp(0.01, 1.4),
                            child: Container(
                              width: circle,
                              height: circle,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Color(0x5566BB6A),
                                    blurRadius: 30,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: Size.square(
                                context.rs(52)),
                            painter: _CheckPainter(
                                _tick.value),
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
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    OxroColors.charcoal)),
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _text,
                          builder: (context, _) =>
                              Container(
                            height: 4,
                            width: 64 * _text.value,
                            decoration: BoxDecoration(
                              gradient:
                                  OxroColors.gradient,
                              borderRadius:
                                  BorderRadius.circular(
                                      2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6),
                          decoration: BoxDecoration(
                            color: OxroColors.pageBg,
                            borderRadius:
                                BorderRadius.circular(
                                    16),
                            border: Border.all(
                                color:
                                    OxroColors.border),
                          ),
                          child: Text(
                              'Order ID: ${widget.orderId}',
                              key: const ValueKey(
                                  'payment_order_id'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: OxroColors
                                      .charcoal)),
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
                        TweenAnimationBuilder<
                            double>(
                          key: const ValueKey(
                              'result_auto_bar'),
                          tween: Tween(
                              begin: 0.0, end: 1.0),
                          duration: const Duration(
                              milliseconds: 2000),
                          curve: Curves.linear,
                          builder: (context, v, _) =>
                              Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: OxroColors.border,
                              borderRadius:
                                  BorderRadius.circular(
                                      2),
                            ),
                            child: Align(
                              alignment:
                                  Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: v,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: OxroColors
                                        .gradient,
                                    borderRadius:
                                        BorderRadius
                                            .circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ShineBtn(
                          key: const ValueKey(
                              'result_continue'),
                          label: 'Continue Shopping',
                          shine: _shine,
                          onTap: () {
                            _auto?.cancel();
                            _go17();
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
          color: Colors.green
              .withValues(alpha: 0.5 * opacity),
          width: 3,
        ),
      ),
    );
  }

  Widget _dot(int i, double t,
      {required bool wide}) {
    final n = wide ? 22 : 10;
    final angle =
        (i / n) * math.pi * 2 + (wide ? 0.3 : 0.6);
    final dist =
        (wide ? 62 : 46) + (wide ? 70 : 50) * t;
    final color =
        _confettiColors[i % _confettiColors.length];
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
            shape: i.isEven
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: i.isEven
                ? null
                : BorderRadius.circular(2),
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
    final total =
        metrics.fold<double>(0, (s, m) => s + m.length);
    var drawn = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (drawn <= 0) break;
      final len = math.min(drawn, m.length);
      canvas.drawPath(m.extractPath(0, len), paint);
      drawn -= len;
    }
  }

  @override
  bool shouldRepaint(
          covariant _CheckPainter old) =>
      old.progress != progress;
}

/// Press-scale solid primary button with shine sweep.
class _ShineBtn extends StatefulWidget {
  const _ShineBtn(
      {super.key,
      required this.label,
      required this.shine,
      required this.onTap});

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
            padding: const EdgeInsets.symmetric(
                vertical: 14),
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
                Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Transform.translate(
                      offset: Offset(
                          -220 +
                              440 *
                                  widget.shine.value,
                          0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 46,
                          color: Colors.white
                              .withValues(
                                  alpha: 0.30 *
                                      (1 -
                                          widget.shine
                                              .value)),
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
      ..color = Colors.green
          .withValues(alpha: 0.08 + 0.02 * t);
    canvas.drawCircle(
        Offset(size.width * 0.5, 120), 150, glow);
    final dot = Paint()
      ..color = OxroColors.royalBlue
          .withValues(alpha: 0.10);
    for (double x = 16; x < size.width; x += 26) {
      for (double y = 190; y < 300; y += 26) {
        canvas.drawCircle(
            Offset(x, y + 4 * t), 1.6, dot);
      }
    }
    final wave = Paint()
      ..color = OxroColors.navyDark
          .withValues(alpha: 0.05);
    final path = Path()
      ..moveTo(0, size.height - 90)
      ..quadraticBezierTo(size.width * 0.5,
          size.height - 110 - 8 * t, size.width, size.height - 90)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(
          covariant _ResultBgPainter old) =>
      old.t != t;
}
