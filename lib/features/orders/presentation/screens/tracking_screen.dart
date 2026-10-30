import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/video_banner.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';
import 'package:oxro/features/coupons/presentation/screens/coupons_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

enum _PromoAction { premium, biryani, pizza }

class _PromoSlide {
  const _PromoSlide({
    required this.eyebrow,
    required this.title,
    required this.sub,
    required this.cta,
    required this.image,
    required this.video,
    required this.colors,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final String sub;
  final String cta;
  final String image;
  final String video;
  final List<Color> colors;
  final _PromoAction action;
}

const _promoSlides = [
  _PromoSlide(
    eyebrow: 'OXRO PREMIUM',
    title: 'FREE DELIVERY',
    sub: 'On every order above ₹199',
    cta: 'Explore PREMIUM',
    image: FoodMedia.heroThali,
    video: 'assets/videos/promo_premium.mp4',
    colors: [Color(0xFF2A0714), Color(0xFF6B1535)],
    action: _PromoAction.premium,
  ),
  _PromoSlide(
    eyebrow: 'LIMITED TIME',
    title: 'BIRYANI FEST',
    sub: 'Flat 30% OFF on dum biryani',
    cta: 'Order biryani',
    image: FoodMedia.heroBiryani,
    video: 'assets/videos/promo_biryani.mp4',
    colors: [Color(0xFFB3261E), Color(0xFFFF6A00)],
    action: _PromoAction.biryani,
  ),
  _PromoSlide(
    eyebrow: 'WEEKEND SPECIAL',
    title: 'PIZZA PARTY',
    sub: 'Buy 1 get 1 on signature pizzas',
    cta: 'Grab the deal',
    image: FoodMedia.heroPizza,
    video: 'assets/videos/promo_pizza.mp4',
    colors: [Color(0xFF004E92), Color(0xFF0A8CFF)],
    action: _PromoAction.pizza,
  ),
];

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _ambient;
  late final ScrollController _scroll;
  late final ValueNotifier<double> _collapse;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _collapse = ValueNotifier(0);
    _scroll = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _collapse.dispose();
    _entry.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final t = (_scroll.offset / 72).clamp(0.0, 1.0);
    if ((_collapse.value - t).abs() > 0.01) _collapse.value = t;
  }

  String get _shortId {
    final digits = widget.orderId.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? widget.orderId : digits;
  }

  static int _doneCount(OrderStatus status) {
    return switch (status) {
      OrderStatus.processing => 1,
      OrderStatus.shipped => 3,
      OrderStatus.outForDelivery => 4,
      OrderStatus.delivered => 5,
      OrderStatus.cancelled => 1,
    };
  }

  static String _headline(OrderStatus status) {
    return switch (status) {
      OrderStatus.processing => 'Order confirmed',
      OrderStatus.shipped => 'Being Prepared',
      OrderStatus.outForDelivery => 'On the way',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  static String _statusTab(OrderStatus status) {
    return switch (status) {
      OrderStatus.processing => 'Preparing your order!',
      OrderStatus.shipped => 'Preparing your order!',
      OrderStatus.outForDelivery => 'Your order is on the way!',
      OrderStatus.delivered => 'Delivered — enjoy your meal!',
      OrderStatus.cancelled => 'Order cancelled',
    };
  }

  static String _statusPill(OrderStatus status) {
    return switch (status) {
      OrderStatus.delivered => 'COMPLETED',
      OrderStatus.cancelled => 'CLOSED',
      _ => 'ON-TIME',
    };
  }

  static int _etaMinutes(String window, int fallback) {
    final matches = RegExp(r'\d+').allMatches(window).toList();
    if (matches.isEmpty) return fallback;
    return int.tryParse(matches.last.group(0) ?? '') ?? fallback;
  }

  static String _addressLine(Address? address) {
    if (address == null) return '123, Anna Nagar, Chennai — 600040';
    return '${address.line}, ${address.city} — ${address.pin}';
  }

  static String? _savingsText(OrderBill? bill) {
    if (bill == null) return null;
    if (bill.discountPaise > 0) {
      return '${Money.inr(bill.discountPaise)} saved on this order';
    }
    if (bill.deliveryPaise == 0) {
      return 'Free delivery applied on this order';
    }
    return null;
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: widget.orderId));
    showOxroSnack(context, 'Order ID copied');
  }

