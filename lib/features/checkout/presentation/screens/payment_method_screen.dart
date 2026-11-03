import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen>
    with SingleTickerProviderStateMixin {
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
    PaymentStore.instance.select(m, label: label);
    setState(() {});
    _anim.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final pay = PaymentStore.instance;
    final selectedMethod = pay.method;
    final selectedLabel = pay.paymentLabel;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF102A43)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF102A43),
          ),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 10),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_anim),
          child: ListenableBuilder(
            listenable: PaymentStore.instance,
            builder: (context, _) {
              final payStore = PaymentStore.instance;
              return ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                children: [
                  _section('UPI Payments'),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/google_pay.svg',
                    label: 'Google Pay',
                    selected: selectedLabel == 'Google Pay',
                    onTap: () => _pick(PaymentMethod.upi, 'Google Pay'),
                  ),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/phonepe.svg',
                    label: 'PhonePe',
                    selected: selectedLabel == 'PhonePe',
                    onTap: () => _pick(PaymentMethod.upi, 'PhonePe'),
                  ),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/whatsapp.svg',
                    label: 'WhatsApp Pay',
                    selected: selectedLabel == 'WhatsApp Pay',
                    onTap: () => _pick(PaymentMethod.upi, 'WhatsApp Pay'),
                  ),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/paytm.svg',
                    label: 'Paytm',
                    selected: selectedLabel == 'Paytm',
                    onTap: () => _pick(PaymentMethod.upi, 'Paytm'),
                  ),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/other_upi.png',
                    label: 'Other UPI Apps',
                    selected: selectedLabel == 'UPI',
                    onTap: () => _pick(PaymentMethod.upi, 'UPI'),
                  ),

                  // Cards
                  _section('Credit & Debit Cards'),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/visa.svg',
                    label: 'Credit Card',
                    selected: selectedLabel == 'Credit Card',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CardEntryScreen(cardType: 'Credit Card'),
                      ),
                    ),
                  ),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/mastercard.svg',
                    label: 'Debit Card',
                    selected: selectedLabel == 'Debit Card',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CardEntryScreen(cardType: 'Debit Card'),
                      ),
                    ),
                  ),

                  // Wallet
                  _section('Wallet'),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/wallet.png',
                    label: 'OXO Money',
                    selected: selectedMethod == PaymentMethod.wallet,
                    subtitle:
                        'Balance ₹${(WalletStore.instance.balance ~/ 100)}',
                    onTap: () {
                      final balance = WalletStore.instance.balance;
                      if (balance < payStore.toPayPaise) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Insufficient wallet balance — top up',
                            ),
                          ),
                        );
                        return;
                      }
                      _pick(PaymentMethod.wallet, 'OXO Money');
                    },
                  ),

                  // Net Banking
                  _section('Net Banking'),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/bank_all.png',
                    label: 'Select Bank',
                    selected: false,
                    subtitle: 'Popular banks',
                    onTap: () => _showNetBanking(context),
                  ),

                  // COD
                  _section('Cash on Delivery'),
                  _premiumRow(
                    iconAsset: 'assets/images/payment_methods/cod.png',
                    label: 'Cash on Delivery',
                    selected: selectedMethod == PaymentMethod.cod,
                    subtitle: 'Pay with cash at delivery',
                    onTap: () => _pick(PaymentMethod.cod, 'Cash on Delivery'),
                  ),

                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _stickyConfirm(context),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
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

  Widget _premiumRow({
    required String iconAsset,
    required String label,
    required bool selected,
    String? subtitle,
    required VoidCallback onTap,
  }) {
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF6A00).withValues(alpha: 0.08)
                        : const Color(0xFFF4F7FB),
                    shape: BoxShape.circle,
                  ),
                  child: iconAsset.endsWith('.svg')
                      ? SvgPicture.asset(
                          iconAsset,
                          width: 22,
                          height: 22,
                          colorFilter: selected
                              ? const ColorFilter.mode(
                                  Color(0xFFFF6A00),
                                  BlendMode.srcIn,
                                )
                              : const ColorFilter.mode(
                                  Color(0xFF102A43),
                                  BlendMode.srcIn,
                                ),
                        )
                      : Image.asset(
                          iconAsset,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xFFFF6A00)
                              : const Color(0xFF102A43),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? const Color(0xFFE85D00)
                                : const Color(0xFF62758A),
                          ),
                        ),
                      ],
                    ],
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

  Widget _stickyConfirm(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE5EBF2))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF102A43).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selected',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFF62758A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PaymentStore.instance.paymentLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102A43),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetBanking(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final banks = [
          'State Bank of India',
          'HDFC Bank',
          'ICICI Bank',
          'Axis Bank',
          'Punjab National Bank',
          'Kotak Mahindra Bank',
          'Canara Bank',
        ];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Bank',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102A43),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Continue to your bank\'s secure page',
                style: TextStyle(fontSize: 12, color: Color(0xFF62758A)),
              ),
              const SizedBox(height: 16),
              ...banks.map(
                (b) => ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 20,
                      color: Color(0xFF1769FF),
                    ),
                  ),
                  title: Text(
                    b,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF102A43),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pick(PaymentMethod.upi, 'Net Banking');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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

  bool get _valid {
    final num = _number.text.trim();
    final exp = _expiry.text.trim();
    final cvv = _cvv.text.trim();
    return num.length >= 13 &&
        _name.text.trim().isNotEmpty &&
        exp.length == 5 &&
        exp.contains('/') &&
        cvv.length >= 3;
  }

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('${widget.cardType} Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF102A43)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter card details securely. Your information is encrypted and never stored locally.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF62758A),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _field(
              'Card Number',
              _number,
              keyboard: TextInputType.number,
              hint: '1234 5678 9012 3456',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
                LengthLimitingTextInputFormatter(19),
              ],
            ),
            _field('Cardholder Name', _name, hint: 'Your name as on card'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'Expiry (MM/YY)',
                    _expiry,
                    keyboard: TextInputType.number,
                    hint: 'MM/YY',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                      LengthLimitingTextInputFormatter(5),
                      _ExpiryFormatter(),
                    ],
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save & Continue',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool obscure = false,
    String? hint,
    TextInputType? keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF102A43),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5EBF2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5EBF2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFFF6A00),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s+'), '');
    final formatted = <String>[];
    for (var i = 0; i < text.length && i < 16; i += 4) {
      final end = (i + 4 < text.length) ? i + 4 : text.length;
      formatted.add(text.substring(i, end));
    }
    final result = formatted.join(' ');
    final offset = result.length > oldValue.text.length
        ? result.length
        : oldValue.selection.baseOffset;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, result.length),
      ),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    String result = text;
    if (text.length >= 3) {
      result = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    int offset = newValue.selection.baseOffset;
    if (result.length > oldValue.text.length && result.contains('/')) {
      offset += 1;
    }
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, result.length),
      ),
    );
  }
}
