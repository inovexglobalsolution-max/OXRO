import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/dineout/data/reservation_payment.dart';

/// Reservation confirmation — Razorpay ₹7.00 platform fee.
/// Online payment only (GPay/PhonePe/UPI/cards/netbanking); COD blocked.
class ReservationPaymentScreen extends StatefulWidget {
  const ReservationPaymentScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.guests,
    required this.slot,
  });

  final String restaurantId;
  final String restaurantName;
  final int guests;
  final String slot;

  @override
  State<ReservationPaymentScreen> createState() =>
      _ReservationPaymentScreenState();
}

class _ReservationPaymentScreenState extends State<ReservationPaymentScreen> {
  bool _processing = false;

  Future<void> _pay() async {
    if (_processing) return;
    if (!ReservationPayment.canAttemptPayment) {
      showOxroSnack(context, 'Payment unavailable offline');
      return;
    }
    setState(() => _processing = true);
    try {
      final result = await ReservationPayment.run(
        restaurantId: widget.restaurantId,
        guests: widget.guests,
        slot: widget.slot,
      );
      if (!mounted) return;
      switch (result.status) {
        case ReservationPaymentStatus.success:
          showOxroSnack(
            context,
            'Reservation confirmed — table for ${widget.guests} at ${widget.slot}',
          );
          Navigator.of(context).pop(result);
          break;
        case ReservationPaymentStatus.cancelled:
          showOxroSnack(context, 'Payment cancelled');
          break;
        case ReservationPaymentStatus.pending:
          showOxroSnack(
            context,
            result.message ?? 'Payment is being confirmed',
          );
          break;
        case ReservationPaymentStatus.failed:
        case ReservationPaymentStatus.error:
          showOxroSnack(context, result.message ?? 'Payment failed');
          break;
        case ReservationPaymentStatus.offline:
          showOxroSnack(context, 'Payment unavailable offline');
          break;
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('reservation_payment_screen'),
      backgroundColor: OxroColors.premiumCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('reservation_back'),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: OxroColors.charcoal,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Confirm Reservation',
          style: TextStyle(
            color: OxroColors.charcoal,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Restaurant + reservation details.
              Container(
                key: const ValueKey('reservation_details'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OxroColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurantName.toUpperCase(),
                      key: const ValueKey('reservation_restaurant_name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: OxroColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 18,
                          color: OxroColors.royalBlue,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.guests} guests • ${widget.slot}',
                          key: const ValueKey('reservation_guests_slot'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Billing — Reservation Platform Fee ₹7.00 only.
              const Text(
                'Reservation Platform Fee',
                key: ValueKey('reservation_fee_title'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your ticket platform fee is ₹7',
                style: TextStyle(fontSize: 12, color: OxroColors.muted),
              ),
              const SizedBox(height: 16),
              _BillRow(label: 'Platform Fee for Reservation', value: '₹7.00'),
              const Divider(height: 24, color: OxroColors.border),
              _BillRow(
                label: 'Total Amount',
                value: '₹7.00',
                bold: true,
                key: const ValueKey('reservation_total'),
              ),
              const SizedBox(height: 24),
              const Spacer(),
              // Online payment methods only — COD never shown.
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: OxroColors.muted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Online payment only — GPay · PhonePe · UPI · Cards · NetBanking',
                    style: TextStyle(fontSize: 11, color: OxroColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  key: const ValueKey('reservation_pay_button'),
                  onPressed: _processing ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OxroColors.coral,
                    disabledBackgroundColor: OxroColors.coral.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Pay ₹7 & Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
    super.key,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 13.5,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      color: bold ? OxroColors.charcoal : OxroColors.muted,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
