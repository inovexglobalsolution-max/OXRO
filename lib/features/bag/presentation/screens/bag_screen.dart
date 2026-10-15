import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Shopping Bag tab — lines + bill + sticky order bar (premium).
/// Live from [CartStore]: stepper pops, totals tick, empty ↔ filled
/// swaps slide+fade, rows cascade in staggered, swipe ← removes.
class BagScreen extends StatelessWidget {
  const BagScreen({super.key, required this.onShopNow});

  /// Empty-state CTA → Home tab.
  final VoidCallback onShopNow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: CartStore.instance,
          builder: (context, _) {
            final store = CartStore.instance;
            final lines = store.lines;
            return Column(
              children: [
                // Header.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.padX, 12, context.padX, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Shopping Bag',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color:
                                    OxroColors.charcoal)),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(
                            milliseconds: 200),
                        child: Container(
                          key: ValueKey(
                              'bag_count_${store.count}'),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4),
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                              '${store.count} items',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      OxroColors.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body swaps empty ↔ filled.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(
                        milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder:
                        (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.12, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(
                        position: slide,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: lines.isEmpty
                        ? _emptyBody(context)
                        : _filledBody(context, lines),
                  ),
                ),
                // Sticky order bar.
                if (lines.isNotEmpty)
                  SafeArea(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                          context.padX, 8, context.padX,
                          12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            top: BorderSide(
                                color: OxroColors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('To Pay',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            OxroColors.muted,
                                        fontWeight:
                                            FontWeight
                                                .w600)),
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(
                                          milliseconds:
                                              200),
                                  transitionBuilder:
                                      (child, anim) =>
                                          ScaleTransition(
                                              scale: anim,
                                              child: child),
                                  child: Text(
                                    Product.inr(
                                        store.totalPrice),
                                    key: ValueKey(
                                        'bar_${store.totalPrice}'),
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        fontFeatures: [
                                          FontFeature
                                              .tabularFigures()
                                        ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OrderButton(
                                onTap: () async {
                              if (!AddressStore
                                  .instance.hasValid) {
                                showOxroSnack(context,
                                    'First fill your address');
                              }
                              if (!context.mounted) return;
                              pushScreen(
                                  context,
                                  const AddressSelectionScreen());
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyBody(BuildContext context) {
    return Center(
      key: const ValueKey('bag_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration:
                const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, v, _) =>
                Transform.scale(
              scale: v,
              child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 72,
                  color: OxroColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Your bag is empty',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Add styles you love',
              style: TextStyle(
                  fontSize: 13, color: OxroColors.muted)),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('bag_shop_now'),
            onTap: onShopNow,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40051D47),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Text('Shop Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filledBody(
      BuildContext context, List<CartLine> lines) {
    final store = CartStore.instance;
    return ListView(
      key: const ValueKey('bag_lines'),
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.fromLTRB(
          context.padX, 12, context.padX, 16),
      children: [
        for (var i = 0; i < lines.length; i++)
          _BagStagger(
            index: i,
            child: _BagLineCard(line: lines[i]),
          ),
        const SizedBox(height: 4),
        // Bill card (premium: bordered + tabular + reactive).
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(
              milliseconds:
                  300 + lines.length * 60),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final t = v.clamp(0.0, 1.0);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: Container(
                  padding: EdgeInsets.all(
                      context.rs(14)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                        color: OxroColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: OxroColors.royalBlue
                            .withValues(alpha: 0.07),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: OxroColors.primary
                                  .withValues(
                                      alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(
                                      9),
                            ),
                            child: const Icon(
                                Icons.receipt_outlined,
                                size: 17,
                                color:
                                    OxroColors.primary),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('BILL DETAILS',
                                maxLines: 1,
                                overflow: TextOverflow
                                    .ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: OxroColors.muted,
                                    letterSpacing: 1.1)),
                          ),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(
                                milliseconds: 200),
                            child: Container(
                              key: ValueKey(
                                  'bag_bill_count_${store.count}'),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                              decoration: BoxDecoration(
                                color: OxroColors
                                    .pageBg,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                              ),
                              child: Text(
                                  '${store.count} items',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: OxroColors
                                          .charcoal)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _billRow(
                          context,
                          'Total MRP',
                          Product.inr(store.totalMrp),
                          null,
                          'mrp_${store.totalMrp}'),
                      const SizedBox(height: 2),
                      _billRow(
                          context,
                          'Discount',
                          '−${Product.inr(store.savings)}',
                          Colors.green,
                          'disc_${store.savings}'),
                      const SizedBox(height: 2),
                      _billRow(context, 'Delivery',
                          'FREE', Colors.green, 'free'),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 12),
                        child: Divider(
                            height: 1,
                            color: OxroColors.border),
                      ),
                      SizedBox(
                        height: 26,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            const Text('To Pay',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: OxroColors
                                        .charcoal)),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration:
                                  const Duration(
                                      milliseconds:
                                          220),
                              transitionBuilder:
                                  (child, anim) =>
                                      ScaleTransition(
                                          scale: anim,
                                          child: child),
                              child: Text(
                                Product.inr(
                                    store.totalPrice),
                                key: ValueKey(
                                    'bag_total_${store.totalPrice}'),
                                maxLines: 1,
                                overflow: TextOverflow
                                    .ellipsis,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: OxroColors
                                        .charcoal,
                                    fontFeatures: [
                                      FontFeature
                                          .tabularFigures()
                                    ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Savings banner (green, pulsing, re-pops on change).
        if (store.savings > 0) ...[
          const SizedBox(height: 10),
          _SavingsBanner(
              key:
                  ValueKey('savepop_${store.savings}'),
              store: store,
              lines: lines.length),
        ],
      ],
    );
  }

  Widget _billRow(BuildContext context, String label,
      String value, Color? color, String flashKey) {
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OxroColors.muted)),
          const Spacer(),
          TweenAnimationBuilder<double>(
            key: ValueKey('billflash_$flashKey'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (context, v, _) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: OxroColors.primary
                    .withValues(alpha: 0.16 * (1 - v)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(
                        scale: anim, child: child),
                child: Text(value,
                    key: ValueKey('billval_$flashKey'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color:
                            color ?? OxroColors.charcoal,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green savings banner — pops on every savings change (parent keys
/// it by value) + slow glow pulse while visible.
class _SavingsBanner extends StatefulWidget {
  const _SavingsBanner(
      {super.key, required this.store, required this.lines});

  final CartStore store;
  final int lines;

  @override
  State<_SavingsBanner> createState() => _SavingsBannerState();
}

class _SavingsBannerState extends State<_SavingsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pct = store.totalMrp > 0
        ? (store.savings * 100 ~/ store.totalMrp)
        : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration:
          Duration(milliseconds: 350 + widget.lines * 60),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => Transform.scale(
        scale: v,
        child: Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => Container(
              key: const ValueKey('bag_savings'),
              width: double.infinity,
              padding:
                  EdgeInsets.all(context.rs(12)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF16A34A),
                    Color(0xFF4ADE80)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A)
                        .withValues(
                            alpha: 0.25 +
                                0.12 *
                                    _ambient.value),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.celebration_outlined,
                        size: 20,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(
                          milliseconds: 200),
                      transitionBuilder:
                          (child, anim) =>
                              ScaleTransition(
                                  scale: anim,
                                  child: child),
                      child: Column(
                        key: ValueKey(
                            'save_${store.savings}'),
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              'You save ${Product.inr(store.savings)} ($pct%)',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: Colors.white,
                                  fontFeatures: [
                                    FontFeature
                                        .tabularFigures()
                                  ])),
                          const SizedBox(height: 3),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(
                                      alpha: 0.25),
                              borderRadius:
                                  BorderRadius.circular(
                                      6),
                            ),
                            child: const Text(
                                'BEST DEAL • on this order',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight:
                                        FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
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

/// Staggered slide-up entrance for bag rows.
class _BagStagger extends StatelessWidget {
  const _BagStagger(
      {required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration:
          Duration(milliseconds: 250 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// One cart line — swipe ← to remove, compact stepper, × remove.
class _BagLineCard extends StatelessWidget {
  const _BagLineCard({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    return Dismissible(
      key: ValueKey('bag_line_${p.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          CartStore.instance.remove(p.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: context.rs(10)),
        decoration: BoxDecoration(
          color: OxroColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.white),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: context.rs(10)),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: OxroColors.lightGrey),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10051D47),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.rs(60),
              height: context.rs(60),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: p.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(p.icon,
                  size: 28, color: OxroColors.muted),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: OxroColors.muted,
                          fontWeight: FontWeight.w600)),
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: context.font(13),
                          fontWeight: FontWeight.w700,
                          height: 1.25)),
                  const SizedBox(height: 4),
                  // Price + mrp + off% (PDP pattern). FittedBox
                  // shrinks on narrow screens — never overlaps.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            Product.inr(p.price),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800)),
                        const SizedBox(width: 6),
                        Text(
                            Product.inr(p.mrp),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: OxroColors.muted,
                                decoration: TextDecoration
                                    .lineThrough)),
                        const SizedBox(width: 6),
                        Text('${p.off}% off',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w700,
                                color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Fixed-width stepper — identical size for
                      // every row no matter the qty digits.
                      SizedBox(
                        width: 96,
                        child: Container(
                          decoration: BoxDecoration(
                            color: OxroColors.primary,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.max,
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              GestureDetector(
                                key: ValueKey(
                                    'bag_dec_${p.id}'),
                                onTap: () => CartStore
                                    .instance
                                    .decrement(p.id),
                                behavior: HitTestBehavior
                                    .opaque,
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  child: Text('−',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color: Colors
                                              .white)),
                                ),
                              ),
                              SizedBox(
                                width: 24,
                                child:
                                    AnimatedSwitcher(
                                  duration:
                                      const Duration(
                                          milliseconds:
                                              150),
                                  transitionBuilder:
                                      (child, anim) =>
                                          ScaleTransition(
                                              scale: anim,
                                              child: child),
                                  child: Text(
                                      '${line.qty}',
                                      key: ValueKey(
                                          'bag_qty_${p.id}_${line.qty}'),
                                      textAlign:
                                          TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow
                                          .clip,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color: Colors
                                              .white)),
                                ),
                              ),
                              GestureDetector(
                                key: ValueKey(
                                    'bag_inc_${p.id}'),
                                onTap: () => CartStore
                                    .instance
                                    .increment(p.id),
                                behavior: HitTestBehavior
                                    .opaque,
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  child: Text('+',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color: Colors
                                              .white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        key: ValueKey(
                            'bag_remove_${p.id}'),
                        onTap: () => CartStore.instance
                            .remove(p.id),
                        behavior:
                            HitTestBehavior.opaque,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 15,
                                color: OxroColors.muted),
                            SizedBox(width: 4),
                            Text('Remove',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: OxroColors.muted)),
                          ],
                        ),
                      ),
                    ],
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

/// Gradient order button with press scale.
class _OrderButton extends StatefulWidget {
  const _OrderButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_OrderButton> createState() =>
      _OrderButtonState();
}

class _OrderButtonState extends State<_OrderButton>
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
      key: const ValueKey('bag_order'),
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
        child: Container(
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: OxroColors.gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40051D47),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Text('Place Order',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
      ),
    );
  }
}
