import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One wallet ledger entry.
class WalletTx {
  const WalletTx({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
  });

  /// Positive = credit, negative = debit.
  final String id;
  final String label;
  final int amount;
  final DateTime date;
}

/// OXRO Money (mock, in-memory).
/// Backend ledger replaces this later.
class WalletStore extends ChangeNotifier {
  WalletStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final WalletStore instance = WalletStore._();

  static const _kCache = 'oxro_wallet_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._balance = 0;
    instance._txs.clear();
    instance.notifyListeners();
  }

  int _balance = 0;
  final List<WalletTx> _txs = [];

  int get balance => _balance;

  List<WalletTx> get txs => List.unmodifiable(_txs);

  /// Loads persisted balance + ledger (call once at splash).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _balance = (m['balance'] as num?)?.toInt() ?? 0;
      _txs.clear();
      for (final e in (m['txs'] is List ? m['txs'] as List : const [])) {
        final t = e as Map<String, dynamic>;
        final date = t['date'];
        _txs.add(
          WalletTx(
            id: (t['id'] as String?) ?? '',
            label: (t['label'] as String?) ?? '',
            amount: (t['amount'] as num?)?.toInt() ?? 0,
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
          'balance': _balance,
          'txs': [
            for (final t in _txs.take(50))
              {
                'id': t.id,
                'label': t.label,
                'amount': t.amount,
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

  /// Adds money (mock UPI top-up). Amount must be > 0.
  void add(int amount, {String label = 'Wallet top-up'}) {
    if (amount <= 0) return;
    _balance += amount;
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

  /// Pays from wallet. Returns false when insufficient.
  bool deduct(int amount, {String label = 'Order payment'}) {
    if (amount <= 0) return false;
    if (_balance < amount) return false;
    _balance -= amount;
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

  /// Pays an exact paise bill. Wallet balances are whole rupees, so the
  /// debit is rounded up to avoid undercharging a fraction of a rupee.
  bool deductPaise(int paise, {String label = 'Order payment'}) {
    if (paise <= 0) return false;
    final rupees = (paise + 99) ~/ 100;
    return deduct(rupees, label: label);
  }
}
