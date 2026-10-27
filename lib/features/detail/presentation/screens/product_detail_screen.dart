import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/app/widgets/oxro_bottom_nav.dart';
import 'package:oxro/features/detail/data/product_sizes.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/reviews/data/review_repo.dart';
import 'package:oxro/features/reviews/data/review_store.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// 11 Product Detail — premium: curved gallery + overlap info sheet +
/// offers + details + similars + sticky ADD bar.
/// Opened from Home / PLP / Search cards. Hero `pdp_image_<id>`
/// matches the card image for a shared transition on top of the
/// app-wide slide+fade.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.autoOpenReview = false,
  });

  final Product product;

  /// Past-orders deep-link: open the write sheet on first frame
  /// when the 48h window is still open.
  final bool autoOpenReview;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin, AutoHideNavState {
  late final AnimationController _entry;
  late final AnimationController _buyPress;

  /// Explicit size pick for apparel/footwear (null = not chosen yet).
  String? _size;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _buyPress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _entry.dispose();
    _buyPress.dispose();
    cancelNavTimer();
    super.dispose();
  }

  /// Cascading slide-up + fade entrance.
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

  void _buyNow() {
    final p = widget.product;
    if (p.restaurantId == null && requiresSize(p) && _size == null) {
      showOxroSnack(context, 'Please select a size first');
      return;
    }
    CartStore.instance.add(p, size: _size ?? defaultSizeFor(p));
    showOxroSnack(context, 'Checkout — coming in the next screen');
  }

  void _addFromPdp() {
    final p = widget.product;
    if (p.restaurantId == null && requiresSize(p) && _size == null) {
      showOxroSnack(context, 'Please select a size first');
      return;
    }
    CartStore.instance.add(p, size: _size ?? defaultSizeFor(p));
  }

  /// Size-guide sheet (chest/waist or foot-cm table per type).
  void _openSizeGuide() {
    final p = widget.product;
    final type = sizeTypeFor(p);
    final rows = type == SizeType.footwear ? footwearGuide : apparelGuide;
    final title = type == SizeType.footwear ? 'Shoe size guide' : 'Size guide';
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.padX, 16, context.padX, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.dark,
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('size_guide_close'),
                    onTap: () => Navigator.of(ctx).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.close, color: OxroColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('size_guide_table'),
                decoration: BoxDecoration(
                  border: Border.all(color: OxroColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: i == 0 ? OxroColors.pageBg : Colors.white,
                          border: i == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: OxroColors.border),
                                ),
                        ),
                        child: Row(
                          children: [
                            for (final c in rows[i])
                              Expanded(
                                child: Text(
                                  c,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: i == 0
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: OxroColors.dark,
                                  ),
                                ),
                              ),
                          ],
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
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isFood = p.restaurantId != null;
    final similars = ProductRepo.allFor(
      'pdp',
      p.brand,
      icon: p.icon,
    ).where((s) => s.id != p.id).take(6).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: HideableOxroBottomNav(
        visible: navVisible,
        currentIndex: 0,
        onTap: (i) => handleShopNav(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: handleNavScroll,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('pdp_scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _gallery(context, p),
                      // Overlap info sheet.
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: _in(
                            0.15,
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                context.padX,
                                16,
                                context.padX,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            if (isFood) ...[
                                              VegMark(veg: p.veg, size: 14),
                                              const SizedBox(width: 6),
                                            ],
                                            Flexible(
                                              child: Text(
                                                isFood ? p.kitchen : p.brand,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: OxroColors.muted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: OxroColors.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          isFood
                                              ? 'Freshly prepared'
                                              : '100% Original',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: OxroColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.name,
                                    key: const ValueKey('pdp_name'),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: context.font(20),
                                      fontWeight: FontWeight.w800,
                                      color: OxroColors.charcoal,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          p.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          isFood
                                              ? '(${p.reviews} ratings) - Loved by diners'
                                              : '(${p.reviews} ratings) - 100+ bought this month',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: OxroColors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Product.inr(p.price),
                                          key: const ValueKey('pdp_price'),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
                                          child: Text(
                                            Product.inr(p.mrp),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: OxroColors.muted,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
                                          child: Text(
                                            '${p.off}% off',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Inclusive of all taxes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: OxroColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Size selector (dresses + shoes; hidden
                      // for one-size products like electronics).
                      if (!isFood && requiresSize(p))
                        _in(
                          0.3,
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.padX,
                              12,
                              context.padX,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Select size',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: OxroColors.charcoal,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      key: const ValueKey('size_guide_btn'),
                                      onTap: _openSizeGuide,
                                      behavior: HitTestBehavior.opaque,
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.straighten_outlined,
                                            size: 15,
                                            color: OxroColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Size guide',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: OxroColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final s in sizesFor(p))
                                      GestureDetector(
                                        key: ValueKey('size_chip_$s'),
                                        onTap: () => setState(() => _size = s),
                                        behavior: HitTestBehavior.opaque,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _size == s
                                                ? OxroColors.primary
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: _size == s
                                                  ? OxroColors.primary
                                                  : OxroColors.border,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            s,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: _size == s
                                                  ? Colors.white
                                                  : OxroColors.dark,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Offers.
                      _in(
                        0.35,
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.padX,
                            4,
                            context.padX,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available offers',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isFood) ...[
                                _offerRow(
                                  context,
                                  Icons.percent_rounded,
                                  '10% off on your first order',
                                  'Use code OXRO10',
                                ),
                                const SizedBox(height: 8),
                                _offerRow(
                                  context,
                                  Icons.delivery_dining_outlined,
                                  'Free delivery above Rs 199',
                                  'On your first 3 orders',
                                ),
                              ] else ...[
                                _offerRow(
                                  context,
                                  Icons.local_offer_outlined,
                                  '10% off on OXRO Card',
                                  'On orders above Rs 1999',
                                ),
                                const SizedBox(height: 8),
                                _offerRow(
                                  context,
                                  Icons.credit_card_outlined,
                                  'No-Cost EMI from Rs ${(p.price / 12).round()}',
                                  'On major credit cards',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Details + delivery.
                      _in(
                        0.5,
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.padX,
                            16,
                            context.padX,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFood ? 'Dish details' : 'Product details',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: OxroColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final d
                                  in isFood
                                      ? [
                                          'Kitchen: ${p.kitchen}',
                                          if (p.description.isNotEmpty)
                                            p.description,
                                          'Freshly prepared after you order',
                                          'Delivered hot in tamper-proof packaging',
                                          'No-contact delivery available',
                                        ]
                                      : [
                                          'Brand: ${p.brand}',
                                          '100% Original - sourced from brand',
                                          'Easy 7-day returns, no questions asked',
                                          'Cash on Delivery available',
                                        ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: OxroColors.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          d,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(context.rs(12)),
                                decoration: BoxDecoration(
                                  color: OxroColors.lightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      size: 22,
                                      color: OxroColors.primary,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Free delivery • 600001',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '100% Original • Easy 7-day returns • COD available',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: OxroColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Reviews (all products, deterministic mocks).
                      _in(
                        0.6,
                        _ReviewsBlock(
                          product: p,
                          autoOpen: widget.autoOpenReview,
                        ),
                      ),
                      // Similars.
                      if (similars.isNotEmpty)
                        _in(
                          0.65,
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.padX,
                                  ),
                                  child: const Text(
                                    'You may also like',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: OxroColors.charcoal,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: context.rs(196),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.padX,
                                    ),
                                    itemCount: similars.length,
                                    separatorBuilder: (context, _) =>
                                        SizedBox(width: context.rs(10)),
                                    itemBuilder: (_, i) =>
                                        _similarCard(context, similars[i]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: context.rs(16)),
                    ],
                  ),
                ),
              ),
              // Sticky bottom bar (slides up on entry).
              AnimatedBuilder(
                animation: _entry,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(
                    ((_entry.value - 0.7) / 0.3).clamp(0.0, 1.0),
                  );
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - t)),
                      child: SafeArea(
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            context.padX,
                            8,
                            context.padX,
                            12,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            border: Border(
                              top: BorderSide(color: OxroColors.border),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x14051D47),
                                blurRadius: 12,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: !isFood && requiresSize(p)
                                    ? _SizeAddButton(
                                        product: p,
                                        selectedSize: _size,
                                        onNeedSize: _addFromPdp,
                                      )
                                    : AddButton(product: p),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  key: const ValueKey('pdp_buy'),
                                  onTapDown: (_) => _buyPress.value = 0.96,
                                  onTapUp: (_) => _buyPress.value = 1.0,
                                  onTapCancel: () => _buyPress.value = 1.0,
                                  onTap: () {
                                    _buyPress.value = 1.0;
                                    _buyNow();
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: ScaleTransition(
                                    scale: _buyPress,
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: OxroColors.primary,
                                          width: 1.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x18051D47),
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        isFood ? 'Checkout' : 'Buy Now',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: OxroColors.primary,
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Curved gallery: gradient + blobs + glass disc icon + badges.
  Widget _gallery(BuildContext context, Product p) {
    return Stack(
      children: [
        Hero(
          tag: 'pdp_image_${p.id}',
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: SizedBox(
              height: context.rs(300),
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(
                    imageUrl: p.imageUrl,
                    colors: p.colors,
                    icon: p.icon,
                    radius: 0,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55000000),
                          Color(0x00000000),
                          Color(0x44000000),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Back + wishlist fade in.
        Positioned(
          left: 8,
          top: 8,
          child: SafeArea(
            child: _fadePop(
              0,
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x20000000), blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: SafeArea(
            child: _fadePop(
              1,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: WishlistStore.instance,
                    builder: (context, _) {
                      final wished = WishlistStore.instance.contains(p.id);
                      return GestureDetector(
                        onTap: () => WishlistStore.instance.toggle(p),
                        behavior: HitTestBehavior.opaque,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('heart_$wished'),
                          tween: Tween(begin: 1.3, end: 1.0),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          builder: (context, v, _) => Transform.scale(
                            scale: v,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x20000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                wished
                                    ? Icons.favorite
                                    : Icons.favorite_outline,
                                size: 20,
                                color: wished ? Colors.red : OxroColors.muted,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _fadePop(
                    2,
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x20000000), blurRadius: 8),
                        ],
                      ),
                      child: ProductShareButton(product: p, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 36,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(-12 * (1 - v), 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${p.off}% OFF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Staggered fade for small overlay buttons.
  Widget _fadePop(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 100),
      curve: Curves.easeOut,
      builder: (context, v, _) =>
          Opacity(opacity: v.clamp(0.0, 1.0), child: child),
    );
  }

  Widget _offerRow(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
  ) {
    return Container(
      padding: EdgeInsets.all(context.rs(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OxroColors.lightGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: OxroColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _similarCard(BuildContext context, Product s) {
    return GestureDetector(
      key: ValueKey('pdp_similar_${s.id}'),
      onTap: () => pushScreen(context, ProductDetailScreen(product: s)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: context.rs(120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OxroColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: context.rs(84),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'pdp_image_${s.id}',
                    child: FoodImage(
                      imageUrl: s.imageUrl,
                      colors: s.colors,
                      icon: s.icon,
                      radius: 14,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: ProductShareButton(product: s, size: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Product.inr(s.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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

/// Ratings & Reviews block — deterministic mocks for every product.
/// Write form is hidden unless the 48h post-delivery window is open
/// (expired / never-bought render nothing — full hide, no lock note).
class _SizeAddButton extends StatelessWidget {
  const _SizeAddButton({
    required this.product,
    required this.selectedSize,
    required this.onNeedSize,
  });

  /// PDP sticky ADD bound to the selected size: SELECT SIZE until a
  /// chip is picked, then ADD ↔ stepper for that size only.
  final Product product;
  final String? selectedSize;
  final VoidCallback onNeedSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final qty = selectedSize == null
            ? 0
            : CartStore.instance.qtyOf(product.id, selectedSize);
        if (selectedSize == null || qty <= 0) {
          return GestureDetector(
            key: ValueKey('pdp_add_${product.id}_${selectedSize ?? 'none'}'),
            onTap: onNeedSize,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selectedSize == null
                    ? OxroColors.dark
                    : OxroColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x22051D47), blurRadius: 6),
                ],
              ),
              child: Text(
                selectedSize == null ? 'SELECT SIZE' : 'ADD',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
        return Container(
          key: ValueKey('pdp_stepper_${product.id}_$selectedSize'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: OxroColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x22051D47), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                key: ValueKey('pdp_dec_${product.id}_$selectedSize'),
                onTap: () => CartStore.instance.decrement(
                  product.id,
                  size: selectedSize,
                ),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Text(
                    '−',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Text(
                '$qty',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                key: ValueKey('pdp_inc_${product.id}_$selectedSize'),
                onTap: () => CartStore.instance.increment(
                  product.id,
                  size: selectedSize,
                ),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ratings & Reviews block — deterministic mocks for every product.
/// Write form is hidden unless the 48h post-delivery window is open
/// (expired / never-bought render nothing — full hide, no lock note).
class _ReviewsBlock extends StatefulWidget {
  const _ReviewsBlock({required this.product, this.autoOpen = false});
  final Product product;
  final bool autoOpen;
  @override
  State<_ReviewsBlock> createState() => _ReviewsBlockState();
}

class _ReviewsBlockState extends State<_ReviewsBlock> {
  late List<Review> _reviews;
  final _helped = <String>{};
  Review? _mine;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _reviews = ReviewRepo.reviewsFor(widget.product);
    _mine = ReviewStore.instance.myReviewFor(widget.product.id);
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoOpen());
    }
  }

  void _maybeAutoOpen() {
    if (_autoOpened || !mounted) return;
    _autoOpened = true;
    final access = ReviewRepo.canReview(
      productId: widget.product.id,
      orders: OrderStore.instance.all,
    );
    if (access == ReviewAccess.ok &&
        !ReviewStore.instance.hasReviewed(widget.product.id)) {
      _write();
    }
  }

  bool get _canWriteNow =>
      ReviewRepo.canReview(
        productId: widget.product.id,
        orders: OrderStore.instance.all,
      ) ==
      ReviewAccess.ok;

  Future<void> _write() async {
    // Recheck at submit-time: window may have closed while browsing.
    if (!_canWriteNow) {
      if (mounted) showOxroSnack(context, 'Review window closed (48 hrs over)');
      return;
    }
    if (ReviewStore.instance.hasReviewed(widget.product.id)) {
      if (mounted) showOxroSnack(context, 'You already reviewed this product');
      return;
    }
    final nameCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var stars = 5;
    final attached = <int>[];
    var attachVideo = false;
    var seedTick = 0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OxroColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Write a review',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        key: ValueKey('review_star_$i'),
                        onTap: () => setSheet(() => stars = i),
                        child: Icon(
                          i <= stars ? Icons.star : Icons.star_border,
                          size: 32,
                          color: OxroColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('review_name'),
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('review_body'),
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'What did you like? (min 10 chars)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // Mock attachments (demo gallery; device picker later).
                Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey('review_attach_photo'),
                      onTap: () {
                        if (attached.length >= 3) return;
                        setSheet(() {
                          attached.add(
                            (seedTick * 2 + 1) % ReviewRepo.mediaTints.length,
                          );
                          seedTick++;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: OxroColors.primary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 17,
                              color: OxroColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Photo (${attached.length}/3)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('review_attach_video'),
                      onTap: () => setSheet(() => attachVideo = !attachVideo),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: attachVideo
                              ? OxroColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: OxroColors.primary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 17,
                              color: attachVideo
                                  ? Colors.white
                                  : OxroColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '6s video',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: attachVideo
                                    ? Colors.white
                                    : OxroColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (attached.isNotEmpty || attachVideo) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attached.length + (attachVideo ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i < attached.length) {
                          final seed = attached[i];
                          final t = ReviewRepo
                              .mediaTints[seed % ReviewRepo.mediaTints.length];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: FoodImage(
                                  imageUrl: FoodMedia
                                      .all[seed.abs() % FoodMedia.all.length],
                                  colors: t,
                                  icon: Icons.restaurant,
                                  width: 56,
                                  height: 56,
                                  radius: 10,
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  key: ValueKey('review_unattach_$i'),
                                  onTap: () =>
                                      setSheet(() => attached.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Container(
                          width: 88,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: OxroColors.charcoal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '0:06',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('review_submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OxroColors.primary,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().length < 2 ||
                          bodyCtrl.text.trim().length < 10) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Add name + at least 10 chars'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Submit review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      // Window may have closed while the sheet was open — recheck.
      if (!_canWriteNow) {
        showOxroSnack(context, 'Review window closed (48 hrs over)');
        return;
      }
      final saved = await ReviewStore.instance.submit(
        productId: widget.product.id,
        name: nameCtrl.text,
        rating: stars,
        body: bodyCtrl.text,
        photos: List.of(attached),
        hasVideo: attachVideo,
      );
      if (!mounted) return;
      if (saved == null) {
        showOxroSnack(context, 'You already reviewed this product');
        return;
      }
      setState(() => _mine = saved);
      showOxroSnack(context, 'Thanks! Review submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bars = ReviewRepo.breakdown(p);
    final all = <Review>[..._reviews];
    if (_mine != null) all.insert(0, _mine!);
    return Padding(
      padding: EdgeInsets.fromLTRB(context.padX, 16, context.padX, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ratings & Reviews',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('pdp_reviews'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OxroColors.pageBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OxroColors.border),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      p.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _stars(p.rating.round(), 14),
                    Text(
                      '${p.reviews} ratings',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '${5 - i}★',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    key: ValueKey('pdp_rate_bar_${5 - i}'),
                                    value: bars[i] / 100,
                                    minHeight: 6,
                                    backgroundColor: OxroColors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      i < 2
                                          ? Colors.green
                                          : i == 2
                                          ? Colors.amber
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${bars[i]}%',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: OxroColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < all.length; i++) _card(context, all[i], i),
          ListenableBuilder(
            listenable: Listenable.merge([
              OrderStore.instance,
              ReviewStore.instance,
            ]),
            builder: (context, _) {
              final stored = ReviewStore.instance.myReviewFor(p.id);
              if (stored != null && _mine?.id != stored.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _mine = stored);
                });
              }
              final access = ReviewRepo.canReview(
                productId: p.id,
                orders: OrderStore.instance.all,
              );
              // 48h hide rule: show only when window is open
              // and user has not reviewed yet. Otherwise hide.
              if (access != ReviewAccess.ok ||
                  ReviewStore.instance.hasReviewed(p.id)) {
                return const SizedBox.shrink(
                  key: ValueKey('review_write_hidden'),
                );
              }
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('review_write'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OxroColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _write,
                  child: const Text(
                    'Write a review',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: OxroColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Review r, int i) {
    final helped = _helped.contains(r.id);
    return Container(
      key: ValueKey('review_card_${r.id}'),
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
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: OxroColors.gradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  r.name.isEmpty ? '?' : r.name[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${r.name} • ${r.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (r.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.green,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      r.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _stars(r.rating, 14),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            r.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
          if (r.hasMedia) ...[
            const SizedBox(height: 8),
            _mediaStrip(context, r),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            key: ValueKey('review_helpful_${r.id}'),
            onTap: () {
              if (_helped.contains(r.id)) return;
              setState(() => _helped.add(r.id));
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: helped ? OxroColors.primary : OxroColors.border,
                ),
                color: helped
                    ? OxroColors.primary.withValues(alpha: 0.08)
                    : Colors.white,
              ),
              child: Text(
                helped
                    ? 'Helpful (${r.helpful + 1}) ✓'
                    : 'Helpful (${r.helpful})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: helped ? OxroColors.primary : OxroColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Photo strip + 6-sec video tile for a review.
  Widget _mediaStrip(BuildContext context, Review r) {
    final shown = r.photos.take(3).toList();
    final extra = r.photos.length - shown.length;
    return SizedBox(
      height: 76,
      child: ListView.separated(
        key: ValueKey('review_media_${r.id}'),
        scrollDirection: Axis.horizontal,
        itemCount: shown.length + (r.hasVideo ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i < shown.length) {
            final seed = shown[i];
            final last = i == shown.length - 1 && extra > 0;
            return PressScale(
              key: ValueKey('review_photo_${r.id}_$seed'),
              onTap: () => _zoomPhoto(context, r, seed),
              child: _thumb(seed, overlay: last ? '+$extra' : null),
            );
          }
          return PressScale(
            key: ValueKey('review_video_${r.id}'),
            onTap: () => _playVideo(context, r),
            child: _videoTile(r),
          );
        },
      ),
    );
  }

  Widget _thumb(int seed, {String? overlay, double size = 76}) {
    final t = ReviewRepo.mediaTints[seed % ReviewRepo.mediaTints.length];
    final image = FoodMedia.all[seed.abs() % FoodMedia.all.length];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FoodImage(
              imageUrl: image,
              colors: t,
              icon: Icons.restaurant,
              width: size,
              height: size,
              radius: 12,
            ),
          ),
          if (overlay != null)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                overlay,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _videoTile(Review r) {
    final t = ReviewRepo
        .mediaTints[(r.id.hashCode).abs() % ReviewRepo.mediaTints.length];
    final image =
        widget.product.imageUrl ?? FoodMedia.forDish(widget.product.name);
    return Container(
      width: 120,
      height: 76,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FoodImage(
            imageUrl: image,
            colors: t,
            icon: Icons.restaurant,
            width: 120,
            height: 76,
            radius: 12,
          ),
          Container(color: Colors.black.withValues(alpha: 0.30)),
          const Center(
            child: Icon(Icons.play_circle_fill, size: 32, color: Colors.white),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '0:${r.videoSecs.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _zoomPhoto(BuildContext context, Review r, int seed) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        key: ValueKey('review_zoom_${r.id}_$seed'),
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (context, v, _) =>
                Transform.scale(scale: v, child: _thumb(seed, size: 260)),
          ),
        ),
      ),
    );
  }

  void _playVideo(BuildContext context, Review r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MockPlayer(
        review: r,
        imageUrl:
            widget.product.imageUrl ?? FoodMedia.forDish(widget.product.name),
      ),
    );
  }

  Widget _stars(int n, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= n ? Icons.star : Icons.star_border,
            size: size,
            color: Colors.amber.shade700,
          ),
      ],
    );
  }
}

/// Mock 6-sec review clip player (no real video yet).
/// Animated progress + play/pause + close; backend stream replaces later.
class _MockPlayer extends StatefulWidget {
  const _MockPlayer({required this.review, required this.imageUrl});

  final Review review;
  final String imageUrl;

  @override
  State<_MockPlayer> createState() => _MockPlayerState();
}

class _MockPlayerState extends State<_MockPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.review.videoSecs),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t =
        ReviewRepo.mediaTints[(widget.review.id.hashCode).abs() %
            ReviewRepo.mediaTints.length];
    return SafeArea(
      child: Container(
        key: const ValueKey('video_player'),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF102A43),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.review.name} • 0:06 clip',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('video_close'),
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 180,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(
                    imageUrl: widget.imageUrl,
                    colors: t,
                    icon: Icons.restaurant,
                    width: double.infinity,
                    height: 180,
                    radius: 14,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.25)),
                  GestureDetector(
                    key: const ValueKey('video_play'),
                    onTap: () {
                      if (_c.status == AnimationStatus.completed) {
                        _c.forward(from: 0);
                        setState(() => _playing = true);
                      } else if (_playing) {
                        _c.stop();
                        setState(() => _playing = false);
                      } else {
                        _c.forward();
                        setState(() => _playing = true);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('video_progress'),
                  value: _c.value.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    OxroColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Demo clip — full player ships with backend',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
