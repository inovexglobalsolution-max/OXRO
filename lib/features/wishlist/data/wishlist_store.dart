import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/home/data/home_data.dart';

/// App-wide wishlist (mock, in-memory).
/// Hearts in Home + Listing + Search + PDP share one instance so
/// every heart stays in sync. Backend wishlist replaces this later.
class WishlistStore extends ChangeNotifier {
  WishlistStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final WishlistStore instance = WishlistStore._();

  static const _kCache = 'oxro_wishlist_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._items.clear();
    instance.notifyListeners();
  }

  /// Keyed by product id (first instance wins), insertion-ordered.
  final Map<int, Product> _items = {};

  /// Loads persisted wishlist (call once at splash).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final product = Product.fromJson(e as Map<String, dynamic>);
        _items[product.id] = product;
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
          jsonEncode(
              [for (final v in _items.values) v.toJson()]));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  void toggle(Product p) {
    if (_items.containsKey(p.id)) {
      _items.remove(p.id);
    } else {
      _items[p.id] = p;
    }
    _changed();
  }

  void remove(int id) {
    if (_items.remove(id) != null) _changed();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _changed();
  }

  bool contains(int id) => _items.containsKey(id);

  int get count => _items.length;

  List<Product> get items => List.unmodifiable(_items.values);
}
