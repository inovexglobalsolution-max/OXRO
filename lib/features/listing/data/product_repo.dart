import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/features/detail/data/dish_options.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Mock catalogue for 08 Product Listing (food dishes).
/// Deterministic per sub-category (same sub → same 60 dishes every run).
/// Backend/Supabase catalogue replaces this later.
class ProductRepo {
  static const totalPerLeaf = 60;
  static const pageSize = 10;

  /// Kitchens (used as the "brand" facet on the PLP).
  static const _brands = [
    'Paradise Biryani',
    'Saravana Bhavan',
    'A2B Veg',
    "Domino's",
    'Burger King',
    'Sangeetha Veg',
    'Anandhas Kitchen',
    'KFC',
    'Pizza Hut',
    'Cream Stone',
  ];

  /// RestaurantRepo ids, parallel to [_brands] so every generated dish
  /// resolves to a real kitchen page.
  static const _brandIds = [
    'r_paradise',
    'r_saravana',
    'r_a2b',
    'r_dominos',
    'r_burger_king',
    'r_sangeetha',
    'r_anandhas',
    'r_kfc',
    'r_pizza_hut',
    'r_cream_stone',
  ];

  /// Dish style words (prefix the sub-category name).
  static const _styles = [
    'Special',
    'Ghee Roast',
    'Tandoori',
    'Home Style',
    'Chef Special',
    'Spicy',
    'Mild',
    'Deluxe',
    'Combo',
    'Single',
  ];

