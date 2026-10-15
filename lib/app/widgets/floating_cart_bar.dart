import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Shared floating cart bar for pushed shopping pages
/// (L2 SubCategory, PLP, PDP, Search).
/// Same look/feel as Home's `_CartBar`: gradient pill, bounce icon,
/// AnimatedSwitcher count + total, GO button. Slides up when the bag
/// is non-empty, hides otherwise (and callers never show it on
/// Bag/Checkout — those have their own bottom bars).
class FloatingCartBar extends StatefulWidget {
  const FloatingCartBar({
    super.key,
    required this.onTap,
    this.bottomPadding = 10,
    this.compact = false,
  });

  /// Opens the Bag (callers push `BagScreen`).
  final VoidCallback onTap;

  /// Distance from the bottom (PDP passes sticky-bar height + gap).
  final double bottomPadding;

  /// Compact hides the count/savings text column
  /// (PDP: icon + total + Proceed only).
  final bool compact;

  @override
  State<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends State<FloatingCartBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final store = CartStore.instance;
        final show = store.count > 0;
        return AnimatedSlide(
          offset: show ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: show
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                        context.padX,
                        0,
                        context.padX,
                        widget.bottomPadding),
                    child: GestureDetector(
                      key: const ValueKey('cart_bar'),
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _ambient,
                        builder: (context, _) => Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8),
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(colors: [
                              Color(0xFFFFE3CB),
                              Color(0xFFFFC79B)
                            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                                color: OxroColors.primary,
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: OxroColors.primary
                                    .withValues(
                                        alpha: 0.22 +
                                            0.08 *
                                                _ambient
                                                    .value),
                                blurRadius: 16,
                                offset:
                                    const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              TweenAnimationBuilder<double>(
                                key: ValueKey(
                                    'cart_bounce_${store.count}'),
                                tween: Tween(
                                    begin: 0.5, end: 1.0),
                                duration:
                                    const Duration(
                                        milliseconds:
                                            280),
                                curve:
                                    Curves.easeOutBack,
                                builder:
                                    (context, v, _) =>
                                        Transform.scale(
                                  scale: v,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment:
                                        Alignment.center,
                                    decoration: BoxDecoration(
                                      color: OxroColors
                                          .primary
                                          .withValues(
                                              alpha:
                                                  0.14),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  12),
                                    ),
                                    child: const Icon(
                                        Icons
                                            .shopping_cart_outlined,
                                        size: 22,
                                        color: OxroColors
                                            .primary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!widget.compact)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(
                                              milliseconds:
                                                  200),
                                      transitionBuilder:
                                          (child,
                                                  anim) =>
                                              ScaleTransition(
                                                  scale:
                                                      anim,
                                                  child:
                                                      child),
                                      child: Text(
                                        '${store.count} items',
                                        key: ValueKey(
                                            'bar_${store.count}'),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight
                                                        .w800,
                                                color: OxroColors
                                                    .charcoal),
                                      ),
                                    ),
                                    Text(
                                        store.savings > 0
                                            ? '${Product.inr(store.savings)} savings'
                                            : 'Cart ready',
                                        key: ValueKey(
                                            'bar_sub_${store.savings}'),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: OxroColors
                                                .muted)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 34,
                                margin:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 4),
                                color: OxroColors.primary
                                    .withValues(
                                        alpha: 0.35),
                              ),
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(
                                          milliseconds:
                                              200),
                                  // FittedBox shrinks the font
                                  // instead of cutting the amount.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment:
                                        Alignment.centerLeft,
                                    child: Text(
                                      Product.inr(store
                                          .totalPrice),
                                      key: ValueKey(
                                          'cart_bar_total_${store.totalPrice}'),
                                      maxLines: 1,
                                      style:
                                          const TextStyle(
                                              fontSize:
                                                  13,
                                              fontWeight:
                                                  FontWeight
                                                      .w800,
                                              color:
                                                  OxroColors
                                                      .charcoal),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                key: const ValueKey(
                                    'cart_bar_go'),
                                onTap: widget.onTap,
                                behavior:
                                    HitTestBehavior.opaque,
                                child: Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal: 14,
                                          vertical: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        OxroColors.primary,
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                  ),
                                  child: const Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text('Proceed',
                                          style: TextStyle(
                                              color: Colors
                                                  .white,
                                              fontWeight:
                                                  FontWeight
                                                      .w800,
                                              fontSize:
                                                  13)),
                                      SizedBox(width: 2),
                                      Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color:
                                              Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
