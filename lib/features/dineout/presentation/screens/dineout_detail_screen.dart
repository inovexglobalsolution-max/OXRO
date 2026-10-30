import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/filter_chip_row.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/features/dineout/data/dineout_repo.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

class DineoutDetailScreen extends StatefulWidget {
  const DineoutDetailScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<DineoutDetailScreen> createState() => _DineoutDetailScreenState();
}

class _DineoutDetailScreenState extends State<DineoutDetailScreen> {
  int _guests = 2;
  late String _slot;

  DineoutRestaurant? get _restaurant => DineoutRepo.byId(widget.restaurantId);

  @override
  void initState() {
    super.initState();
    _slot = _restaurant?.slots.first ?? '7:30 PM';
  }

  void _pickCustomGuests() {
    int val = _guests > 8 ? _guests : 2;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guests'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      setDialogState(() => val = (val - 1).clamp(1, 25)),
                ),
                Expanded(
                  child: Text(
                    '$val',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setDialogState(() => val = (val + 1).clamp(1, 25)),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _guests = val);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _book(DineoutRestaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = _restaurant;
    if (restaurant == null) {
      return const Scaffold(
        body: Center(child: Text('Restaurant unavailable')),
      );
    }
    return Scaffold(
      key: const ValueKey('dineout_detail_screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('dineout_detail_scroll'),
          padding: EdgeInsets.only(bottom: context.rs(24)),
          children: [
            _hero(context, restaurant),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.padX,
                context.rs(16),
                context.padX,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.font(22),
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: OxroColors.charcoal,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      RatingChip(rating: restaurant.rating),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    restaurant.cuisineLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OxroColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Meta(
                        icon: Icons.place_outlined,
                        label:
                            '${restaurant.area} • ${restaurant.distanceLabel}',
                      ),
                      const SizedBox(width: 14),
                      _Meta(
                        icon: Icons.payments_outlined,
                        label:
                            '${Money.inr(restaurant.costForTwo * 100)} for two',
                      ),
                    ],
                  ),
                  if (restaurant.hasOffer) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: OxroColors.bgWarm,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: OxroColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 16,
                            color: OxroColors.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              restaurant.offerText,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _sectionTitle(context, 'Guests'),
                  const SizedBox(height: 10),
                  FilterChipRow(
                    key: const ValueKey('dineout_guests'),
                    padding: EdgeInsets.zero,
                    chips: [
                      for (final g in const [2, 4, 6, 8])
                        OxroFilterChip(
                          key: ValueKey('dineout_guests_$g'),
                          label: '$g guests',
                          selected: _guests == g,
                          onTap: () => setState(() => _guests = g),
                        ),
                      OxroFilterChip(
                        key: const ValueKey('dineout_guests_custom'),
                        label: _guests > 8 ? '$_guests guests' : 'Custom',
                        selected: _guests > 8,
                        onTap: _pickCustomGuests,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Pick a time'),
                  const SizedBox(height: 10),
                  FilterChipRow(
                    key: const ValueKey('dineout_slots'),
                    padding: EdgeInsets.zero,
                    chips: [
                      for (final slot in restaurant.slots)
                        OxroFilterChip(
                          key: ValueKey(
                            'dineout_slot_${slot.replaceAll(RegExp('[^0-9]'), '')}',
                          ),
                          label: slot,
                          selected: _slot == slot,
                          onTap: () => setState(() => _slot = slot),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle(context, 'About this place'),
                  const SizedBox(height: 7),
                  Text(
                    'A relaxed ${restaurant.cuisineLabel.toLowerCase()} '
                    'table in ${restaurant.area}. Walk in for a slow '
                    'meal, or reserve ahead for dinner with the people '
                    'who matter.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: OxroColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OxroColors.pageBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: OxroColors.muted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your table is held for 15 minutes after the '
                            'reserved time.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            context.padX,
            10,
            context.padX,
            context.isShortScreen ? 8 : 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: OxroColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_guests guests • $_slot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'No prepayment needed',
                      style: TextStyle(fontSize: 10, color: OxroColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                key: const ValueKey('dineout_book'),
                onTap: () => _book(restaurant),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: context.rs(46),
                  padding: EdgeInsets.symmetric(horizontal: context.rs(20)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: OxroColors.gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FF6A00),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Confirm reservation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

  Widget _hero(BuildContext context, DineoutRestaurant restaurant) {
    return Stack(
      children: [
        FoodImage(
          imageUrl: restaurant.imageUrl,
          colors: const [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
          icon: Icons.restaurant_outlined,
          width: double.infinity,
          height: context.isSmallPhone ? 190 : 224,
          radius: 0,
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000),
                  Color(0x00000000),
                  Color(0x66000000),
                ],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 8,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              key: const ValueKey('dineout_back'),
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 19,
                  color: OxroColors.charcoal,
                ),
              ),
            ),
          ),
        ),
        if (restaurant.hasOffer)
          Positioned(
            left: context.padX,
            right: context.padX,
            bottom: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: OxroColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  restaurant.offerText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: context.font(14),
        fontWeight: FontWeight.w900,
        color: OxroColors.charcoal,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OxroColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OxroColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