  static const _tiles = [
    [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
    [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
    [Color(0xFFE6E6FA), Color(0xFFC4B5FD)],
    [Color(0xFFD9F2E6), Color(0xFFA7DFC3)],
    [Color(0xFFFFE8EE), Color(0xFFFFC2D4)],
    [Color(0xFFFFF3D6), Color(0xFFFFDFA3)],
  ];

  static final _cache = <String, List<Product>>{};

  /// Full 60-product list for a leaf (cached, deterministic).
  static List<Product> allFor(
    String ns,
    String leaf, {
    IconData icon = Icons.shopping_bag_outlined,
  }) {
    final key = '$ns::$leaf';
    return _cache.putIfAbsent(key, () => _build(ns, leaf, icon));
  }

  /// One page (10). Empty when exhausted → drives infinite scroll end.
  static List<Product> page(
    String ns,
    String leaf,
    int page, {
    IconData icon = Icons.shopping_bag_outlined,
  }) {
    final all = allFor(ns, leaf, icon: icon);
    final start = page * pageSize;
    if (start >= all.length) return const [];
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  /// 'All' pool: round-robin first 15 of each leaf (capped 60).
  static List<Product> allMixed(String ns, List<String> leafs, IconData icon) {
    final pools = [
      for (final leaf in leafs) allFor(ns, leaf, icon: icon).take(15).toList(),
    ];
    final out = <Product>[];
    for (var i = 0; i < 15 && out.length < totalPerLeaf; i++) {
      for (final p in pools) {
        if (i < p.length && out.length < totalPerLeaf) {
          out.add(p[i]);
        }
      }
    }
    return out;
  }

  /// Stable FNV-1a string hash (Dart String.hashCode is not
  /// guaranteed stable across runs — this keeps catalogue ids
  /// deterministic on every device and SDK).
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Collision-free id: 25-bit (ns, leaf) lane × 128 + index.
  /// XOR-with-small-index (old scheme) collided across leaves and
  /// merged distinct products in Cart/Wishlist.
  static int productId(String ns, String leaf, int i) {
    final lane = ((_stableHash(ns) * 31 + _stableHash(leaf)) & 0x1ffffff);
    return lane * 128 + (i % 128);
  }

  /// Diet tag derived from the dish name, not a coin flip.
  ///
  /// "Veggie" tokenises to `veggie`, so it is not mistaken for an egg dish.
  static ({bool veg, bool egg}) _dietFor(String name) {
    final tokens = name.toLowerCase().split(RegExp(r'[^a-z]+'));
    bool has(Set<String> words) => tokens.any(words.contains);

    const eggWords = {'egg', 'eggs', 'omelette', 'omelet', 'bhurji'};
    const nonVegWords = {
      'chicken',
      'mutton',
      'lamb',
      'goat',
      'beef',
      'pork',
      'fish',
      'prawn',
      'prawns',
      'shrimp',
      'crab',
      'lobster',
      'squid',
      'seafood',
      'kebab',
      'kebabs',
      'tikka',
      'nihari',
      'haleem',
      'keema',
      'pepperoni',
      'salami',
      'sausage',
      'bacon',
      'ham',
      'meat',
      'zinger',
      'ilish',
      'mangsho',
      'macher',
    };

    if (has(eggWords)) return (veg: false, egg: true);
    if (has(nonVegWords)) return (veg: false, egg: false);
    return (veg: true, egg: false);
  }

  static List<Product> _build(String ns, String leaf, IconData icon) {
    var s = (_stableHash(ns) ^ _stableHash(leaf)) & 0x7fffffff;
    int next(int max) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s % max;
    }

    return List.generate(totalPerLeaf, (i) {
      final style = _styles[i % _styles.length];
      final dup = i ~/ _styles.length;
      final name = dup == 0 ? '$style $leaf' : '$style $leaf ${dup + 1}';
      final price = ((49 + next(560)) ~/ 10) * 10 + 9;
      final off = 10 + next(50);
      final mrp = price + (price * off ~/ (100 - off));
      final tile = _tiles[next(_tiles.length)];
      // Keep consuming the pseudo-random sequence in the same order so
      // prices/ratings/kitchens stay stable, but derive the diet from the
      // dish itself: a "Chicken Biryani" must never be tagged veg.
      final randomVeg = next(2) == 0;
      if (!randomVeg) next(3);
      final kitchenIndex = next(_brands.length);
      final kitchen = _brands[kitchenIndex];
      final diet = _dietFor(name);
      return Product(
        id: productId(ns, leaf, i),
        name: name,
        brand: kitchen,
        restaurantId: _brandIds[kitchenIndex],
        restaurantName: kitchen,
        veg: diet.veg,
        egg: diet.egg,
        description:
            '$leaf prepared $style, served hot '
            'with freshly ground spices.',
        price: price,
        mrp: mrp,
        rating: (36 + next(14)) / 10,
        reviews: 50 + next(30000),
        icon: icon,
        colors: tile,
        imageUrl: FoodMedia.forDish(name, category: leaf, variant: i),
        options: dishOptionsFor(name),
      );
    });
  }
}

enum PlpSort { popularity, priceAsc, priceDesc, rating, discount }

const plpSortLabels = {
  PlpSort.popularity: 'Popularity',
  PlpSort.priceAsc: 'Price: Low to High',
  PlpSort.priceDesc: 'Price: High to Low',
  PlpSort.rating: 'Rating',
  PlpSort.discount: 'Discount',
};

/// Price buckets for 10 Filters (food plate ranges).
enum PlpPrice { all, under200, b200to399, above400 }

const plpPriceLabels = {
  PlpPrice.all: 'All prices',
  PlpPrice.under200: 'Under ₹200',
  PlpPrice.b200to399: '₹200 – ₹399',
  PlpPrice.above400: '₹400 & above',
};

/// Immutable PLP filter set — empty/default = no filtering.
/// Pure + unit-tested alongside [sortProducts].
class PlpFilters {
  const PlpFilters({
    this.brands = const {},
    this.price = PlpPrice.all,
    this.minRating = 0,
    this.minOff = 0,
  });

  /// Empty = all brands.
  final Set<String> brands;
  final PlpPrice price;

  /// 0 = any, else 3 / 4.
  final double minRating;

  /// 0 = any, else 10 / 30 / 50.
  final int minOff;

  bool get isActive =>
      brands.isNotEmpty || price != PlpPrice.all || minRating > 0 || minOff > 0;

  /// Active facet groups (0–4) for the Filter button badge.
  int get count =>
      (brands.isNotEmpty ? 1 : 0) +
      (price != PlpPrice.all ? 1 : 0) +
      (minRating > 0 ? 1 : 0) +
      (minOff > 0 ? 1 : 0);

  PlpFilters copyWith({
    Set<String>? brands,
    PlpPrice? price,
    double? minRating,
    int? minOff,
  }) {
    return PlpFilters(
      brands: brands ?? this.brands,
      price: price ?? this.price,
      minRating: minRating ?? this.minRating,
      minOff: minOff ?? this.minOff,
    );
  }
}

/// Pure filter — brand set, price bucket, min rating, min discount.
List<Product> filterProducts(List<Product> src, PlpFilters f) {
  if (!f.isActive) return List<Product>.of(src);
  return [
    for (final p in src)
      if ((f.brands.isEmpty || f.brands.contains(p.brand)) &&
          switch (f.price) {
            PlpPrice.all => true,
            PlpPrice.under200 => p.price < 200,
            PlpPrice.b200to399 => p.price >= 200 && p.price < 400,
            PlpPrice.above400 => p.price >= 400,
          } &&
          p.rating >= f.minRating &&
          p.off >= f.minOff)
        p,
  ];
}

/// Pure sort — unit-tested.
List<Product> sortProducts(List<Product> src, PlpSort sort) {
  final list = List<Product>.of(src);
  switch (sort) {
    case PlpSort.priceAsc:
      list.sort((a, b) => a.price.compareTo(b.price));
    case PlpSort.priceDesc:
      list.sort((a, b) => b.price.compareTo(a.price));
    case PlpSort.rating:
      list.sort((a, b) => b.rating.compareTo(a.rating));
    case PlpSort.discount:
      list.sort((a, b) => b.off.compareTo(a.off));
    case PlpSort.popularity:
      list.sort((a, b) => b.reviews.compareTo(a.reviews));
  }
  return list;
}
