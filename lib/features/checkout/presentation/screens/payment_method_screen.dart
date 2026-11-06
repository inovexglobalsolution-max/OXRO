import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/widgets/cod_smart_change_dialog.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

/// Premium Payment Methods screen — dedicated selection page inspired by
/// modern food-delivery flows. Keeps selection state in PaymentStore so
/// checkout updates instantly when navigating back.
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

  String _recommendedIcon(PaymentMethod m) => switch (m) {
    PaymentMethod.card => 'assets/images/payment_methods/visa.svg',
    PaymentMethod.wallet => 'assets/images/payment_methods/oxo_money.png',
    PaymentMethod.cod => 'assets/images/payment_methods/cod.png',
    PaymentMethod.upi => 'assets/images/payment_methods/other_upi.png',
  };

  /// COD gate: mandatory OXRO Smart Change consent before selection.
  /// Declining (or dismissing) keeps the customer on payment selection
  /// — COD is never selected without a server-confirmed activation.
  Future<void> _selectCod(BuildContext context, PaymentStore pay) async {
    HapticFeedback.selectionClick();
    // Consent already valid for the current quote → no duplicate popup.
    if (pay.hasCodSmartChange && pay.codConsentAmountPaise == pay.toPayPaise) {
      _pick(PaymentMethod.cod, 'Cash on Delivery');
      return;
    }
    final result = await showDialog<CodSmartChangeResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CodSmartChangeDialog(orderAmountPaise: pay.toPayPaise),
    );
    if (!mounted) return;
    if (result == null || !result.confirmed || result.txnId == null) return;
    pay.setCodSmartChange(
      txnId: result.txnId!,
      cashAmount: (result.cashAmountPaise ?? 0) / 100.0,
      walletCreditPaise: result.walletCreditPaise ?? 0,
      consentAmountPaise: pay.toPayPaise,
    );
    _pick(PaymentMethod.cod, 'Cash on Delivery');
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
          'Select Payment Method',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
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
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: context.padX,
                ),
                children: [
                  // Recommended — top UPI apps + previously selected method.
                  const _SectionTitle('Recommended'),
                  if (selectedLabel != 'UPI' &&
                      selectedLabel != 'Google Pay' &&
                      selectedLabel != 'PhonePe')
                    _PremiumRow(
                      iconAsset: _recommendedIcon(selectedMethod),
                      label: selectedLabel,
                      subtitle: 'Previously selected',
                      selected: true,
                      onTap: () {},
                    ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/google_pay.svg',
                    label: 'Google Pay (GPay)',
                    subtitle: 'Recommended UPI app',
                    selected: selectedLabel == 'Google Pay',
                    onTap: () => _pick(PaymentMethod.upi, 'Google Pay'),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/phonepe.svg',
                    label: 'PhonePe',
                    subtitle: 'Recommended UPI app',
                    selected: selectedLabel == 'PhonePe',
                    onTap: () => _pick(PaymentMethod.upi, 'PhonePe'),
                  ),

                  // UPI Payments
                  const _SectionTitle('UPI Payments'),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/google_pay.svg',
                    label: 'Google Pay (GPay)',
                    selected: selectedLabel == 'Google Pay',
                    onTap: () => _pick(PaymentMethod.upi, 'Google Pay'),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/phonepe.svg',
                    label: 'PhonePe',
                    selected: selectedLabel == 'PhonePe',
                    onTap: () => _pick(PaymentMethod.upi, 'PhonePe'),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/whatsapp.svg',
                    label: 'WhatsApp Pay',
                    selected: selectedLabel == 'WhatsApp Pay',
                    onTap: () => _pick(PaymentMethod.upi, 'WhatsApp Pay'),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/paytm.svg',
                    label: 'Paytm',
                    selected: selectedLabel == 'Paytm',
                    onTap: () => _pick(PaymentMethod.upi, 'Paytm'),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/other_upi.png',
                    label: 'Other UPI Apps',
                    selected: selectedLabel == 'UPI',
                    onTap: () => _pick(PaymentMethod.upi, 'UPI'),
                  ),
                  // UPI ID entry
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openUpiVerification(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEFF4FF,
                                  ).withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_circle_rounded,
                                  size: 22,
                                  color: Color(0xFF1769FF),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Enter UPI ID',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF102A43),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Verify with your UPI app',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF62758A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF62758A),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Credit & Debit Cards
                  const SizedBox(height: 8),
                  const _SectionTitle('Cards'),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/visa.svg',
                    label: 'Add Credit Card',
                    selected: selectedLabel == 'Credit Card',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CardEntryScreen(cardType: 'Credit Card'),
                      ),
                    ),
                  ),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/mastercard.svg',
                    label: 'Add Debit Card',
                    selected: selectedLabel == 'Debit Card',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CardEntryScreen(cardType: 'Debit Card'),
                      ),
                    ),
                  ),
                  // Saved Cards placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5EBF2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: Color(0xFF1769FF),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saved cards are tokenized securely '
                              'via the payment gateway.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF62758A),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Wallets
                  const SizedBox(height: 8),
                  const _SectionTitle('Wallets'),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/oxo_money.png',
                    label: 'OXO Money',
                    selected: selectedMethod == PaymentMethod.wallet,
                    subtitle:
                        'Balance ${Money.inr(WalletStore.instance.balancePaise)}',
                    onTap: () {
                      final balance = WalletStore.instance.balancePaise;
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
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/wallet.png',
                    label: 'Other Wallets',
                    selected: selectedLabel == 'Other Wallet',
                    subtitle: 'Pay via supported wallet apps',
                    onTap: () => _pick(PaymentMethod.wallet, 'Other Wallet'),
                  ),

                  // Other Payment Options
                  const SizedBox(height: 8),
                  const _SectionTitle('Other Payment Options'),
                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/bank_all.png',
                    label: 'Select Bank',
                    selected:
                        selectedMethod == PaymentMethod.upi &&
                        selectedLabel == 'Net Banking',
                    subtitle: 'Popular banks · View all',
                    onTap: () => _showNetBanking(context),
                  ),

                  _PremiumRow(
                    iconAsset: 'assets/images/payment_methods/cod.png',
                    label: 'Cash on Delivery',
                    selected: selectedMethod == PaymentMethod.cod,
                    subtitle: 'Pay with cash at delivery',
                    onTap: () => _selectCod(context, payStore),
                  ),

                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _StickyConfirm(context: context),
    );
  }

  void _openUpiVerification(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enter UPI ID',
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
                    'Enter your UPI address (e.g., yourname@upi)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF62758A)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    cursorColor: const Color(0xFFFF6A00),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'yourname@upi',
                      errorText: error,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(
                        Icons.account_circle_rounded,
                        color: Color(0xFF1769FF),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5EBF2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6A00),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _applyUpi(ctx, controller, setState),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _applyUpi(ctx, controller, setState),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyUpi(
    BuildContext ctx,
    TextEditingController c,
    StateSetter setBottomState,
  ) {
    final value = c.text.trim();
    if (value.isEmpty || !value.contains('@')) {
      setBottomState(() => '');
      return;
    }
    Navigator.of(ctx).pop();
    _pick(PaymentMethod.upi, value.isNotEmpty ? value : 'UPI');
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
          {
            'name': 'State Bank of India',
            'icon': Icons.account_balance_rounded,
          },
          {'name': 'HDFC Bank', 'icon': Icons.account_balance_rounded},
          {'name': 'ICICI Bank', 'icon': Icons.account_balance_rounded},
          {'name': 'Axis Bank', 'icon': Icons.account_balance_rounded},
          {
            'name': 'Punjab National Bank',
            'icon': Icons.account_balance_rounded,
          },
          {
            'name': 'Kotak Mahindra Bank',
            'icon': Icons.account_balance_rounded,
          },
          {'name': 'Canara Bank', 'icon': Icons.account_balance_rounded},
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
                    child: Icon(
                      b['icon'] as IconData,
                      size: 20,
                      color: const Color(0xFF1769FF),
                    ),
                  ),
                  title: Text(
                    b['name'] as String,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
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
  }
}

class _PremiumRow extends StatelessWidget {
  const _PremiumRow({
    required this.iconAsset,
    required this.label,
    required this.selected,
    this.subtitle,
    required this.onTap,
  });
  final String iconAsset;
  final String label;
  final bool selected;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                          subtitle!,
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
}

class _StickyConfirm extends StatelessWidget {
  const _StickyConfirm({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
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
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 48),
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
            ),
          ],
        ),
      ),
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
