import 'package:flutter/material.dart';
import 'package:oxro/app/theme/app_colors.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, this.selectedMethod});
  final String? selectedMethod;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2ED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: OxroColors.charcoal),
          onPressed: () => Navigator.pop(context, _selected),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: OxroColors.charcoal,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('UPI Payments'),
            _payTile(
              'Google Pay (GPay)',
              Icons.account_balance_wallet_rounded,
              'upi_google',
              isSelect: true,
            ),
            _payTile('PhonePe', Icons.phone_android_rounded, 'upi_phonepe'),
            _payTile('WhatsApp Pay', Icons.chat_rounded, 'upi_whatsapp'),
            _payTile('Other UPI Apps', Icons.apps_rounded, 'upi_other'),
            const SizedBox(height: 12),
            _sectionTitle('Credit & Debit Cards'),
            _payTile('Credit Card', Icons.credit_card_rounded, 'card_credit'),
            _payTile('Debit Card', Icons.credit_card_rounded, 'card_debit'),
            const SizedBox(height: 12),
            _sectionTitle('Wallets'),
            _payTile(
              'OXO Money',
              Icons.account_balance_wallet_rounded,
              'wallet_oxo',
              balance: '₹1,250',
            ),
            const SizedBox(height: 12),
            _sectionTitle('Net Banking'),
            _payTile('Select Bank', Icons.account_balance_rounded, 'net_bank'),
            const SizedBox(height: 12),
            _sectionTitle('Cash on Delivery'),
            _payTile('Cash on Delivery', Icons.money_rounded, 'cod'),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: OxroColors.border)),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _selected ?? 'upi_google');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OxroColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Confirm Payment Method',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: OxroColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _payTile(
    String label,
    IconData icon,
    String key, {
    bool isSelect = false,
    String? balance,
  }) {
    final selected = _selected == key;
    return GestureDetector(
      onTap: () => setState(() => _selected = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? OxroColors.green.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? OxroColors.green : OxroColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: selected
                  ? OxroColors.green.withValues(alpha: 0.15)
                  : OxroColors.pageBg,
              child: Icon(
                icon,
                color: selected ? OxroColors.green : OxroColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  if (balance != null)
                    Text(
                      balance,
                      style: TextStyle(fontSize: 12, color: OxroColors.muted),
                    ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: OxroColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: OxroColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
