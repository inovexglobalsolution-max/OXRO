import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/profile_repo.dart';

/// OXRO PREMIUM membership (mock, persisted on device).
/// Backend subscription billing replaces this later.
class PremiumStore extends ChangeNotifier {
  PremiumStore._();

  static final PremiumStore instance = PremiumStore._();

  /// Cart value (rupees) needed for the member free-delivery benefit.
  static const freeDeliveryMinOrder = 199;

  static const _kCache = 'oxro_premium_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._isMember = false;
    instance._joinedAt = null;
    instance.notifyListeners();
  }

  bool _isMember = false;
  DateTime? _joinedAt;

  bool get isMember => _isMember;

  DateTime? get joinedAt => _joinedAt;

  /// Loads persisted membership (call once at splash).
  Future<void> load() async {
    if (CustomerIdentity.networkEnabled) {
      try {
        final remote = await ProfileRepo().fetchPremium();
        if (remote != null) {
          final isMember = (remote['isMember'] as bool?) ?? false;
          if (isMember) {
            _isMember = true;
            final joined = remote['joinedAt'];
            _joinedAt = joined is String
                ? DateTime.tryParse(joined)
                : _joinedAt;
            notifyListeners();
            await _persist();
            return;
          }
        }
      } catch (_) {
        // Offline — the local membership stays authoritative.
      }
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _isMember = (m['isMember'] as bool?) ?? false;
      final joined = m['joinedAt'];
      _joinedAt = joined is String ? DateTime.tryParse(joined) : null;
      notifyListeners();
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _kCache,
        jsonEncode({
          'isMember': _isMember,
          'joinedAt': _joinedAt?.toIso8601String(),
        }),
      );
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void join() {
    if (_isMember) return;
    _isMember = true;
    _joinedAt = DateTime.now();
    notifyListeners();
    _persist();
    if (CustomerIdentity.networkEnabled) {
      unawaited(() async {
        try {
          await ProfileRepo().joinPremium();
        } catch (_) {
          // Best-effort sync only.
        }
      }());
    }
  }

  void cancel() {
    if (!_isMember) return;
    _isMember = false;
    _joinedAt = null;
    notifyListeners();
    _persist();
    if (CustomerIdentity.networkEnabled) {
      unawaited(() async {
        try {
          await ProfileRepo().cancelPremium();
        } catch (_) {
          // Best-effort sync only.
        }
      }());
    }
  }
}