  void _openHelp() {
    pushScreen(context, HelpScreen(orderId: widget.orderId));
  }

  void _showGuarantee() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          key: const ValueKey('track_guarantee_sheet'),
          padding: EdgeInsets.fromLTRB(
            sheetContext.padX,
            4,
            sheetContext.padX,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Guarantee',
                style: TextStyle(
                  fontSize: sheetContext.font(20),
                  fontWeight: FontWeight.w900,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This order isn't covered by the on-time guarantee right now.",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: OxroColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('track_guarantee_close'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: OxroColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRestaurant(String? id) {
    if (id == null || id.isEmpty || RestaurantRepo.byId(id) == null) return;
    pushScreen(context, RestaurantScreen(restaurantId: id));
  }

  void _openOrderDetails() {
    pushScreen(context, OrderDetailsScreen(orderId: widget.orderId));
  }

  void _openPromo(_PromoAction action) {
    switch (action) {
      case _PromoAction.premium:
        pushScreen(context, const PremiumScreen());
      case _PromoAction.biryani:
        pushScreen(context, SubCategoryScreen(category: homeCategories[0]));
      case _PromoAction.pizza:
        pushScreen(context, SubCategoryScreen(category: homeCategories[4]));
    }
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
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final order = store.byId(widget.orderId);
    final status = store.statusOf(widget.orderId);
    final steps = store.trackingSteps(widget.orderId);
    final done = _doneCount(status);
    final kitchenId = order?.restaurantId;
    final kitchenName = order?.kitchenName;
    final restaurant = kitchenId == null
        ? null
        : RestaurantRepo.byId(kitchenId);
    final address = AddressStore.instance.address;
    final window = store.arrivalWindowFor(widget.orderId);
    final minutes = _etaMinutes(window, restaurant?.etaMinutes ?? 30);
    final progress = status == OrderStatus.cancelled
        ? 0.18
        : (done / 5).clamp(0.0, 1.0);
    final heroImage = FoodMedia.forRestaurant(kitchenId, kitchenName);
    final payable =
        order?.payablePaise ??
        (order == null
            ? 0
            : order.products.fold<int>(0, (s, p) => s + p.price) * 100);
    final itemCount = order?.products.length ?? 0;
    final firstItem = order?.products.isNotEmpty == true
        ? order!.products.first.name
        : 'Order items';
    final savings = _savingsText(order?.bill);
    final accent = status == OrderStatus.delivered
        ? OxroColors.green
        : status == OrderStatus.cancelled
        ? OxroColors.red
        : OxroColors.green;
    final headerHeight = context.rs(76);

    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              key: const ValueKey('track_screen'),
              controller: _scroll,
              padding: EdgeInsets.only(top: headerHeight + 4, bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.maxContentW),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.padX),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _in(
                          0,
                          _EtaCard(
                            status: status,
                            minutes: minutes,
                            progress: progress,
                            ambient: _ambient,
                            onGuarantee: _showGuarantee,
                          ),
                        ),
                        SizedBox(height: context.rs(14)),
                        _in(0.12, _HeroBanner(image: heroImage)),
                        _in(
                          0.2,
                          _deliverySheet(
                            context,
                            status: status,
                            steps: steps,
                            done: done,
                            address: address,
                            kitchenId: kitchenId,
                            kitchenName: kitchenName,
                            restaurant: restaurant,
                            payable: payable,
                            itemCount: itemCount,
                            firstItem: firstItem,
                            savings: savings,
                            accent: accent,
                          ),
                        ),
                        SizedBox(height: context.rs(22)),
                        _in(0.38, _promoSection(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _header(
                context,
                status: status,
                minutes: minutes,
                progress: progress,
                accent: accent,
                height: headerHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required OrderStatus status,
    required int minutes,
    required double progress,
    required Color accent,
    required double height,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (context, t, _) {
        final compact = t > 0.02;
        final active =
            status != OrderStatus.delivered && status != OrderStatus.cancelled;
        final statusLine = active
            ? '$minutes Mins left | ${_headline(status)}'
            : _headline(status);
        return Container(
          key: const ValueKey('track_header'),
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07 * t),
                blurRadius: 14 * t,
                offset: Offset(0, 4 * t),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.maxContentW + context.padX * 2,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: context.rs(6),
                      right: context.padX,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: OxroColors.charcoal,
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey('track_copy'),
                            onTap: _copyId,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Order #$_shortId',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: context.font(21 - 8 * t),
                                          fontWeight: FontWeight.w900,
                                          color: OxroColors.charcoal,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: context.rs(11),
                                      color: OxroColors.muted,
                                    ),
                                  ],
                                ),
                                if (compact)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      statusLine,
                                      key: const ValueKey('track_status'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: context.font(12),
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PressScale(
                          key: const ValueKey('track_help'),
                          onTap: _openHelp,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rs(15),
                              vertical: context.rs(8),
                            ),
                            decoration: BoxDecoration(
                              color: OxroColors.pageBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: OxroColors.border),
                            ),
                            child: Text(
                              'Help',
                              style: TextStyle(
                                fontSize: context.font(12.5),
                                fontWeight: FontWeight.w800,
                                color: OxroColors.charcoal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: t,
                  child: LinearProgressIndicator(
                    key: const ValueKey('track_header_progress'),
                    value: progress,
                    minHeight: 3,
                    backgroundColor: OxroColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _deliverySheet(
    BuildContext context, {
    required OrderStatus status,
    required List<TrackingStep> steps,
    required int done,
    required Address? address,
    required String? kitchenId,
    required String? kitchenName,
    required Restaurant? restaurant,
    required int payable,
    required int itemCount,
    required String firstItem,
    required String? savings,
    required Color accent,
  }) {
    final canOpenRestaurant =
        kitchenId != null &&
        kitchenId.isNotEmpty &&
        RestaurantRepo.byId(kitchenId) != null;
    final restaurantSub = restaurant == null
        ? 'Freshly prepared for you'
        : '${restaurant.distanceLabel} away • View menu';
    final countLabel = itemCount == 1 ? 'item' : 'items';
    final summary =
        '${Money.inr(payable)} | $itemCount $countLabel : 1x $firstItem';
    final addressTitle = 'Delivering at ${address?.label ?? 'Home'}';
    final restaurantTitle = kitchenName == null
        ? 'Delivering from OXRO Kitchen'
        : 'Delivering from $kitchenName';

    return Container(
      key: const ValueKey('track_sheet'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.rs(12),
        context.rs(5),
        context.rs(12),
        context.rs(18),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: context.rs(38),
              height: 4,
              decoration: BoxDecoration(
                color: OxroColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(height: context.rs(12)),
          Container(
            padding: EdgeInsets.all(context.rs(14)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OxroColors.border),
            ),
            child: Column(
              children: [
                _infoRow(
                  context,
                  key: const ValueKey('track_address'),
                  icon: Icons.location_on_outlined,
                  iconColor: OxroColors.royalBlue,
                  title: addressTitle,
                  subtitle: _addressLine(address),
                ),
                const _DashedDivider(),
                const _DashedDivider(),
                _riderCard(context),
                const _DashedDivider(),
                _infoRow(
                  context,
                  icon: Icons.location_on_outlined,
                  iconColor: OxroColors.royalBlue,
                  title: addressTitle,
                  subtitle: _addressLine(address),
                ),
                _infoRow(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  iconColor: OxroColors.charcoal,
                  title: 'Order Summary',
                  subtitle: summary,
                  trailing: GestureDetector(
                    key: const ValueKey('track_view_order'),
                    onTap: _openOrderDetails,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        'View ›',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: OxroColors.authBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                if (savings != null) ...[
                  SizedBox(height: context.rs(8)),
                  Container(
                    key: const ValueKey('track_savings'),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(10),
                      vertical: context.rs(8),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 16,
                          color: OxroColors.green,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            savings,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const _DashedDivider(),
                if (canOpenRestaurant)
                  PressScale(
                    key: const ValueKey('track_restaurant'),
                    onTap: () => _openRestaurant(kitchenId),
                    behavior: HitTestBehavior.opaque,
                    child: _infoRow(
                      context,
                      icon: Icons.storefront_outlined,
                      iconColor: OxroColors.primary,
                      title: restaurantTitle,
                      subtitle: restaurantSub,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(
                              Icons.call_rounded,
                              size: 18,
                              color: OxroColors.green,
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('tel:+919876543210');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: OxroColors.royalBlue,
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('sms:+919876543210');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _infoRow(
                    context,
                    key: const ValueKey('track_restaurant'),
                    icon: Icons.storefront_outlined,
                    iconColor: OxroColors.primary,
                    title: restaurantTitle,
                    subtitle: restaurantSub,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.call_rounded,
                            size: 18,
                            color: OxroColors.green,
                          ),
                          onPressed: () async {
                            final uri = Uri.parse('tel:+919876543210');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: OxroColors.royalBlue,
                          ),
                          onPressed: () async {
                            final uri = Uri.parse('sms:+919876543210');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: context.rs(14)),
          _journeyCard(
            context,
            status: status,
            steps: steps,
            done: done,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _riderCard(BuildContext context) {
    final riderName = 'Rahul Kumar';
    final riderPhone = '9876543210';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rs(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: OxroColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              size: 22,
              color: OxroColors.primary,
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Partner',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$riderName • +91 $riderPhone',
                  style: const TextStyle(fontSize: 12, color: OxroColors.muted),
                ),
              ],
            ),
          ),
          PressScale(
            onTap: () async {
              final uri = Uri.parse('tel:+91$riderPhone');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OxroColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_rounded, size: 16, color: OxroColors.green),
                  SizedBox(width: 4),
                  Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: context.rs(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.rs(23), color: iconColor),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(14.5),
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(12),
                    height: 1.35,
                    color: OxroColors.muted,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _journeyCard(
    BuildContext context, {
    required OrderStatus status,
    required List<TrackingStep> steps,
    required int done,
    required Color accent,
  }) {
    final progress = status == OrderStatus.cancelled
        ? 0.18
        : (done / 5).clamp(0.0, 1.0);
    return Container(
      key: const ValueKey('track_journey'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.rs(14),
        context.rs(12),
        context.rs(14),
        context.rs(10),
      ),
      decoration: BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'LIVE JOURNEY',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: OxroColors.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _headline(status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(8)),
          Stack(
            children: [
              Positioned(
                left: 15,
                top: 17,
                bottom: 17,
                child: SizedBox(
                  width: 2,
                  child: CustomPaint(
                    painter: _JourneyRailPainter(
                      progress: progress,
                      color: accent,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _journeyNode(context, i, steps[i], done, status, accent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _journeyNode(
    BuildContext context,
    int index,
    TrackingStep step,
    int done,
    OrderStatus status,
    Color accent,
  ) {
    final isDone = index < done;
    final isCurrent =
        index == done &&
        status != OrderStatus.delivered &&
        status != OrderStatus.cancelled;
    final dotColor = isDone
        ? OxroColors.green
        : isCurrent
        ? OxroColors.royalBlue
        : OxroColors.border;
    final chipBg = isDone
        ? const Color(0xFFD9F2E6)
        : isCurrent
        ? const Color(0xFFD8EBFF)
        : Colors.white;
    final ink = isDone
        ? OxroColors.green
        : isCurrent
        ? OxroColors.royalBlue
        : OxroColors.muted;
    final time = step.time.contains('�') ? '—' : step.time;

    return TweenAnimationBuilder<double>(
      key: ValueKey('track_node_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 130),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.82 + 0.18 * t,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.rs(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, _) => Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dotColor.withValues(
                              alpha: 0.32 + 0.38 * _ambient.value,
                            ),
                            width: 3,
                          ),
                        ),
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chipBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: dotColor, width: 1.5),
                          ),
                          child: Icon(step.icon, size: 13, color: ink),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDone ? chipBg : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: dotColor,
                          width: isDone ? 2 : 1.5,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check : step.icon,
                        size: 14,
                        color: ink,
                      ),
                    ),
                  SizedBox(width: context.rs(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.font(13),
                            fontWeight: isDone || isCurrent
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isDone || isCurrent
                                ? OxroColors.charcoal
                                : OxroColors.muted,
                          ),
                        ),
                        Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.font(11),
                            color: OxroColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, _) => Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OxroColors.royalBlue.withValues(
                            alpha: 0.09 + 0.06 * _ambient.value,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'now',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: OxroColors.royalBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _promoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OXRO Spotlight',
          style: TextStyle(
            fontSize: context.font(19),
            fontWeight: FontWeight.w900,
            color: OxroColors.charcoal,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: context.rs(12)),
        _PromoCarousel(onOpen: _openPromo),
        SizedBox(height: context.rs(14)),
        GridView.builder(
          key: const ValueKey('track_promo_grid'),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: CouponStore.coupons.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: context.rs(10),
            crossAxisSpacing: context.rs(10),
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final coupon = CouponStore.coupons[index];
            return _CouponTile(
              key: ValueKey('track_coupon_$index'),
              index: index,
              coupon: coupon,
              onTap: () => pushScreen(context, const CouponsScreen()),
            );
          },
        ),
        SizedBox(height: context.rs(14)),
        _premiumCard(context),
        SizedBox(height: context.rs(14)),
        _adCard(context),
        SizedBox(height: context.rs(24)),
        Center(
          child: Text(
            'It happens\nonly with OXRO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.font(34),
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: OxroColors.muted.withValues(alpha: 0.28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _premiumCard(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumStore.instance,
      builder: (context, _) {
        final member = PremiumStore.instance.isMember;
        return Container(
          key: const ValueKey('track_premium_card'),
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [OxroColors.premiumDeep, OxroColors.premiumWine],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OxroColors.premiumChampagne.withValues(alpha: 0.38),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 22,
                    color: OxroColors.premiumChampagne,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'OXRO PREMIUM',
                      style: TextStyle(
                        fontSize: context.font(14),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: OxroColors.premiumCream,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: OxroColors.premiumChampagne.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '₹${PremiumStore.freeDeliveryMinOrder}+',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.premiumChampagne,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: OxroColors.premiumChampagne.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member ? 'PREMIUM member' : 'Unlock FREE delivery',
                          style: TextStyle(
                            fontSize: context.font(16),
                            fontWeight: FontWeight.w900,
                            color: OxroColors.premiumCream,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          member
                              ? 'Your free-delivery benefit is active.'
                              : 'Free delivery on every order above ₹199.',
                          style: TextStyle(
                            fontSize: context.font(11.5),
                            height: 1.35,
                            color: OxroColors.premiumCream.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressScale(
                    key: const ValueKey('track_premium_cta'),
                    onTap: () => pushScreen(context, const PremiumScreen()),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(12),
                        vertical: context.rs(8),
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.premiumCream,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        member ? 'Manage' : 'Join',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: OxroColors.premiumInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _adCard(BuildContext context) {
    return PressScale(
      key: const ValueKey('track_ad'),
      onTap: () => _openPromo(_PromoAction.biryani),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OxroColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: context.rs(138),
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    FoodMedia.heroBbq,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [OxroColors.royalBlue, OxroColors.skyBlue],
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        "CHEF'S SPECIALS",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 13,
                    child: Text(
                      'Slow-cooked favourites,\ndelivered hot.',
                      style: TextStyle(
                        fontSize: context.font(21),
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.rs(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Explore rich biryanis, kebabs and weekend specials from our kitchens.',
                      style: TextStyle(
                        fontSize: context.font(12),
                        height: 1.4,
                        color: OxroColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(12),
                      vertical: context.rs(8),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: OxroColors.charcoal),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Discover',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: OxroColors.charcoal,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.north_east_rounded,
                          size: 13,
                          color: OxroColors.charcoal,
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
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({
    required this.status,
    required this.minutes,
    required this.progress,
    required this.ambient,
    required this.onGuarantee,
  });

  final OrderStatus status;
  final int minutes;
  final double progress;
  final Animation<double> ambient;
  final VoidCallback onGuarantee;

  @override
  Widget build(BuildContext context) {
    final terminal =
        status == OrderStatus.delivered || status == OrderStatus.cancelled;
    final big = terminal
        ? (status == OrderStatus.delivered ? 'Delivered' : 'Cancelled')
        : '$minutes';
    final accent = status == OrderStatus.delivered
        ? OxroColors.green
        : status == OrderStatus.cancelled
        ? OxroColors.red
        : OxroColors.green;

    return Container(
      key: const ValueKey('track_eta'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: OxroColors.charcoal.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rs(16),
              context.rs(14),
              context.rs(14),
              context.rs(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ARRIVING IN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: OxroColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              big,
                              key: const ValueKey('track_eta_minutes'),
                              style: TextStyle(
                                fontSize: context.font(29),
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: OxroColors.charcoal,
                                letterSpacing: -0.6,
                              ),
                            ),
                            if (!terminal) ...[
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  'Mins',
                                  style: TextStyle(
                                    fontSize: context.font(15),
                                    fontWeight: FontWeight.w800,
                                    color: OxroColors.charcoal,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 7),
                            Container(
                              key: const ValueKey('track_eta_pill'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: AnimatedBuilder(
                                animation: ambient,
                                builder: (context, _) => Text(
                                  _TrackingScreenState._statusPill(status),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                    color: accent.withValues(
                                      alpha: 0.82 + 0.18 * ambient.value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  key: const ValueKey('track_guarantee'),
                  onTap: onGuarantee,
                  child: SizedBox(
                    width: context.rs(106),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Time Guarantee',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.font(12.5),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w900,
                                  color: OxroColors.red,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: OxroColors.red,
                            ),
                          ],
                        ),
                        const Text(
                          'Not Applicable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: OxroColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rs(16)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final t = value.clamp(0.0, 1.0);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      key: const ValueKey('track_progress'),
                      height: 8,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: OxroColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: t,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: status == OrderStatus.cancelled
                                      ? [
                                          OxroColors.red.withValues(alpha: 0.7),
                                          OxroColors.red,
                                        ]
                                      : [
                                          OxroColors.skyBlue,
                                          OxroColors.royalBlue,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (constraints.maxWidth * t - 4).clamp(
                              0.0,
                              constraints.maxWidth - 8,
                            ),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: status == OrderStatus.cancelled
                                    ? OxroColors.red
                                    : OxroColors.royalBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: context.rs(5)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: context.rs(10)),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Text(
              _TrackingScreenState._statusTab(status),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.font(15),
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: AspectRatio(
        key: const ValueKey('track_hero'),
        aspectRatio: 1.72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoBanner(
              asset: 'assets/videos/hero_paneer.mp4',
              fallbackAsset: image,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.onOpen});

  final void Function(_PromoAction action) onOpen;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.03,
          child: PageView.builder(
            key: const ValueKey('track_promo_carousel'),
            controller: _controller,
            itemCount: _promoSlides.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final slide = _promoSlides[index];
              return PressScale(
                key: ValueKey('track_promo_$index'),
                onTap: () => widget.onOpen(slide.action),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: slide.colors.last.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoBanner(
                          asset: slide.video,
                          fallbackAsset: slide.image,
                          play: index == _page,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                slide.colors.last.withValues(alpha: 0.15),
                                slide.colors.first.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 18,
                          child: Text(
                            'OXRO',
                            style: TextStyle(
                              fontSize: context.font(15),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 18,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.eyebrow,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                slide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.font(27),
                                  height: 0.98,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.sub,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.font(12),
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rs(13),
                                  vertical: context.rs(8),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  slide.cta,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: slide.colors.first,
                                  ),
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
        ),
        SizedBox(height: context.rs(10)),
        Container(
          key: const ValueKey('track_promo_counter'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OxroColors.charcoal.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_page + 1}/${_promoSlides.length}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    super.key,
    required this.index,
    required this.coupon,
    required this.onTap,
  });

  final int index;
  final Coupon coupon;
  final VoidCallback onTap;

  static const _images = [
    FoodMedia.heroBiryani,
    FoodMedia.heroPizza,
    FoodMedia.heroDessert,
    FoodMedia.heroThali,
  ];

  static const _gradients = [
    [Color(0xFF7F1D1D), Color(0xFFB3261E)],
    [Color(0xFF004E92), Color(0xFF0A8CFF)],
    [Color(0xFF9D174D), Color(0xFFE11D48)],
    [Color(0xFF065F46), Color(0xFF0E9F6E)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final image = _images[index % _images.length];
    return PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
            Opacity(
              opacity: 0.72,
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.last.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.rs(11)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      coupon.code,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: colors.first,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: Text(
                      coupon.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.font(12.5),
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: Text(
                      coupon.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.font(10),
                        height: 1.25,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 9,
              bottom: 9,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: colors.first,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OxroColors.border
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JourneyRailPainter extends CustomPainter {
  const _JourneyRailPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = OxroColors.border
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      track,
    );
    final active = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height * progress.clamp(0.0, 1.0)),
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _JourneyRailPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
