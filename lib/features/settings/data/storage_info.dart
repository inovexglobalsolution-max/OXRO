import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// On-device storage breakdown (demo meter; backend data excluded).
class StorageBreakdown {
  const StorageBreakdown({
    required this.prefsBytes,
    required this.imageBytes,
    required this.cartLines,
    required this.wishlistItems,
    required this.orderCount,
    required this.recentCount,
    required this.walletTxs,
  });

  final int prefsBytes;
  final int imageBytes;
  final int cartLines;
  final int wishlistItems;
  final int orderCount;
  final int recentCount;
  final int walletTxs;

  int get totalBytes => prefsBytes + imageBytes;

  /// 50 MB demo budget.
  static const budgetBytes = 50 * 1024 * 1024;

  double get fraction =>
      (totalBytes / budgetBytes).clamp(0.0, 1.0);

  static String human(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Measures prefs bytes + live image cache + store counts.
class StorageInfo {
  static int _valueLen(Object? v) {
    if (v is String) return v.length * 2;
    if (v is List<String>) {
      return v.fold(0, (s, e) => s + e.length * 2);
    }
    if (v is int || v is double) return 8;
    if (v is bool) return 1;
    return 16;
  }

  static Future<StorageBreakdown> collect() async {
    var prefsBytes = 0;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys()) {
        prefsBytes += k.length * 2 + _valueLen(p.get(k));
      }
    } catch (_) {
      // Prefs unavailable — meter shows images only.
    }
    final imageBytes =
        PaintingBinding.instance.imageCache.currentSizeBytes;
    return StorageBreakdown(
      prefsBytes: prefsBytes,
      imageBytes: imageBytes,
      cartLines: CartStore.instance.lines.length,
      wishlistItems: WishlistStore.instance.count,
      orderCount: OrderStore.instance.all.length,
      recentCount: SearchRepo.recents.length,
      walletTxs: WalletStore.instance.txs.length,
    );
  }

  /// Clears decoded images (safe: re-decoded on demand).
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
