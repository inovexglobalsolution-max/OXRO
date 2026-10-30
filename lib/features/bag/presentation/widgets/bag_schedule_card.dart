import 'package:flutter/material.dart';

import 'package:oxro/app/data/delivery_time_service.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';

/// Premium, animated Scheduling Time container for the Cart (Bag) page.
///
/// Shows one consolidated estimated delivery time for the *complete* order.
/// Fades/slides in once on first appearance and cross-fades the time whenever
/// the cart changes. Never shown for an empty cart.
class BagScheduleCard extends StatefulWidget {
  const BagScheduleCard({super.key, required this.estimate});

  final DeliveryTimeEstimate estimate;

  @override
  State<BagScheduleCard> createState() => _BagScheduleCardState();
}

class _BagScheduleCardState extends State<BagScheduleCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // Static end state until didChangeDependencies can read MediaQuery.
    _entrance.value = 1.0;
    _pulse.value = 0.5;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _entrance.value = 1.0;
      _pulse.value = 0.5;
    } else {
      _entrance.forward();
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final e = widget.estimate;

    return FadeTransition(
      opacity: _entrance.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: SlideTransition(
        position: _entrance.drive(
          Tween(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: Container(
          key: const ValueKey('bag_schedule_card'),
          width: double.infinity,
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [OxroColors.premiumCream, OxroColors.premiumCreamDeep],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OxroColors.premiumChampagne.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: OxroColors.navyDark.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated clock / delivery-time icon.
              Container(
                width: context.rs(40),
                height: context.rs(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OxroColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OxroColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) {
                    final scale = reduce ? 1.0 : 0.92 + 0.08 * _pulse.value;
                    final turn = reduce ? 0.0 : _pulse.value / 12;
                    return Transform.rotate(
                      angle: turn,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: const Icon(
                    Icons.schedule_outlined,
                    size: 20,
                    color: OxroColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Estimated Delivery Time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.premiumInk,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Smooth number/time transition when the estimate changes.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        e.rangeLabel,
                        key: ValueKey('bag_schedule_time_${e.rangeLabel}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: OxroColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Based on your complete order · Estimate only',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: OxroColors.premiumMuted,
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
}
