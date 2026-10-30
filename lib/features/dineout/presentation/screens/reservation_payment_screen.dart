import 'package:flutter/material.dart';
import 'package:oxro/app/theme/app_colors.dart';

class ReservationPaymentScreen extends StatelessWidget {
  const ReservationPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OxroColors.premiumCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reservation Fee',
                style: TextStyle(fontSize: 14, color: OxroColors.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                '₹7',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: OxroColors.charcoal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your table is held for 16 min. No prepayment needed.',
                style: TextStyle(fontSize: 12, color: OxroColors.muted),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OxroColors.coral,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Pay ₹7 & Confirm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
