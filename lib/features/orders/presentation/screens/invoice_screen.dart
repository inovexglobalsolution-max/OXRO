import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';

/// Order invoice — a transparent, itemised copy of the frozen bill.
///
/// Reads only [MockOrder.bill]; it never recomputes, so an invoice printed
/// today matches the price charged at checkout even after admin edits.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final matches = OrderStore.instance.all.where((o) => o.id == orderId);
    final order = matches.isEmpty ? null : matches.first;
    final bill = order?.bill;
    final products = order?.products ?? const <Product>[];
    final instructions = order?.instructions;
    final cutleryOptIn = order?.cutleryOptIn;
    final cfgVersion = bill?.configVersion ?? 1;
    final addr = AddressStore.instance.address;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Invoice',
          style: TextStyle(
            color: OxroColors.charcoal,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: OxroColors.charcoal),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 24),
        children: [
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OXRO',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OxroColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Food Delivery Invoice',
                  style: TextStyle(fontSize: 12, color: OxroColors.muted),
                ),
                const SizedBox(height: 12),
                _kv('Order ID', orderId),
                _kv('Kitchen', order?.kitchenName ?? '-'),
                if (instructions != null) _kv('Note', instructions),
                if (cutleryOptIn != null)
                  _kv('Cutlery', cutleryOptIn ? 'Opted in' : 'Not requested'),
                _kv('Date', order?.date ?? '—'),
                _kv('Payment', 'Prepaid / Pay on delivery'),
                _kv('Config version', 'v$cfgVersion'),
              ],
            ),
          ),
          SizedBox(height: context.rs(12)),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERED TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.muted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  addr == null
                      ? 'No address on file'
                      : '${addr.name} • ${addr.phone}\n'
                            '${addr.line}, ${addr.city} - ${addr.pin}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: OxroColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.rs(12)),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ITEMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.muted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final p in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: OxroColors.charcoal,
                            ),
                          ),
                        ),
                        Text(
                          Product.inr(p.price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (products.isEmpty)
                  const Text(
                    'Itemised lines unavailable',
                    style: TextStyle(fontSize: 13, color: OxroColors.muted),
                  ),
              ],
            ),
          ),
          SizedBox(height: context.rs(12)),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.muted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                if (bill == null)
                  _row(
                    'Items Total',
                    Money.inr(
                      products.fold<int>(0, (s, p) => s + p.price) * 100,
                    ),
                  )
                else ...[
                  _row('Item total', Money.inr(bill.itemSubtotalPaise)),
                  if (bill.packagingPaise > 0)
                    _row(
                      'Restaurant packaging',
                      Money.inr(bill.packagingPaise),
                    ),
                  _row(
                    'Delivery fee',
                    bill.deliveryPaise == 0
                        ? 'FREE'
                        : Money.inr(bill.deliveryPaise),
                  ),
                  if (bill.smallCartFeePaise > 0)
                    _row(
                      'Small cart fee',
                      Money.inr(bill.smallCartFeePaise),
                    ),
                  _row(
                    'Platform fee',
                    bill.platformFeePaise == 0
                        ? 'FREE'
                        : Money.inr(bill.platformFeePaise),
                  ),
                  _row('Taxes (5% GST)', Money.inr(bill.taxPaise)),
                  if (bill.tipPaise > 0)
                    _row(
                      'Delivery tip (100% to rider)',
                      Money.inr(bill.tipPaise),
                    ),
                  if (bill.discountPaise > 0)
                    _row('Discount', '−${Money.inr(bill.discountPaise)}'),
                ],
                const Divider(height: 20),
                Row(
                  children: [
                    const Text(
                      'Total Paid',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Money.inr(
                        order?.payablePaise ??
                            products.fold<int>(0, (s, p) => s + p.price) * 100,
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: OxroColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.rs(16)),
          Center(
            child: GestureDetector(
              key: const ValueKey('invoice_share'),
              onTap: () =>
                  showOxroSnack(context, 'Invoice download — coming next'),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: OxroColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Download / Share Invoice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Prices are frozen at order time. Rates may change later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: OxroColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(context.rs(14)),
    decoration: BoxDecoration(
      color: OxroColors.pageBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: OxroColors.border),
    ),
    child: child,
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: OxroColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OxroColors.charcoal,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: OxroColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OxroColors.charcoal,
          ),
        ),
      ],
    ),
  );
}
