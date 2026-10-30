import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/rating_chip.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: OxroColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          restaurant.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: OxroColors.charcoal,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.padX),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  restaurant.cuisineLabel,
                  style: const TextStyle(fontSize: 15, color: OxroColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RatingChip(rating: restaurant.rating),
                    const SizedBox(width: 12),
                    Text(
                      '${restaurant.distanceLabel} · ${restaurant.etaLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  title: 'This is a delivery-only kitchen',
                  subtitle:
                      'There are multiple brands delivering from this kitchen',
                ),
                const SizedBox(height: 8),
                _InfoTile(title: 'Live on OXRO since 2024'),
                const SizedBox(height: 16),
                _DetailRow(
                  label: 'Legal Name',
                  value: 'SAPPHIRE FOODS INDIA LIMITED',
                ),
                const SizedBox(height: 8),
                _DetailRow(label: 'GST Number', value: '33XXXXXXX1Z8'),
                const SizedBox(height: 8),
                _DetailRow(label: 'FSSAI Lic No', value: '12423018002374'),
                const SizedBox(height: 16),
                Text(
                  'Had a bad experience here?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.dark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _LinkTile(
                        title: 'Hide this restaurant',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7A3E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        'Go back to menu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delivery_dining_rounded,
                size: 18,
                color: OxroColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OxroColors.dark,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OxroColors.muted,
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 13, color: OxroColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OxroColors.dark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, color: OxroColors.muted),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.visibility_off_rounded,
              size: 18,
              color: OxroColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: OxroColors.dark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: OxroColors.muted),
          ],
        ),
      ),
    );
  }
}
