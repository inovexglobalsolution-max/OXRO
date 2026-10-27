import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

/// One admin change, kept for the audit log.
class PricingAuditEntry {
  const PricingAuditEntry({
    required this.version,
    required this.summary,
    required this.at,
  });

  final int version;
  final String summary;
  final DateTime at;
}

/// App-side holder for the live [PricingConfig].
///
/// Until the OXRO backend exists this is the local "admin panel": it seeds
/// the confirmed initial rates, lets tests flip them, and persists changes
/// so the whole app prices from one source. When the backend lands, [load]
/// becomes `GET /v1/pricing-config` and nothing else changes.
class PricingConfigStore extends ChangeNotifier {
  PricingConfigStore._();

  static final PricingConfigStore instance = PricingConfigStore._();

  static const _kConfig = 'oxro_pricing_config_v1';
  static const _kPromo = 'oxro_platform_fee_promo_v1';

  @visibleForTesting
  void resetForTests() {
    _config = PricingConfig.initial;
    _promoFreePlatformFee = false;
    _audit.clear();
    notifyListeners();
  }

  /// Restores the confirmed initial rates (checkout reset + fallback).
  void resetToInitial() {
    _config = PricingConfig.initial;
    _promoFreePlatformFee = false;
    notifyListeners();
  }

  PricingConfig _config = PricingConfig.initial;
  bool _promoFreePlatformFee = false;
  final List<PricingAuditEntry> _audit = [];

  PricingConfig get config => _config;

  /// Immutable admin audit log (newest first).
  List<PricingAuditEntry> get audit => List.unmodifiable(_audit);

  /// True while an admin promo runs the customer platform fee at ₹0.
  bool get promoFreePlatformFee => _promoFreePlatformFee;

  int get configVersion => _config.version;

  /// Fee actually charged to the customer right now.
  int get effectivePlatformFeePaise =>
      _promoFreePlatformFee ? 0 : _config.platformFeePaise;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _promoFreePlatformFee = p.getBool(_kPromo) ?? false;
      final raw = p.getString(_kConfig);
      if (raw != null && raw.isNotEmpty) {
        _config = PricingConfig.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
      notifyListeners();
    } catch (_) {
      // Best-effort cache; fall back to initial config.
    }
  }

  /// Applies a new config (admin edit) and bumps the version so every
  /// later order snapshots the new rates. A no-op save changes nothing.
  Future<void> apply(PricingConfig next) async {
    final diff = _diff(_config, next);
    if (diff.isEmpty) return;
    final bumped = next.copyWith(version: _config.version + 1);
    bumped.validate();
    _config = bumped;
    _record(bumped.version, diff.join(', '));
    notifyListeners();
    await _persist();
  }

  Future<void> setPromoFreePlatformFee(bool on) async {
    if (_promoFreePlatformFee == on) return;
    _promoFreePlatformFee = on;
    _record(_config.version,
        on ? 'Platform fee promo ON (₹0)' : 'Platform fee promo OFF');
    notifyListeners();
    await _persist();
  }

  void _record(int version, String summary) {
    _audit.insert(
      0,
      PricingAuditEntry(
          version: version, summary: summary, at: DateTime.now()),
    );
    if (_audit.length > 50) _audit.removeLast();
  }

  static List<String> _diff(PricingConfig a, PricingConfig b) {
    final out = <String>[];
    void chk(String name, num x, num y, {bool percent = false}) {
      if (x != y) {
        out.add(percent
            ? '$name ${(x / 100).toStringAsFixed(2)}% → ${(y / 100).toStringAsFixed(2)}%'
            : '$name $x → $y');
      }
    }

    chk('Commission', a.commissionBps, b.commissionBps,
        percent: true);
    chk('Platform fee', a.platformFeePaise, b.platformFeePaise);
    chk('Delivery fee', a.customerDeliveryFeePaise,
        b.customerDeliveryFeePaise);
    chk('GST', a.customerGstBps, b.customerGstBps, percent: true);
    chk('Commission GST', a.commissionGstBps, b.commissionGstBps,
        percent: true);
    chk('TDS', a.tdsBps, b.tdsBps, percent: true);
    chk('Base payout', a.basePayoutPaise, b.basePayoutPaise);
    chk('Included distance', a.includedDistanceMetres,
        b.includedDistanceMetres);
    chk('Per km', a.perKmPaise, b.perKmPaise);
    chk('Stacking bonus', a.stackingBonusPaise, b.stackingBonusPaise);
    chk('Waiting comp/min', a.waitingCompPerMinutePaise,
        b.waitingCompPerMinutePaise);
    return out;
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kConfig, jsonEncode(_config.toJson()));
      await p.setBool(_kPromo, _promoFreePlatformFee);
    } catch (_) {
      // Best-effort cache only.
    }
  }
}
