import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/wishlist_repo.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// App-wide wishlist. Hearts in Home + Listing + Search + PDP share one
/// instance so every heart stays in sync. Local cache is the instant UI
/// layer; the backend is authoritative when reachable.
class WishlistStore extends ChangeNotifier {
  WishlistStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final WishlistStore instance = WishlistStore._();

  static const _kCache = 'oxro_wishlist_v2';

  @visibleForTesting
  static void resetForTests() {
    instance._items.clear();
    instance.notifyListeners();
  }

  /// Keyed by product id (first instance wins), insertion-ordered.
  final Map<int, Product> _items = {};
  bool _serverEmpty = false;

  /// Loads persisted wishlist (call once at splash).
  Future<void> _maybeSeedServer() async {
    if (!_serverEmpty || !CustomerIdentity.networkEnabled || _items.isEmpty) {
      _serverEmpty = false;
      return;
    }
    try {
      for (final p in _items.values) {
        await WishlistRepo().add(p.toJson());
      }
    } catch (_) {
      // Local cache remains authoritative; next sync can retry.
    } finally {
      _serverEmpty = false;
    }
  }

  Future<void> load() async {
    _serverEmpty = false;
    if (CustomerIdentity.networkEnabled) {
      try {
        final remote = await WishlistRepo().list();
        if (remote != null) {
          if (remote.isNotEmpty) {
            _items.clear();
            for (final e in remote) {
              if (e is! Map<String, dynamic>) continue;
              final product = Product.fromJson(e);
              _items[product.id] = product;
            }
            notifyListeners();
            await _persist();
            return;
          }
          // Empty server — seed it from the local cache after it loads.
          _serverEmpty = true;
        }
      } catch (_) {
        // Offline — the local cache stays authoritative.
      }
    }
    try {
      final p = await SharedPreferences.getInstance();
      if (_items.isNotEmpty) {
        await _maybeSeedServer();
        return;
      }
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) {
        await _maybeSeedServer();
        return;
      }
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final product = Product.fromJson(e as Map<String, dynamic>);
        _items[product.id] = product;
      }
      notifyListeners();
    } catch (_) {
      // Best-effort cache only.
    }
    await _maybeSeedServer();
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _kCache,
        jsonEncode([for (final v in _items.values) v.toJson()]),
      );
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  static void _sync(Future<List<dynamic>?> Function() action) {
    if (!CustomerIdentity.networkEnabled) return;
    unawaited(() async {
      try {
        await action();
      } catch (_) {
        // Best-effort sync only.
      }
    }());
  }

  void toggle(Product p) {
    final adding = !_items.containsKey(p.id);
    if (adding) {
      _items[p.id] = p;
    } else {
      _items.remove(p.id);
    }
    _changed();
    if (adding) {
      _sync(() => WishlistRepo().add(p.toJson()));
    } else {
      _sync(() => WishlistRepo().remove(p.id));
    }
  }

  void remove(int id) {
    if (_items.remove(id) != null) {
      _changed();
      _sync(() => WishlistRepo().remove(id));
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    final ids = _items.keys.toList();
    _items.clear();
    _changed();
    if (CustomerIdentity.networkEnabled) {
      for (final id in ids) {
        _sync(() => WishlistRepo().remove(id));
      }
    }
  }

  bool contains(int id) => _items.containsKey(id);

  int get count => _items.length;

  List<Product> get items => List.unmodifiable(_items.values);
}
