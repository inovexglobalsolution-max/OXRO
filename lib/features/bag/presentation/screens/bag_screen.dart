import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/data/delivery_time_service.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/address/presentation/widgets/address_required_dialog.dart';
import 'package:oxro/features/bag/presentation/widgets/bag_bill_card.dart';
import 'package:oxro/features/bag/presentation/widgets/bag_reference_sections.dart';
import 'package:oxro/features/bag/presentation/widgets/bag_schedule_card.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/coupons/presentation/screens/coupons_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/widgets/schedule_sheet.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

/// My Cart tab — lines + bill + sticky order bar (premium).
/// Live from [CartStore]: stepper pops, totals tick, empty ↔ filled
/// swaps slide+fade, rows cascade in staggered, swipe ← removes.
class BagScreen extends StatelessWidget {
  const BagScreen({super.key, required this.onShopNow, this.onOrders});

  /// Empty-state CTA → Home tab.
  final VoidCallback onShopNow;

  final VoidCallback? onOrders;

  void _handleBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.maybePop();
    } else {
      onShopNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F4),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            CartStore.instance,
            PaymentStore.instance,
            PricingConfigStore.instance,
            PremiumStore.instance,
            AddressStore.instance,
          ]),
          builder: (context, _) {
            final store = CartStore.instance;
            final lines = store.lines;
            final quote = PaymentStore.instance.quoteForItemsTotal(
              store.totalPrice,
            );
            final restaurant = RestaurantRepo.byId(store.restaurantId ?? '');
            final minOrder = restaurant?.minOrder ?? 0;
            final belowMin = minOrder > 0 && store.totalPrice < minOrder;
            return Column(
              children: [
                // Header.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.padX,
                    12,
                    context.padX,
                    8,
                  ),
                  child: Row(
                    children: [
                      PressScale(
                        key: const ValueKey('bag_back'),
                        onTap: () => _handleBack(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: OxroColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 19,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'My Cart',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('bag_help'),
                        tooltip: 'Help & Support',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => pushScreen(
                          context,
                          HelpScreen(
                            onOrders: onOrders,
                            bagContext: true,
                            restaurantName: store.restaurantName,
                          ),
                        ),
                        icon: const Icon(
                          Icons.help_outline,
                          size: 20,
                          color: OxroColors.royalBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey('bag_count_${store.count}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: OxroColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${store.count} items',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body swaps empty ↔ filled.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.12, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(
                        position: slide,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: lines.isEmpty
                        ? _emptyBody(context)
                        : _filledBody(context, lines, quote),
                  ),
                ),
                // Sticky order bar.
                if (lines.isNotEmpty && belowMin)
                  Container(
                    key: const ValueKey('bag_min_order'),
                    width: double.infinity,
                    color: OxroColors.primary.withValues(alpha: 0.08),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.padX,
                      vertical: 7,
                    ),
                    child: Text(
                      'Add ${Product.inr(minOrder - store.totalPrice)} more to place your order',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.primary,
                      ),
                    ),
                  ),
                if (lines.isNotEmpty)
                  SafeArea(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        context.padX,
                        8,
                        context.padX,
                        12,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: OxroColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'To Pay',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: OxroColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: Text(
                                    Money.inr(quote.grandTotalPaise),
                                    key: ValueKey(
                                      'bag_bar_total_${quote.grandTotalPaise}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OrderButton(
                              onTap: () async {
                                final issue = AddressStore.instance.issue;
                                if (issue != AddressIssue.none) {
                                  final go = await showAddressRequiredDialog(
                                    context,
                                    issue,
                                  );
                                  if (go && context.mounted) {
                                    pushScreen(
                                      context,
                                      const AddressSelectionScreen(),
                                    );
                                  }
                                  return;
                                }
                                if (belowMin) {
                                  showOxroSnack(
                                    context,
                                    'Add ${Product.inr(minOrder - store.totalPrice)} more to place your order',
                                  );
                                  return;
                                }
                                if (!context.mounted) return;
                                pushScreen(
                                  context,
                                  const AddressSelectionScreen(),
                                );
                              },
                            ),
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
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 72,
                color: OxroColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your bag is empty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add dishes you love',
            style: TextStyle(fontSize: 13, color: OxroColors.muted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('bag_shop_now'),
            onTap: onShopNow,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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

  Future<void> _editNote(BuildContext context, CartStore store) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NoteSheet(
        initial: store.instructions,
        canClear: store.instructions.isNotEmpty,
      ),
    );
    if (result != null) store.setInstructions(result);
  }

  Widget _filledBody(
    BuildContext context,
    List<CartLine> lines,
    OrderQuote quote,
  ) {
    final store = CartStore.instance;
    final payment = PaymentStore.instance;
    final restaurant = RestaurantRepo.byId(store.restaurantId ?? '');
    final schedule = DeliveryTimeService().estimateForCart(
      lines: lines,
      restaurant: restaurant,
    );
    var section = 0;
    Widget reveal(Widget child) => BagReveal(index: section++, child: child);
    return ListView(
      key: const ValueKey('bag_lines'),
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 16),
      children: [
        if (store.savings > 0) ...[
          reveal(
            _SavingsBanner(
              key: ValueKey('savepop_${store.savings}'),
              store: store,
              lines: lines.length,
            ),
          ),
          const SizedBox(height: 10),
        ],
        reveal(
          BagPremiumOfferCard(
            total: store.totalPrice,
            member: PremiumStore.instance.isMember,
            onOpen: () => pushScreen(context, const PremiumScreen()),
          ),
        ),
        const SizedBox(height: 10),
        if (store.restaurantName != null) ...[
          Container(
            key: const ValueKey('bag_restaurant'),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: OxroColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OxroColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant,
                  size: 18,
                  color: OxroColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        store.restaurantName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        () {
                          final r = RestaurantRepo.byId(
                            store.restaurantId ?? '',
                          );
                          if (r == null) return 'Your kitchen';
                          return '${r.etaLabel}  ·  ${r.distanceLabel}';
                        }(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: OxroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('bag_clear'),
                  onPressed: store.clear,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < lines.length; i++)
          _BagStagger(
            index: i,
            child: _BagLineCard(line: lines[i]),
          ),
        const SizedBox(height: 4),
        if (store.restaurantId != null) ...[
          reveal(
            _BagItemActions(
              store: store,
              onAddMore: () => pushScreen(
                context,
                RestaurantScreen(restaurantId: store.restaurantId!),
              ),
              onNoteTap: () => _editNote(context, store),
            ),
          ),
          const SizedBox(height: 10),
          reveal(_FoodPreferencesCard(store: store)),
          const SizedBox(height: 12),
        ],
        if (restaurant != null) ...[
          reveal(BagMealRail(restaurant: restaurant, store: store)),
          const SizedBox(height: 14),
        ],
        reveal(
          BagCouponCard(
            store: store,
            payment: payment,
            onViewAll: () => pushScreen(context, const CouponsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        reveal(
          BagDeliveryAddressCard(
            address: AddressStore.instance.address,
            eta: restaurant?.etaRangeLabel,
            onTap: () => pushScreen(context, const AddressSelectionScreen()),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: quote.smallCartFeePaise > 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SmallCartFeeHint(
                    itemSubtotalPaise: quote.itemSubtotalPaise,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (schedule != null) ...[
          const SizedBox(height: 10),
          BagScheduleCard(estimate: schedule),
          const SizedBox(height: 10),
        ],
        BagBillCard(store: store, quote: quote, lines: lines),
        const SizedBox(height: 10),
        reveal(const BagCancellationNote()),
      ],
    );
  }
}

class _SmallCartFeeHint extends StatelessWidget {
  const _SmallCartFeeHint({required this.itemSubtotalPaise});

  final int itemSubtotalPaise;

  @override
  Widget build(BuildContext context) {
    final remaining = PricingEngine.smallCartFeeWaiverRemainingPaise(
      itemSubtotalPaise,
    );
    if (remaining <= 0) return const SizedBox.shrink();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final progress =
        (itemSubtotalPaise / PricingEngine.smallCartFeeWaiverThresholdPaise)
            .clamp(0.0, 1.0);
    return Container(
      key: const ValueKey('bag_smallcart_hint'),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E6), Color(0xFFFFFBF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OxroColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: OxroColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              size: 15,
              color: OxroColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Text(
                    'Add ${Money.inr(remaining)} more to remove the small cart fee!',
                    key: ValueKey('bag_smallcart_hint_$remaining'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: OxroColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      valueColor: const AlwaysStoppedAnimation(
                        OxroColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Green savings banner — pops on every savings change (parent keys
/// it by value) + slow glow pulse while visible.
/// Bottom sheet that owns its controller for a safe dismissal.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial, required this.canClear});

  final String initial;
  final bool canClear;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.padX, 10, context.padX, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OxroColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add a note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tell the restaurant about allergies or preferences.',
                style: TextStyle(fontSize: 12, color: OxroColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('bag_note_field'),
                controller: _ctrl,
                autofocus: true,
                maxLength: 140,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Less spicy, no onion',
                  filled: true,
                  fillColor: OxroColors.pageBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: OxroColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (widget.canClear)
                    TextButton(
                      key: const ValueKey('bag_note_clear'),
                      onPressed: () => Navigator.of(context).pop(''),
                      child: const Text('Clear'),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('bag_note_cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const ValueKey('bag_note_save'),
                    onPressed: () =>
                        Navigator.of(context).pop(_ctrl.text.trim()),
                    child: const Text('Save note'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kitchen note + cutlery choice for food bags.
class _BagItemActions extends StatelessWidget {
  const _BagItemActions({
    required this.store,
    required this.onAddMore,
    required this.onNoteTap,
  });

  final CartStore store;
  final VoidCallback onAddMore;
  final VoidCallback onNoteTap;

  @override
  Widget build(BuildContext context) {
    final note = store.instructions;
    return Container(
      key: const ValueKey('bag_item_actions'),
      padding: EdgeInsets.all(context.rs(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BagAction(
                  key: const ValueKey('bag_add_more'),
                  icon: Icons.add_circle_outline,
                  label: 'Add more items',
                  onTap: onAddMore,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BagAction(
                  key: const ValueKey('bag_note'),
                  icon: Icons.edit_note,
                  label: note.isEmpty ? 'Add a note' : 'Edit note',
                  onTap: onNoteTap,
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: OxroColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: OxroColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      key: const ValueKey('bag_note_value'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: OxroColors.charcoal,
                      ),
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
}

class _BagAction extends StatelessWidget {
  const _BagAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: OxroColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: OxroColors.primary.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: OxroColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodPreferencesCard extends StatelessWidget {
  const _FoodPreferencesCard({required this.store});

  final CartStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('bag_food_prefs'),
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_outlined,
            size: 19,
            color: OxroColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Opt in for cutlery',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal,
                  ),
                ),
                Text(
                  store.cutleryOptIn
                      ? 'Cutlery will be included'
                      : 'No cutlery needed',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: OxroColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('bag_cutlery'),
            value: store.cutleryOptIn,
            onChanged: store.setCutlery,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _SavingsBanner extends StatefulWidget {
  const _SavingsBanner({super.key, required this.store, required this.lines});

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
      duration: Duration(milliseconds: 350 + widget.lines * 60),
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
              padding: EdgeInsets.all(context.rs(12)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF1D4ED8,
                    ).withValues(alpha: 0.22 + 0.10 * _ambient.value),
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
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Column(
                        key: ValueKey('save_${store.savings}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'You save ${Product.inr(store.savings)} ($pct%)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BEST DEAL • on this order',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
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
        ),
      ),
    );
  }
}

/// Staggered slide-up entrance for bag rows.
class _BagStagger extends StatelessWidget {
  const _BagStagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + index * 60),
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
    // Size-aware keys stay backward compatible: size-less lines keep
    // the legacy `bag_*_<id>` keys; sized lines append `_<size>`.
    final sfx = line.size == null ? '' : '_${line.size}';
    return Dismissible(
      key: ValueKey('bag_line_${p.id}$sfx'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => CartStore.instance.remove(p.id, size: line.size),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: context.rs(10)),
        decoration: BoxDecoration(
          color: OxroColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: context.rs(10)),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OxroColors.lightGrey),
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
            FoodImage(
              imageUrl: p.imageUrl,
              colors: p.colors,
              icon: p.icon,
              width: context.rs(60),
              height: context.rs(60),
              radius: 14,
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.restaurantId != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: VegMark(veg: p.veg, egg: p.egg, size: 13),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.font(13),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (p.restaurantId != null) ...[
                    const SizedBox(height: 6),
                    _LineScheduleChip(line: line),
                  ],
                  if (line.size != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      key: ValueKey('bag_size_${p.id}_${line.size}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.pageBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: OxroColors.border),
                      ),
                      child: Text(
                        '${p.restaurantId == null ? 'Size' : 'Choice'}: ${line.size}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.dark,
                        ),
                      ),
                    ),
                  ],
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
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Product.inr(p.mrp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: OxroColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${p.off}% off',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                key: ValueKey('bag_dec_${p.id}$sfx'),
                                onTap: () => CartStore.instance.decrement(
                                  p.id,
                                  size: line.size,
                                ),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
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
                              SizedBox(
                                width: 24,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: Text(
                                    '${line.qty}',
                                    key: ValueKey(
                                      'bag_qty_${p.id}${sfx}_${line.qty}',
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                key: ValueKey('bag_inc_${p.id}$sfx'),
                                onTap: () => CartStore.instance.increment(
                                  p.id,
                                  size: line.size,
                                ),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
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
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        key: ValueKey('bag_remove_${p.id}$sfx'),
                        onTap: () =>
                            CartStore.instance.remove(p.id, size: line.size),
                        behavior: HitTestBehavior.opaque,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 15,
                              color: OxroColors.muted,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OxroColors.muted,
                              ),
                            ),
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

/// Per-line delivery time control for food items.
class _LineScheduleChip extends StatelessWidget {
  const _LineScheduleChip({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final sfx = line.size == null ? '' : '_${line.size}';
    final schedule = line.schedule;
    final selected = schedule != null;
    final radius = BorderRadius.circular(8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF1E6) : OxroColors.pageBg,
        borderRadius: radius,
        border: Border.all(
          color: selected
              ? OxroColors.primary.withValues(alpha: 0.45)
              : OxroColors.border,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('bag_schedule_${p.id}$sfx'),
          onTap: () => _pick(context),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: selected ? OxroColors.primary : OxroColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schedule?.chipLabel ?? 'Schedule time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? OxroColors.dark : OxroColors.muted,
                    ),
                  ),
                ),
                if (selected)
                  GestureDetector(
                    key: ValueKey('bag_schedule_clear_${p.id}$sfx'),
                    onTap: () => CartStore.instance.setSchedule(
                      p.id,
                      size: line.size,
                      schedule: null,
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: OxroColors.muted,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 15,
                    color: OxroColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showScheduleSheet(context, initial: line.schedule);
    if (picked == null) return;
    CartStore.instance.setSchedule(
      line.product.id,
      size: line.size,
      schedule: picked,
    );
  }
}

/// Gradient order button with press scale.
class _OrderButton extends StatefulWidget {
  const _OrderButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_OrderButton> createState() => _OrderButtonState();
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: const Text(
            'Place Order',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
