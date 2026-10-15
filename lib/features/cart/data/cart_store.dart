import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/home/data/home_data.dart';

/// One cart row.
class CartLine {
  CartLine({required this.product, required this.qty});
  final Product product;
  int qty;
}

/// App-wide cart (mock, in-memory).
/// Screens share one instance so Home + Listing + PDP stay in sync.
/// Backend cart replaces this later. Riverpod migration noted then.
class CartStore extends ChangeNotifier {
  CartStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final CartStore instance = CartStore._();

  static const _kCache = 'oxro_cart_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._lines.clear();
    instance.notifyListeners();
  }

  final Map<int, CartLine> _lines = {};

  /// Loads persisted bag (call once at splash; corrupt cache → empty).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final product =
            Product.fromJson(m['product'] as Map<String, dynamic>);
        final qty = (m['qty'] as num?)?.toInt() ?? 1;
        if (qty > 0) {
          _lines[product.id] =
              CartLine(product: product, qty: qty.clamp(1, 99));
        }
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
          jsonEncode([
            for (final l in _lines.values)
              {'qty': l.qty, 'product': l.product.toJson()},
          ]));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  void add(Product p) {
    final line = _lines[p.id];
    if (line == null) {
      _lines[p.id] = CartLine(product: p, qty: 1);
    } else {
      line.qty++;
    }
    _changed();
  }

  void increment(int id) {
    final line = _lines[id];
    if (line == null) return;
    line.qty++;
    _changed();
  }

  void decrement(int id) {
    final line = _lines[id];
    if (line == null) return;
    line.qty--;
    if (line.qty <= 0) _lines.remove(id);
    _changed();
  }

  void remove(int id) {
    if (_lines.remove(id) != null) _changed();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _changed();
  }

  int qty(int id) => _lines[id]?.qty ?? 0;

  bool contains(int id) => _lines.containsKey(id);

  /// Total units (bag badge).
  int get count =>
      _lines.values.fold(0, (sum, l) => sum + l.qty);

  /// Distinct products.
  int get distinct => _lines.length;

  int get totalMrp =>
      _lines.values.fold(0, (s, l) => s + l.product.mrp * l.qty);

  int get totalPrice =>
      _lines.values.fold(0, (s, l) => s + l.product.price * l.qty);

  int get savings => totalMrp - totalPrice;

  List<CartLine> get lines =>
      List.unmodifiable(_lines.values);
}
