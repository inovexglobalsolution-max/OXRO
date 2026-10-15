import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';

/// Help & Support — FAQ + contact + orders shortcut.
/// Opened from Profile; all mock, no backend.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.onOrders});

  /// Go to Orders tab (track / return help).
  final VoidCallback onOrders;

  static const _faqs = [
    (
      q: 'How do I track my order?',
      a: 'Go to Orders tab, open the order, then tap Track. '
          'You will see live steps from packing to delivered.',
    ),
    (
      q: 'What payment methods are supported?',
      a: 'UPI, cards and Cash on Delivery (COD). '
          'Use code OXRO500 in checkout for a mock coupon discount.',
    ),
    (
      q: 'How do I change my delivery address?',
      a: 'Open Account > Addresses, add or select a default address. '
          'Checkout always uses the valid default address.',
    ),
    (
      q: 'How do returns work?',
      a: 'This demo build has no real returns flow yet. '
          'Contact support and we will arrange it for you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  Expanded(
                    child: Text('Help & Support',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('help_scroll'),
                padding: EdgeInsets.fromLTRB(
                    context.padX, 6, context.padX, 20),
                children: [
                  GestureDetector(
                    key: const ValueKey('help_track_order'),
                    onTap: onOrders,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(context.rs(12)),
                      decoration: BoxDecoration(
                        gradient: OxroColors.gradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                              Icons.local_shipping_outlined,
                              color: Colors.white),
                          SizedBox(width: context.rs(10)),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Need order help?',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                Text('Track or manage your orders',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(14)),
                  Text('FAQs',
                      style: TextStyle(
                          fontSize: context.font(15),
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal)),
                  SizedBox(height: context.rs(8)),
                  for (var i = 0; i < _faqs.length; i++)
                    Container(
                      key: ValueKey('help_faq_$i'),
                      margin: EdgeInsets.only(
                          bottom: context.rs(10)),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: OxroColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text(_faqs[i].q,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.charcoal)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 14),
                            child: Text(_faqs[i].a,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: OxroColors.muted)),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: context.rs(6)),
                  Text('Contact us',
                      style: TextStyle(
                          fontSize: context.font(15),
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal)),
                  SizedBox(height: context.rs(8)),
                  _contactRow(
                    context,
                    key: const ValueKey('help_call'),
                    icon: Icons.call_outlined,
                    label: '1800-123-456 (toll-free)',
                    onTap: () => showOxroSnack(
                        context, 'Calling support is mocked in demo'),
                  ),
                  _contactRow(
                    context,
                    key: const ValueKey('help_mail'),
                    icon: Icons.mail_outline,
                    label: 'care@oxro.in',
                    onTap: () => showOxroSnack(
                        context, 'Mail composer is mocked in demo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: context.rs(10)),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OxroColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OxroColors.primary
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 20, color: OxroColors.primary),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OxroColors.charcoal)),
            ),
            const Icon(Icons.chevron_right,
                color: OxroColors.muted),
          ],
        ),
      ),
    );
  }
}
