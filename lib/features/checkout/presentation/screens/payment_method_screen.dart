import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/features/checkout/data/payment_store.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen>
    with SingleTickerProviderStateMixin {
  String _label = PaymentStore.instance.paymentLabel;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _pick(PaymentMethod m, String label) {
    HapticFeedback.selectionClick();
    setState(() => _label = label);
    PaymentStore.instance.select(m, label: label);
    _anim.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF102A43),
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF102A43)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 12),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_anim),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            children: [
              _section('UPI Payments'),
              _premiumRow(
                Icons.account_balance_wallet_rounded,
                'Google Pay',
                () => _pick(PaymentMethod.upi, 'Google Pay'),
                _label == 'Google Pay',
              ),
              _premiumRow(
                Icons.account_balance_wallet_rounded,
                'PhonePe',
                () => _pick(PaymentMethod.upi, 'PhonePe'),
                _label == 'PhonePe',
              ),
              _premiumRow(
                Icons.chat_bubble_rounded,
                'WhatsApp Pay',
                () => _pick(PaymentMethod.upi, 'WhatsApp Pay'),
                _label == 'WhatsApp Pay',
              ),
              _premiumRow(
                Icons.qr_code_rounded,
                'Other UPI',
                () => _pick(PaymentMethod.upi, 'UPI'),
                _label == 'UPI',
              ),
              _section('Wallet'),
              _premiumRow(
                Icons.wallet_rounded,
                'OXRO Money',
                () => _pick(PaymentMethod.wallet, 'OXRO Money'),
                _label == 'OXRO Money',
              ),
              _section('Cards'),
              _premiumRow(
                Icons.credit_card_rounded,
                'Credit Card',
                () => _openCardEntry('Credit Card'),
                _label == 'Credit Card',
              ),
              _premiumRow(
                Icons.credit_card_rounded,
                'Debit Card',
                () => _openCardEntry('Debit Card'),
                _label == 'Debit Card',
              ),
              _section('Cash'),
              _premiumRow(
                Icons.money_rounded,
                'Cash on Delivery',
                () => _pick(PaymentMethod.cod, 'Cash on Delivery'),
                _label == 'Cash on Delivery',
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 0.8,
        color: Color(0xFF62758A),
      ),
    ),
  );

  Widget _premiumRow(
    IconData icon,
    String label,
    VoidCallback onTap,
    bool selected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFFFF7F1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: selected ? 2 : 0,
        shadowColor: selected
            ? const Color(0xFFFF6A00).withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF6A00).withValues(alpha: 0.1)
                        : const Color(0xFFF4F7FB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? const Color(0xFFFF6A00)
                        : const Color(0xFF102A43),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFFFF6A00)
                          : const Color(0xFF102A43),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected
                      ? Container(
                          key: const ValueKey('check'),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        )
                      : const SizedBox(
                          width: 22,
                          height: 22,
                          key: ValueKey('empty'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCardEntry(String type) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CardEntryScreen(cardType: type)));
  }
}

class CardEntryScreen extends StatefulWidget {
  const CardEntryScreen({super.key, required this.cardType});
  final String cardType;

  @override
  State<CardEntryScreen> createState() => _CardEntryScreenState();
}

class _CardEntryScreenState extends State<CardEntryScreen> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  bool get _valid =>
      _number.text.trim().length >= 13 &&
      _name.text.trim().isNotEmpty &&
      _expiry.text.trim().isNotEmpty &&
      _cvv.text.trim().length >= 3;

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('${widget.cardType} Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(
            'Card Number',
            _number,
            keyboard: TextInputType.number,
            hint: '1234 5678 9012 3456',
          ),
          _field('Cardholder Name', _name, hint: 'Your name as on card'),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Expiry (MM/YY)',
                  _expiry,
                  keyboard: TextInputType.number,
                  hint: 'MM / YY',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'CVV',
                  _cvv,
                  keyboard: TextInputType.number,
                  hint: '123',
                  obscure: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _valid
                ? () {
                    Navigator.of(context).pop();
                    PaymentStore.instance.select(
                      PaymentMethod.card,
                      label: widget.cardType,
                    );
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save & Continue',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool obscure = false,
    String? hint,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: Color(0xFF102A43),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5EBF2)),
            ),
          ),
        ),
      ],
    ),
  );
}
