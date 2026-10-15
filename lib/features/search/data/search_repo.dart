import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/categories/data/category_tree.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';

/// 09 Search index — one bounded global pool over the mock catalogue.
/// Matches query against product name + brand + leaf / group / tab /
/// category names. Pure + unit-testable (no BuildContext).
class SearchHit {
  const SearchHit({required this.product, required this.leaf});

  final Product product;
  final String leaf;
}

class _Entry {
  const _Entry({
    required this.product,
    required this.haystack,
    required this.nameMatch,
  });

  final Product product;
  final String haystack;
  final bool nameMatch;
}

/// Result sort orders for the filter bar.
enum SearchSort { relevance, priceLow, priceHigh, rating, discount }

const searchSortLabels = {
  SearchSort.relevance: 'Relevance',
  SearchSort.priceLow: 'Price: Low to High',
  SearchSort.priceHigh: 'Price: High to Low',
  SearchSort.rating: 'Rating',
  SearchSort.discount: 'Discount',
};

class SearchRepo {
  /// Recent searches (persisted; max 8, most-recent-first).
  static const maxRecents = 8;
  static const _kRecents = 'oxro_recents';
  static final List<String> recents = [];

  /// Loads persisted recents (call in SearchScreen init).
  static Future<void> loadRecents() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_kRecents) ?? const [];
      recents
        ..clear()
        ..addAll(saved.take(maxRecents));
    } catch (_) {
      // Prefs unavailable (older installs) — stay in-memory.
    }
  }

  static Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kRecents, List.of(recents));
    } catch (_) {
      // Prefs unavailable in some test shells — stay in-memory.
    }
  }

  static void _persistRecents() {
    unawaited(_persist());
  }

  static void pushRecent(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    recents.removeWhere(
        (r) => r.toLowerCase() == query.toLowerCase());
    recents.insert(0, query);
    if (recents.length > maxRecents) {
      recents.removeRange(maxRecents, recents.length);
    }
    _persistRecents();
  }

  static void removeRecentAt(int i) {
    if (i < 0 || i >= recents.length) return;
    recents.removeAt(i);
    _persistRecents();
  }

  static void clearRecents() {
    if (recents.isEmpty) return;
    recents.clear();
    _persistRecents();
  }

  /// Fixed trending queries mixing brands + categories.
  static const trendingQueries = [
    'Nike',
    'Saree',
    'Earbuds',
    'Watch',
    'Kurti',
    'Sofa',
  ];

  static List<_Entry>? _pool;

  /// Bounded pool: first 3 products of every leaf + home deals.
  static List<_Entry> _entries() {
    final cached = _pool;
    if (cached != null) return cached;
    final out = <_Entry>[];
    final seen = <int>{};
    void add(Product p, String leaf, String group, String tab,
        String category) {
      if (!seen.add(p.id)) return;
      final hay =
          '${p.name} ${p.brand} $leaf $group $tab $category'
              .toLowerCase();
      out.add(_Entry(product: p, haystack: hay, nameMatch: false));
    }

    for (final deal in homeDeals) {
      add(deal, deal.name, '', '', '');
    }
    for (final category in categoryTree.keys) {
      for (final tab in tabsFor(category)) {
        for (final group in tab.groups) {
          for (final leaf in group.leafs) {
            for (final p in ProductRepo.allFor(
                    'search', leaf.name)
                .take(3)) {
              add(p, leaf.name, group.name, tab.name,
                  category);
            }
          }
        }
      }
    }
    _pool = out;
    return out;
  }

  /// Case-insensitive substring search, capped at 60 hits.
  /// Name matches rank first, then popularity (reviews).
  static List<Product> searchProducts(String query,
      {int limit = 60}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <_Entry>[];
    for (final e in _entries()) {
      if (!e.haystack.contains(q)) continue;
      hits.add(_Entry(
        product: e.product,
        haystack: e.haystack,
        nameMatch:
            e.product.name.toLowerCase().contains(q) ||
                e.product.brand.toLowerCase().contains(q),
      ));
    }
    hits.sort((a, b) {
      if (a.nameMatch != b.nameMatch) {
        return a.nameMatch ? -1 : 1;
      }
      return b.product.reviews.compareTo(a.product.reviews);
    });
    return [for (final h in hits.take(limit)) h.product];
  }

  /// Filters + sorts a result list (pure). Filters compose with AND.
  static List<Product> applyFilters(
    List<Product> src, {
    SearchSort sort = SearchSort.relevance,
    double minRating = 0,
    int minOff = 0,
  }) {
    var out = [
      for (final p in src)
        if (p.rating >= minRating && p.off >= minOff) p,
    ];
    switch (sort) {
      case SearchSort.relevance:
        break;
      case SearchSort.priceLow:
        out.sort((a, b) => a.price.compareTo(b.price));
      case SearchSort.priceHigh:
        out.sort((a, b) => b.price.compareTo(a.price));
      case SearchSort.rating:
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case SearchSort.discount:
        out.sort((a, b) => b.off.compareTo(a.off));
    }
    return out;
  }

  static int get poolSize => _entries().length;
}
