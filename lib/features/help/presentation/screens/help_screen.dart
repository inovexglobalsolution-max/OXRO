import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/help/data/support_store.dart';
import 'package:oxro/features/help/presentation/screens/support_request_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    this.onOrders,
    this.orderId,
    this.bagContext = false,
    this.restaurantName,
  });

  final VoidCallback? onOrders;
  final String? orderId;
  final bool bagContext;
  final String? restaurantName;

  static const _faqs = [
    (
      q: 'How do I track my order?',
      a:
          'Open Orders, select your order, then tap Track. '
          'You will see live steps from confirmed to delivered.',
    ),
    (
      q: 'What payment methods are supported?',
      a:
          'UPI, cards and Cash on Delivery. '
          'Use code OXRO500 in checkout for a mock coupon discount.',
    ),
    (
      q: 'How do I change my delivery address?',
      a:
          'Open Account > Addresses, add or select a default address. '
          'Checkout always uses the valid default address.',
    ),
    (
      q: 'How do I report a missing or wrong item?',
      a:
          'Open the order, tap Help, choose the issue and submit a request. '
          'Our support team reviews every request.',
    ),
    (
      q: 'When will I receive my refund?',
      a:
          'Refunds are reviewed before they are approved. Once approved, '
          'the amount is returned to the original payment method.',
    ),
    (
      q: 'Can I change cutlery or my kitchen note?',
      a:
          'Open Bag, use the food preferences card to add a note or toggle '
          'cutlery before checkout.',
    ),
  ];

  static const _bagFaqs = [
    (
      q: 'Why can I only order from one restaurant?',
      a:
          'A food bag is linked to one kitchen so your order is prepared '
          'and delivered together. Adding another kitchen starts a new bag.',
    ),
    (
      q: 'Why is the minimum order not met?',
      a:
          'Some kitchens have a minimum order value. Add more items from '
          'the same restaurant to continue to checkout.',
    ),
    (
      q: 'Why is my coupon not applying?',
      a:
          'Check the minimum order value, restaurant and payment conditions. '
          'Only one coupon can be applied at a time.',
    ),
    (
      q: 'Can I change the delivery address?',
      a:
          'Go to Account > Addresses to update your default address, then '
          'return to the bag and continue.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final order = _findOrder();
    final isOrderContext = orderId != null;
    final faqs = bagContext && !isOrderContext ? _bagFaqs : _faqs;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(8),
                vertical: 4,
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
                    child: Text(
                      'Help & Support',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.font(17),
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('help_scroll'),
                padding: EdgeInsets.fromLTRB(context.padX, 6, context.padX, 20),
                children: [
                  if (isOrderContext)
                    _orderHero(context, order)
                  else if (bagContext)
                    _bagHero(context)
                  else
                    _generalHero(context),
                  SizedBox(height: context.rs(10)),
                  if (!isOrderContext && !bagContext)
                    _reportCard(context)
                  else if (bagContext)
                    _reportCard(context),
                  if (isOrderContext || bagContext)
                    SizedBox(height: context.rs(10)),
                  if (bagContext && !isOrderContext) ...[
                    _bagContactCard(context),
                    SizedBox(height: context.rs(14)),
                  ],
                  Text(
                    'FAQs',
                    style: TextStyle(
                      fontSize: context.font(15),
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                  for (var i = 0; i < faqs.length; i++)
                    _faq(context, faqs[i], i),
                  _requests(context),
                  Text(
                    'Contact us',
                    style: TextStyle(
                      fontSize: context.font(15),
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                  _contactRow(
                    context,
                    key: const ValueKey('help_chat'),
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat with support',
                    onTap: () => showOxroSnack(
                      context,
                      'Support chat is mocked in this demo',
                    ),
                  ),
                  _contactRow(
                    context,
                    key: const ValueKey('help_mail'),
                    icon: Icons.mail_outline,
                    label: 'care@oxro.in',
                    onTap: () => showOxroSnack(
                      context,
                      'Mail composer is mocked in this demo',
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

  MockOrder? _findOrder() {
    final id = orderId;
    if (id == null) return null;
    for (final o in OrderStore.instance.all) {
      if (o.id == id) return o;
    }
    return null;
  }

  Widget _generalHero(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('help_track_order'),
      onTap: () => _openOrders(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          gradient: OxroColors.gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Colors.white),
            SizedBox(width: context.rs(10)),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need order help?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Track or manage your orders',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _orderHero(BuildContext context, MockOrder? order) {
    final label = order?.status.label ?? 'Order help';
    return Container(
      key: const ValueKey('help_order_context'),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        gradient: OxroColors.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30051D47),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ${orderId ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (order?.kitchenName != null) ...[
            const SizedBox(height: 3),
            Text(
              order!.kitchenName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroButton(
                  context,
                  key: const ValueKey('help_report_issue'),
                  label: 'Report issue',
                  onTap: () => _openOrderIssue(context, orderId!),
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroButton(
                  context,
                  key: const ValueKey('help_track_order'),
                  label: 'Track order',
                  onTap: () => _openOrders(context),
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bagHero(BuildContext context) {
    return Container(
      key: const ValueKey('help_bag_context'),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        gradient: OxroColors.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30051D47),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              SizedBox(width: context.rs(9)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need help with your bag?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      restaurantName == null || restaurantName!.isEmpty
                          ? 'Get help before placing your order'
                          : restaurantName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _heroButton(
            context,
            key: const ValueKey('help_bag_report'),
            label: 'Contact support about this bag',
            onTap: () => _openBagIssue(context),
            filled: true,
          ),
        ],
      ),
    );
  }

  Widget _heroButton(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: filled ? OxroColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('help_report_issue'),
      onTap: () => _pickOrder(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: OxroColors.pageBg,
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
                color: OxroColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.report_problem_outlined,
                size: 20,
                color: OxroColors.primary,
              ),
            ),
            SizedBox(width: context.rs(12)),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an order issue',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  Text(
                    'Missing item, wrong order, refund and more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: OxroColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: OxroColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _bagContactCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: OxroColors.royalBlue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Coupons, minimum order and address help is available below.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: OxroColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(BuildContext context, ({String q, String a}) faq, int index) {
    return Container(
      key: ValueKey('help_faq_$index'),
      margin: EdgeInsets.only(bottom: context.rs(10)),
      decoration: BoxDecoration(
        border: Border.all(color: OxroColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          faq.q,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: OxroColors.charcoal,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              faq.a,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: OxroColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requests(BuildContext context) {
    return ListenableBuilder(
      listenable: SupportStore.instance,
      builder: (context, _) {
        final all = orderId == null
            ? SupportStore.instance.recent
            : SupportStore.instance.forOrder(orderId!);
        if (all.isEmpty) return const SizedBox.shrink();
        final tickets = all.take(3).toList();
        return Column(
          key: const ValueKey('help_requests'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: context.rs(6)),
            Text(
              'Your requests',
              style: TextStyle(
                fontSize: context.font(15),
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
            SizedBox(height: context.rs(8)),
            for (final t in tickets) _ticketCard(context, t),
            SizedBox(height: context.rs(6)),
          ],
        );
      },
    );
  }

  Widget _ticketCard(BuildContext context, SupportTicket ticket) {
    return Container(
      key: ValueKey('help_ticket_${ticket.id}'),
      margin: EdgeInsets.only(bottom: context.rs(8)),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 18, color: Colors.green),
          ),
          SizedBox(width: context.rs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                Text(
                  [
                    if (ticket.orderId != null) ticket.orderId!,
                    if (ticket.restaurantName != null) ticket.restaurantName!,
                    _when(ticket.createdAt),
                  ].join('  |  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: OxroColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ticket.status,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _when(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$m '
        '${d.hour >= 12 ? 'PM' : 'AM'}';
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
                color: OxroColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: OxroColors.primary),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OxroColors.charcoal,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: OxroColors.muted),
          ],
        ),
      ),
    );
  }

  void _openOrders(BuildContext context) {
    final id = orderId;
    if (id != null) {
      pushScreen(context, TrackingScreen(orderId: id));
      return;
    }
    final callback = onOrders;
    if (callback == null) return;
    Navigator.of(context).pop();
    callback();
  }

  void _openOrderIssue(BuildContext context, String id) {
    pushScreen(context, SupportRequestScreen(orderId: id));
  }

  void _openBagIssue(BuildContext context) {
    pushScreen(
      context,
      SupportRequestScreen(
        source: SupportSource.bag,
        restaurantName: restaurantName,
      ),
    );
  }

  Future<void> _pickOrder(BuildContext context) async {
    final orders = OrderStore.instance.all;
    if (orders.isEmpty) {
      showOxroSnack(context, 'No orders available to report');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            key: const ValueKey('help_order_picker'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              const Text(
                'Choose an order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the order you need help with.',
                style: TextStyle(fontSize: 12, color: OxroColors.muted),
              ),
              const SizedBox(height: 12),
              for (final o in orders)
                GestureDetector(
                  key: ValueKey('help_pick_order_${o.id}'),
                  onTap: () => Navigator.of(sheetContext).pop(o.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OxroColors.pageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: OxroColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: OxroColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.id,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                [
                                  if (o.kitchenName != null) o.kitchenName!,
                                  o.status.label,
                                ].join('  |  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OxroColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: OxroColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (id == null || !context.mounted) return;
    await pushScreen(context, SupportRequestScreen(orderId: id));
  }
}
