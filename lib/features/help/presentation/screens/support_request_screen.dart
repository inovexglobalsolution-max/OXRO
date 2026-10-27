import 'package:flutter/material.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/help/data/support_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({
    super.key,
    this.orderId,
    this.restaurantName,
    this.source = SupportSource.order,
  });

  final String? orderId;
  final String? restaurantName;
  final SupportSource source;

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _IssueCategory {
  const _IssueCategory(
    this.id,
    this.label,
    this.icon, {
    this.requiresItem = false,
    this.requiresNote = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool requiresItem;
  final bool requiresNote;
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _note = TextEditingController();
  _IssueCategory? _selected;
  final Set<String> _items = {};
  SupportTicket? _ticket;

  static const _active = [
    _IssueCategory('delayed', 'Order delayed', Icons.schedule),
    _IssueCategory(
      'address',
      'Wrong delivery address',
      Icons.location_off_outlined,
    ),
    _IssueCategory(
      'payment_refund',
      'Payment / refund',
      Icons.account_balance_wallet_outlined,
    ),
    _IssueCategory('other', 'Other', Icons.more_horiz, requiresNote: true),
  ];

  static const _delivered = [
    _IssueCategory(
      'missing_item',
      'Item missing',
      Icons.remove_shopping_cart_outlined,
      requiresItem: true,
    ),
    _IssueCategory(
      'wrong_item',
      'Wrong item',
      Icons.swap_horiz,
      requiresItem: true,
    ),
    _IssueCategory('quality', 'Food quality', Icons.restaurant_menu),
    _IssueCategory(
      'packaging',
      'Packaging damaged',
      Icons.inventory_2_outlined,
    ),
    _IssueCategory(
      'payment_refund',
      'Payment / refund',
      Icons.account_balance_wallet_outlined,
    ),
    _IssueCategory('other', 'Other', Icons.more_horiz, requiresNote: true),
  ];

  static const _cancelled = [
    _IssueCategory('refund', 'Refund not received', Icons.currency_rupee),
    _IssueCategory(
      'cancellation_fee',
      'Cancellation fee',
      Icons.receipt_long_outlined,
    ),
    _IssueCategory('other', 'Other', Icons.more_horiz, requiresNote: true),
  ];

  static const _bag = [
    _IssueCategory(
      'item_unavailable',
      'Item unavailable',
      Icons.restaurant_outlined,
    ),
    _IssueCategory(
      'price_coupon',
      'Price / coupon issue',
      Icons.local_offer_outlined,
    ),
    _IssueCategory('address', 'Delivery address', Icons.location_on_outlined),
    _IssueCategory(
      'payment',
      'Payment issue',
      Icons.account_balance_wallet_outlined,
    ),
    _IssueCategory('other', 'Other', Icons.more_horiz, requiresNote: true),
  ];

  MockOrder? get _order {
    final id = widget.orderId;
    if (id == null) return null;
    for (final o in OrderStore.instance.all) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<_IssueCategory> get _categories {
    if (widget.source == SupportSource.bag) return _bag;
    final status = _order?.status;
    if (status == OrderStatus.delivered) return _delivered;
    if (status == OrderStatus.cancelled) return _cancelled;
    return _active;
  }

  List<String> get _orderItems {
    final order = _order;
    if (order == null) return const [];
    final seen = <String>{};
    return [
      for (final p in order.products)
        if (seen.add(p.name)) p.name,
    ];
  }

  String? get _restaurant => _order?.kitchenName ?? widget.restaurantName;

  bool get _needsItem => _selected?.requiresItem ?? false;

  bool get _canSubmit {
    final selected = _selected;
    if (selected == null) return false;
    if (selected.requiresItem && _items.isEmpty) return false;
    if (selected.requiresNote && _note.text.trim().isEmpty) return false;
    return true;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _choose(_IssueCategory category) {
    setState(() {
      _selected = category;
      if (!category.requiresItem) _items.clear();
    });
  }

  void _submit() {
    final selected = _selected;
    if (!_canSubmit || selected == null) return;
    final ticket = SupportStore.instance.submit(
      source: widget.source,
      categoryId: selected.id,
      categoryLabel: selected.label,
      orderId: widget.orderId,
      restaurantName: _restaurant,
      items: _items.toList(),
      note: _note.text,
    );
    FocusScope.of(context).unfocus();
    setState(() => _ticket = ticket);
  }

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _ticket == null ? _form(context) : _success(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final categories = _categories;
    return Column(
      key: const ValueKey('issue_screen'),
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.padX, 4, context.padX, 16),
            children: [
              _contextCard(context),
              SizedBox(height: context.rs(16)),
              Text(
                'What went wrong?',
                style: TextStyle(
                  fontSize: context.font(15),
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              SizedBox(height: context.rs(8)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories) _categoryChip(context, c),
                ],
              ),
              if (_needsItem) ...[
                SizedBox(height: context.rs(16)),
                Text(
                  'Which item?',
                  style: TextStyle(
                    fontSize: context.font(14),
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                SizedBox(height: context.rs(8)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _orderItems.length; i++)
                      _itemChip(context, _orderItems[i], i),
                  ],
                ),
              ],
              SizedBox(height: context.rs(16)),
              Text(
                'Tell us more',
                style: TextStyle(
                  fontSize: context.font(14),
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              SizedBox(height: context.rs(8)),
              TextField(
                key: const ValueKey('issue_note'),
                controller: _note,
                maxLength: 300,
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Add details that will help us resolve this faster',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: OxroColors.muted,
                  ),
                  filled: true,
                  fillColor: OxroColors.pageBg,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: OxroColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: OxroColors.primary),
                  ),
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
              Text(
                'Our support team reviews every request. Refunds and '
                'compensations are subject to verification.',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: OxroColors.muted,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: OxroColors.border)),
            ),
            child: GestureDetector(
              key: const ValueKey('issue_submit'),
              onTap: _canSubmit ? _submit : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _canSubmit ? OxroColors.primary : OxroColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Submit request',
                  style: TextStyle(
                    color: _canSubmit ? Colors.white : OxroColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contextCard(BuildContext context) {
    final order = _order;
    final title = order == null
        ? (_restaurant ?? 'Your current bag')
        : 'Order ${order.id}';
    final sub = order == null
        ? 'Before placing the order'
        : [
            if (order.kitchenName != null) order.kitchenName!,
            order.status.label,
            Money.inr(order.payablePaise),
          ].join('  |  ');
    return Container(
      key: const ValueKey('issue_context'),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OxroColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              order == null
                  ? Icons.shopping_bag_outlined
                  : Icons.receipt_long_outlined,
              color: OxroColors.primary,
              size: 21,
            ),
          ),
          SizedBox(width: context.rs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OxroColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, _IssueCategory category) {
    final selected = _selected?.id == category.id;
    return GestureDetector(
      key: ValueKey('issue_category_${category.id}'),
      onTap: () => _choose(category),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? OxroColors.primary.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? OxroColors.primary : OxroColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 16,
              color: selected ? OxroColors.primary : OxroColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? OxroColors.primary : OxroColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemChip(BuildContext context, String name, int index) {
    final selected = _items.contains(name);
    return GestureDetector(
      key: ValueKey('issue_item_$index'),
      onTap: () {
        setState(() {
          if (!_items.remove(name)) _items.add(name);
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? OxroColors.royalBlue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? OxroColors.royalBlue : OxroColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: selected ? OxroColors.royalBlue : OxroColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? OxroColors.royalBlue : OxroColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _success(BuildContext context) {
    final ticket = _ticket!;
    return Column(
      key: const ValueKey('issue_success'),
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.padX, 28, context.padX, 16),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
              ),
              SizedBox(height: context.rs(16)),
              const Text(
                'Request submitted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ticket.categoryLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OxroColors.muted,
                ),
              ),
              SizedBox(height: context.rs(16)),
              Container(
                padding: EdgeInsets.all(context.rs(14)),
                decoration: BoxDecoration(
                  color: OxroColors.pageBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OxroColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Request ID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.id,
                      key: const ValueKey('issue_ticket'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Our support team will review this and get back '
                      'within 24 hours. You can find this request under '
                      'Help & Support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: OxroColors.border)),
            ),
            child: GestureDetector(
              key: const ValueKey('issue_done'),
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: OxroColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
