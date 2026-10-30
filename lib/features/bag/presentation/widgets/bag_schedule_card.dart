import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/presentation/widgets/schedule_sheet.dart';

/// Premium, animated whole-bag schedule box (per-dish chips removed).
/// User picks one delivery slot for the complete meal via schedule_sheet.
class BagScheduleCard extends StatefulWidget {
  const BagScheduleCard({super.key, this.schedule});

  /// Whole-bag delivery slot; null = not yet scheduled.
  final DeliverySchedule? schedule;

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
    final s = widget.schedule;

    final label = s?.chipLabel ?? 'Schedule time';

    return FadeTransition(
      opacity: _entrance.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: SlideTransition(
        position: _entrance.drive(
          Tween(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () async {
              final picked = await showScheduleSheet(context, initial: s);
              if (picked != null && context.mounted) {
                CartStore.instance.setBagSchedule(picked);
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              key: const ValueKey('bag_schedule_card'),
              width: double.infinity,
              padding: EdgeInsets.all(context.rs(16)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    OxroColors.premiumCream,
                    OxroColors.premiumCreamDeep,
                  ],
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
                          'Meal Delivery Time',
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            label,
                            key: ValueKey('bag_schedule_time_$label'),
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
                          'Complete your meal · Tap to set delivery time',
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
        ),
      ),
    );
  }
}
