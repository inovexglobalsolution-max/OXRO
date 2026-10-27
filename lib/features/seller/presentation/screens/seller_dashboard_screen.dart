import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';

/// Seller portal mock-up (UI only, mock data).
///
/// Every row is priced by [PricingEngine] with the live [PricingConfigStore]
/// so the settlement shown here matches what the backend will pay out:
/// food subtotal − commission − commission GST − TDS = net settlement.
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  static const _orders = <_SellerOrder>[
    _SellerOrder('ORD-2041', 'Anandhas Kitchen', 30000),
    _SellerOrder('ORD-2040', 'Anandhas Kitchen', 48500),
    _SellerOrder('ORD-2039', 'Anandhas Kitchen', 12900),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Seller Hub',
            style: TextStyle(
                color: OxroColors.charcoal,
                fontWeight: FontWeight.w800)),
        iconTheme:
            const IconThemeData(color: OxroColors.charcoal),
      ),
      body: ListenableBuilder(
        listenable: PricingConfigStore.instance,
        builder: (context, _) {
          final cfg = PricingConfigStore.instance.config;
          final engine = PricingEngine(cfg);

          final quotes = [
            for (final o in _orders)
              engine.quoteOrder(OrderQuoteInput(subOrders: [
                SubOrderInput(
                    restaurantId: o.restaurant,
                    foodSubtotalPaise: o.subtotalPaise),
              ])).subOrders.single,
          ];

          final gross = quotes.fold<int>(
              0, (s, q) => s + q.commissionBasePaise);
          final commission =
              quotes.fold<int>(0, (s, q) => s + q.commissionPaise);
          final gst = quotes.fold<int>(
              0, (s, q) => s + q.commissionGstPaise);
          final tds =
              quotes.fold<int>(0, (s, q) => s + q.tdsPaise);
          final net = quotes.fold<int>(
              0, (s, q) => s + q.settlementPaise);

          return ListView(
            key: const ValueKey('seller_scroll'),
            padding: EdgeInsets.fromLTRB(
                context.padX, 8, context.padX, 24),
            children: [
              _summaryCard(context, cfg, gross, commission,
                  gst, tds, net),
              SizedBox(height: context.rs(12)),
              const Text('RECENT ORDERS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.muted,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              for (var i = 0; i < _orders.length; i++)
                _orderCard(context, _orders[i], quotes[i]),
              SizedBox(height: context.rs(12)),
              const Text('SETTLEMENT HISTORY',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.muted,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              _settlementRow('Mon–Sun · last week',
                  Money.inr(1284500), 'Paid'),
              _settlementRow('Mon–Sun · this week',
                  Money.inr(net), 'Processing'),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(
      BuildContext context,
      PricingConfig cfg,
      int gross,
      int commission,
      int gst,
      int tds,
      int net) {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        gradient: OxroColors.gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THIS WEEK · 3 ORDERS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 1.1)),
          const SizedBox(height: 6),
          Text(Money.inr(net),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text('Net settlement · commission ${cfg.commissionBps ~/ 100}%',
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          _miniRow('Food subtotal', Money.inr(gross)),
          _miniRow('Commission', '−${Money.inr(commission)}'),
          _miniRow('Commission GST', '−${Money.inr(gst)}'),
          _miniRow('TDS (194-O)', '−${Money.inr(tds)}'),
        ],
      ),
    );
  }

  Widget _miniRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70))),
            Text(v,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );

  Widget _orderCard(
      BuildContext context, _SellerOrder o, SubOrderQuote q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(context.rs(14)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.id,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text(o.restaurant,
                        style: const TextStyle(
                            fontSize: 12,
                            color: OxroColors.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OxroColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Completed',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.green)),
              ),
            ],
          ),
          const Divider(height: 18),
          _row('Food subtotal',
              Money.inr(q.commissionBasePaise)),
          _row('Commission (${q.commissionBps ~/ 100}%)',
              '−${Money.inr(q.commissionPaise)}'),
          _row('Commission GST',
              '−${Money.inr(q.commissionGstPaise)}'),
          _row('TDS (194-O)', '−${Money.inr(q.tdsPaise)}'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                  child: Text('Net settlement',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800))),
              Text(Money.inr(q.settlementPaise),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: OxroColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: OxroColors.muted))),
            Text(v,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal)),
          ],
        ),
      );

  Widget _settlementRow(String label, String amount, String status) {
    final paid = status == 'Paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OxroColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13))),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text(status,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: paid
                      ? OxroColors.green
                      : OxroColors.primary)),
        ],
      ),
    );
  }
}

class _SellerOrder {
  const _SellerOrder(this.id, this.restaurant, this.subtotalPaise);
  final String id;
  final String restaurant;
  final int subtotalPaise;
}
