import 'package:flutter/material.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';

/// Admin console mock-up: the single place rates are edited.
///
/// Saving calls [PricingConfigStore.apply], which bumps the config version
/// and records an audit entry. Every order placed afterwards snapshots the
/// new version, so edits never rewrite past bills.
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  late PricingConfig _draft;
  late bool _promo;

  @override
  void initState() {
    super.initState();
    final s = PricingConfigStore.instance;
    _draft = s.config;
    _promo = s.promoFreePlatformFee;
  }

  void _save() {
    PricingConfigStore.instance.apply(_draft);
    PricingConfigStore.instance.setPromoFreePlatformFee(_promo);
    showOxroSnack(
        context, 'Pricing saved · v${_draft.version + 1}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final live = PricingConfigStore.instance;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Admin · Pricing',
            style: TextStyle(
                color: OxroColors.charcoal,
                fontWeight: FontWeight.w800)),
        iconTheme:
            const IconThemeData(color: OxroColors.charcoal),
      ),
      body: ListView(
        key: const ValueKey('admin_pricing_scroll'),
        padding: EdgeInsets.fromLTRB(
            context.padX, 8, context.padX, 24),
        children: [
          _versionPill(context, live),
          SizedBox(height: context.rs(12)),
          _sectionTitle('CUSTOMER FEES'),
          _sliderCard(
            label: 'Platform fee',
            value: _draft.platformFeePaise,
            min: 0,
            max: 2000,
            step: 100,
            display: '₹${_draft.platformFeePaise ~/ 100}',
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(
                    platformFeePaise: v)),
          ),
          SwitchListTile(
            key: const ValueKey('admin_promo'),
            value: _promo,
            activeThumbColor: OxroColors.primary,
            contentPadding: EdgeInsets.zero,
            title: const Text('₹0 platform fee promo',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: const Text('Charges customers ₹0 while active',
                style: TextStyle(fontSize: 12)),
            onChanged: (v) => setState(() => _promo = v),
          ),
          _sliderCard(
            label: 'Delivery fee (per restaurant)',
            value: _draft.customerDeliveryFeePaise,
            min: 0,
            max: 10000,
            step: 500,
            display:
                '₹${_draft.customerDeliveryFeePaise ~/ 100}',
            onChanged: (v) => setState(() =>
                _draft = _draft.copyWith(
                    customerDeliveryFeePaise: v)),
          ),
          _sliderCard(
            label: 'Customer GST',
            value: _draft.customerGstBps,
            min: 0,
            max: 2800,
            step: 100,
            display:
                '${(_draft.customerGstBps / 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(
                () => _draft = _draft.copyWith(customerGstBps: v)),
          ),
          SizedBox(height: context.rs(12)),
          _sectionTitle('SELLER COMMISSION'),
          _sliderCard(
            label: 'Commission',
            value: _draft.commissionBps,
            min: 0,
            max: 3000,
            step: 50,
            display:
                '${(_draft.commissionBps / 100).toStringAsFixed(2)}%',
            onChanged: (v) => setState(
                () => _draft = _draft.copyWith(commissionBps: v)),
          ),
          _sliderCard(
            label: 'GST on commission',
            value: _draft.commissionGstBps,
            min: 0,
            max: 2800,
            step: 100,
            display:
                '${(_draft.commissionGstBps / 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _draft =
                _draft.copyWith(commissionGstBps: v)),
          ),
          _sliderCard(
            label: 'TDS (194-O)',
            value: _draft.tdsBps,
            min: 0,
            max: 1000,
            step: 50,
            display:
                '${(_draft.tdsBps / 100).toStringAsFixed(2)}%',
            onChanged: (v) => setState(
                () => _draft = _draft.copyWith(tdsBps: v)),
          ),
          SizedBox(height: context.rs(12)),
          _sectionTitle('DELIVERY PARTNER PAYOUT'),
          _sliderCard(
            label: 'Base payout',
            value: _draft.basePayoutPaise,
            min: 0,
            max: 10000,
            step: 100,
            display: '₹${_draft.basePayoutPaise ~/ 100}',
            onChanged: (v) => setState(
                () => _draft = _draft.copyWith(basePayoutPaise: v)),
          ),
          _sliderCard(
            label: 'Included distance',
            value: _draft.includedDistanceMetres,
            min: 0,
            max: 10000,
            step: 500,
            display:
                '${(_draft.includedDistanceMetres / 1000).toStringAsFixed(1)} km',
            onChanged: (v) => setState(() => _draft =
                _draft.copyWith(includedDistanceMetres: v)),
          ),
          _sliderCard(
            label: 'Per km beyond included',
            value: _draft.perKmPaise,
            min: 0,
            max: 3000,
            step: 100,
            display: '₹${_draft.perKmPaise ~/ 100}',
            onChanged: (v) => setState(
                () => _draft = _draft.copyWith(perKmPaise: v)),
          ),
          _sliderCard(
            label: 'Stacked order bonus',
            value: _draft.stackingBonusPaise,
            min: 0,
            max: 3000,
            step: 100,
            display: '₹${_draft.stackingBonusPaise ~/ 100}',
            onChanged: (v) => setState(() => _draft =
                _draft.copyWith(stackingBonusPaise: v)),
          ),
          SizedBox(height: context.rs(16)),
          GestureDetector(
            key: const ValueKey('admin_save'),
            onTap: _save,
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: OxroColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Save pricing',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(height: context.rs(20)),
          _sectionTitle('AUDIT LOG'),
          if (live.audit.isEmpty)
            const Text('No changes yet.',
                style: TextStyle(
                    fontSize: 13, color: OxroColors.muted))
          else
            for (final a in live.audit)
              _auditRow(a),
        ],
      ),
    );
  }

  Widget _versionPill(BuildContext context, PricingConfigStore live) {
    return Container(
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: OxroColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live config v${live.config.version}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                Text(
                    'Every order snapshots the config used at checkout.',
                    style: const TextStyle(
                        fontSize: 12, color: OxroColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: OxroColors.muted,
                letterSpacing: 1.1)),
      );

  Widget _sliderCard({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required String display,
    required ValueChanged<int> onChanged,
  }) {
    final divisions = ((max - min) ~/ step).clamp(1, 200);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600))),
              Text(display,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.primary)),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(
                min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            activeColor: OxroColors.primary,
            onChanged: (v) => onChanged(
                (v / step).round() * step),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(PricingAuditEntry a) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: OxroColors.pageBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OxroColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: OxroColors.royalBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('v${a.version}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.royalBlue)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a.summary,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}
