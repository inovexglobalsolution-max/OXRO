import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/wallet_repo.dart';

/// One wallet ledger entry.
class WalletTx {
  const WalletTx({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    this.amountPaise,
  });

  /// Positive = credit, negative = debit (whole rupees, legacy display).
  final String id;
  final String label;
  final int amount;
  final DateTime date;

  /// Exact signed paise for this entry when it carries sub-rupee precision
  /// (e.g. Smart Change credits). Null for whole-rupee entries.
  final int? amountPaise;
}

/// OXRO Money (mock, in-memory).
/// Balance is stored in paise for exact Smart Change credits; the legacy
/// [balance] getter keeps returning whole rupees for existing callers.
class WalletStore extends ChangeNotifier {
  WalletStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final WalletStore instance = WalletStore._();

  static const _kCache = 'oxro_wallet_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._balancePaise = 0;
    instance._txs.clear();
    instance._serverBacked = false;
    instance.notifyListeners();
  }

  int _balancePaise = 0;
  final List<WalletTx> _txs = [];

  /// True once the ledger was loaded from the backend. In that mode the
  /// server already contains Smart Change credits, so the client applier
  /// must not add them again.
  bool _serverBacked = false;

  bool get serverBacked => _serverBacked;

  /// Whole rupees (legacy callers, pills, tests).
  int get balance => _balancePaise ~/ 100;

  /// Exact balance in paise (Smart Change precision).
  int get balancePaise => _balancePaise;

  List<WalletTx> get txs => List.unmodifiable(_txs);

  /// Loads the ledger (call once at splash). The server is authoritative
  /// when reachable; SharedPreferences is the offline fallback.
  Future<void> load() async {
    if (CustomerIdentity.networkEnabled) {
      try {
        final ledger = await WalletRepo().fetchLedger();
        if (ledger != null) {
          _balancePaise = (ledger['balancePaise'] as num?)?.toInt() ?? 0;
          _txs.clear();
          for (final e
              in (ledger['transactions'] is List
                  ? ledger['transactions'] as List
                  : const [])) {
            if (e is! Map<String, dynamic>) continue;
            final createdAt = e['createdAt'];
            _txs.add(
              WalletTx(
                id: (e['id'] as String?) ?? '',
                label: (e['label'] as String?) ?? '',
                amount: ((e['amountPaise'] as num?)?.toInt() ?? 0) ~/ 100,
                amountPaise: (e['amountPaise'] as num?)?.toInt(),
                date: createdAt is String
                    ? DateTime.tryParse(createdAt) ?? DateTime.now()
                    : DateTime.now(),
              ),
            );
          }
          _serverBacked = true;
          await _persist();
          notifyListeners();
          return;
        }
      } catch (_) {
        // Offline — use the local cache.
      }
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final legacy = (m['balance'] as num?)?.toInt();
      _balancePaise =
          (m['balancePaise'] as num?)?.toInt() ?? ((legacy ?? 0) * 100);
      _txs.clear();
      for (final e in (m['txs'] is List ? m['txs'] as List : const [])) {
        final t = e as Map<String, dynamic>;
        final date = t['date'];
        _txs.add(
          WalletTx(
            id: (t['id'] as String?) ?? '',
            label: (t['label'] as String?) ?? '',
            amount: (t['amount'] as num?)?.toInt() ?? 0,
            amountPaise: (t['amountPaise'] as num?)?.toInt(),
            date: date is String
                ? DateTime.tryParse(date) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
      }
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
          'balance': _balancePaise ~/ 100, // legacy key (rupees)
          'balancePaise': _balancePaise,
          'txs': [
            for (final t in _txs.take(50))
              {
                'id': t.id,
                'label': t.label,
                'amount': t.amount,
                'amountPaise': t.amountPaise,
                'date': t.date.toIso8601String(),
              },
          ],
        }),
      );
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  /// Adds money (mock UPI top-up). Amount must be > 0 rupees.
  void add(int amount, {String label = 'Wallet top-up'}) {
    if (amount <= 0) return;
    _balancePaise += amount * 100;
    _txs.insert(
      0,
      WalletTx(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        amount: amount,
        date: DateTime.now(),
      ),
    );
    _changed();
  }

  /// Credits an exact paise amount (Smart Change wallet credit).
  /// [txnId] makes the credit idempotent — a repeat of the same
  /// transaction never credits twice. Returns false when skipped.
  bool addPaise(int paise, {String label = 'Wallet credit', String? txnId}) {
    if (paise <= 0) return false;
    if (txnId != null && txnId.isNotEmpty) {
      final applied = _txs.any((t) => t.id == txnId);
      if (applied) return false; // duplicate credit guard
    }
    _balancePaise += paise;
    _txs.insert(
      0,
      WalletTx(
        id: txnId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        amount: paise ~/ 100,
        amountPaise: paise,
        date: DateTime.now(),
      ),
    );
    _changed();
    return true;
  }

  /// Pays from wallet. Returns false when insufficient.
  bool deduct(int amount, {String label = 'Order payment'}) {
    if (amount <= 0) return false;
    if (_balancePaise < amount * 100) return false;
    _balancePaise -= amount * 100;
    _txs.insert(
      0,
      WalletTx(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        amount: -amount,
        date: DateTime.now(),
      ),
    );
    _changed();
    return true;
  }

  /// Pays an exact paise bill — debited to the paisе, no rounding.
  bool deductPaise(int paise, {String label = 'Order payment'}) {
    if (paise <= 0) return false;
    if (_balancePaise < paise) return false;
    _balancePaise -= paise;
    _txs.insert(
      0,
      WalletTx(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        amount: -(paise ~/ 100),
        amountPaise: -paise,
        date: DateTime.now(),
      ),
    );
    _changed();
    return true;
  }
}
