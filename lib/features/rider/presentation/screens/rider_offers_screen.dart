import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';

/// Rider app mock-up (UI only, mock data).
///
/// Shows the earnings estimate *before* accepting, exactly as the live
/// [PricingEngine] computes it, so a delivery partner can decide on
/// transparent numbers: base + distance + peak/special + tip.
class RiderOffersScreen extends StatefulWidget {
  const RiderOffersScreen({super.key});

  @override
  State<RiderOffersScreen> createState() => _RiderOffersScreenState();
}

class _RiderOffersScreenState extends State<RiderOffersScreen> {
  static const _offers = <_DeliveryOffer>[
    _DeliveryOffer(
      id: 'DL-8801',
      pickup: 'Anandhas Kitchen, Fairlands',
      drop: 'Bharathi Street, Hasthampatti',
      roadMetres: 5100,
      tipPaise: 2000,
      orderCount: 1,
    ),
    _DeliveryOffer(
      id: 'DL-8802',
      pickup: 'Saravana Bhavan, Omalur Road',
      drop: 'Steel Plant Gate, Salem',
      roadMetres: 7800,
      tipPaise: 0,
      orderCount: 1,
    ),
    _DeliveryOffer(
      id: 'DL-8803',
      pickup: 'KFC, Five Roads',
      drop: 'Suramangalam + 1 more',
      roadMetres: 3200,
      tipPaise: 5000,
      orderCount: 2,
    ),
  ];

  final Set<String> _accepted = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Rider Hub',
            style: TextStyle(
                color: OxroColors.charcoal,
                fontWeight: FontWeight.w800)),
        iconTheme:
            const IconThemeData(color: OxroColors.charcoal),
      ),
      body: ListenableBuilder(
        listenable: PricingConfigStore.instance,
        builder: (context, _) {
          final engine = PricingEngine(
              PricingConfigStore.instance.config);
          final payouts = [
            for (final o in _offers)
              engine.payoutFor(DeliveryPayoutInput(
                roadMetres: o.roadMetres,
                orderCount: o.orderCount,
                tipPaise: o.tipPaise,
                acceptedAt: DateTime.now(),
              )),
          ];
          final todayEarnings = payouts.fold<int>(
              0, (s, p) => s + p.totalPaise);

          return ListView(
            key: const ValueKey('rider_scroll'),
            padding: EdgeInsets.fromLTRB(
                context.padX, 8, context.padX, 24),
            children: [
              _earningsHeader(context, todayEarnings),
              SizedBox(height: context.rs(12)),
              const Text('NEW DELIVERY REQUESTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.muted,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              for (var i = 0; i < _offers.length; i++)
                _offerCard(context, _offers[i], payouts[i]),
            ],
          );
        },
      ),
    );
  }

  Widget _earningsHeader(BuildContext context, int estimate) {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        gradient: OxroColors.gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delivery_dining,
                  color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('TODAY · ESTIMATED',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 6),
          Text(Money.inr(estimate),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 2),
          const Text('Across 3 available deliveries (incl. tips)',
              style: TextStyle(
                  fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _offerCard(BuildContext context, _DeliveryOffer o,
      DeliveryPayout p) {
    final accepted = _accepted.contains(o.id);
    final km = p.billableKm;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accepted
                ? OxroColors.green
                : OxroColors.border,
            width: accepted ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.id,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OxroColors.royalBlue
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${km.toStringAsFixed(1)} km',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.royalBlue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _leg(Icons.storefront_outlined, 'Pickup', o.pickup),
          const SizedBox(height: 6),
          _leg(Icons.flag_outlined, 'Drop', o.drop),
          const Divider(height: 18),
          _row('Base payout',
              Money.inr(p.basePayoutPaise)),
          _row('Distance (${km.toStringAsFixed(1)} km)',
              Money.inr(p.distancePayPaise)),
          if (p.stackingBonusPaise > 0)
            _row('Stacked order bonus',
                Money.inr(p.stackingBonusPaise)),
          if (p.peakBonusPaise > 0)
            _row('Peak-hour incentive',
                Money.inr(p.peakBonusPaise)),
          if (p.specialBonusPaise > 0)
            _row('Special bonus',
                Money.inr(p.specialBonusPaise)),
          if (p.tipPaise > 0)
            _row('Customer tip', Money.inr(p.tipPaise),
                highlight: true),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text('Estimated earnings',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              Text(Money.inr(p.totalPaise),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: OxroColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            key: ValueKey('rider_accept_${o.id}'),
            onTap: () {
              setState(() => _accepted.add(o.id));
              showOxroSnack(context,
                  'Accepted ${o.id} · ${Money.inr(p.totalPaise)}');
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accepted
                    ? Colors.white
                    : OxroColors.primary,
                borderRadius: BorderRadius.circular(12),
                border: accepted
                    ? Border.all(color: OxroColors.green)
                    : null,
              ),
              child: Text(
                accepted ? 'Accepted ✓' : 'Accept delivery',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accepted
                        ? OxroColors.green
                        : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leg(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: OxroColors.muted),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: OxroColors.muted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal)),
          ),
        ],
      );

  Widget _row(String k, String v, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: OxroColors.muted))),
            Text(v,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? OxroColors.green
                        : OxroColors.charcoal)),
          ],
        ),
      );
}

class _DeliveryOffer {
  const _DeliveryOffer({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.roadMetres,
    required this.tipPaise,
    required this.orderCount,
  });

  final String id;
  final String pickup;
  final String drop;
  final int roadMetres;
  final int tipPaise;
  final int orderCount;
}
