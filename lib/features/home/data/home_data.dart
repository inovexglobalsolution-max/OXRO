import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/features/categories/data/food_taxonomy.dart';
import 'package:oxro/features/detail/data/dish_options.dart';

export 'package:oxro/features/categories/data/food_taxonomy.dart'
    show
        FoodCategory,
        foodCategories,
        foodSubcategories,
        subcategoriesFor,
        foodCategoryFor;

/// Mock catalogue for 06 Home (food delivery).
/// Real Supabase catalogue replaces this later.

enum BannerStyle { premium, sale, standard }

class HomeBanner {
  const HomeBanner({
    required this.title,
    required this.sub,
    required this.cta,
    required this.colors,
    required this.icon,
    this.imageUrl,
    this.tag,
    this.style = BannerStyle.standard,
  });

  final String title;
  final String sub;
  final String cta;
  final List<Color> colors;
  final IconData icon;

  /// Bundled food photo (load failure = gradient + icon fallback).
  final String? imageUrl;

  /// Short offer sticker rendered as a seal on the hero (e.g. '30% OFF').
  final String? tag;

  /// Hero art treatment. [BannerStyle.premium] is the burgundy-cream FREE
  /// DELIVERY membership slide, [BannerStyle.sale] is the looping starburst
  /// offer promo, and
  /// [BannerStyle.standard] is the per-palette catalogue hero.
  final BannerStyle style;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.mrp,
    required this.rating,
    required this.reviews,
    required this.icon,
    required this.colors,
    this.restaurantId,
    this.restaurantName,
    this.veg = false,
    this.egg = false,
    this.description = '',
    this.options = const [],
    this.imageUrl,
  });

  final int id;
  final String name;
  final String brand;
  final int price;
  final int mrp;
  final double rating;
  final int reviews;
  final IconData icon;
  final List<Color> colors;

  /// Food fields (null/false/empty for legacy catalogue items).
  /// [brand] doubles as the kitchen name for dishes.
  final String? restaurantId;
  final String? restaurantName;
  final bool veg;
  final bool egg;
  final String description;
  final List<DishOptionGroup> options;

  /// Bundled food photo; null = gradient/icon fallback.
  final String? imageUrl;

  int get off => mrp <= 0 ? 0 : ((1 - price / mrp) * 100).round();

  /// Kitchen shown on dish cards (falls back to [brand]).
  String get kitchen => restaurantName ?? brand;

  /// Copy with a customised unit price (add-ons / size deltas).
  Product priced(int newPrice, {int? newMrp}) => Product(
    id: id,
    name: name,
    brand: brand,
    price: newPrice,
    mrp: newMrp ?? mrp,
    rating: rating,
    reviews: reviews,
    icon: icon,
    colors: colors,
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    veg: veg,
    egg: egg,
    description: description,
    imageUrl: imageUrl,
  );

  /// JSON snapshot for on-device caches (cart/wishlist/orders).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'price': price,
    'mrp': mrp,
    'rating': rating,
    'reviews': reviews,
    'icon': icon.codePoint,
    'colors': [for (final c in colors) c.toARGB32()],
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'veg': veg,
    'egg': egg,
    'description': description,
    'imageUrl': imageUrl,
  };

  static Product fromJson(Map<String, dynamic> m) {
    final codePoint = (m['icon'] as num?)?.toInt() ?? 0xe000;
    final rawColors = m['colors'];
    final colorList = [
      for (final v
          in (rawColors is List ? rawColors : const [0xFFFFFFFF, 0xFF000000]))
        if (v is num) Color(v.toInt()),
    ];
    // ignore: non_const_argument_for_const_parameter
    final icon = IconData(codePoint, fontFamily: 'MaterialIcons');
    return Product(
      id: (m['id'] as num).toInt(),
      name: (m['name'] as String?) ?? '',
      brand: (m['brand'] as String?) ?? '',
      price: (m['price'] as num?)?.toInt() ?? 0,
      mrp: (m['mrp'] as num?)?.toInt() ?? 0,
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      reviews: (m['reviews'] as num?)?.toInt() ?? 0,
      icon: icon,
      colors: colorList.isEmpty
          ? const [Color(0xFFFFFFFF), Color(0xFF000000)]
          : colorList,
      restaurantId: m['restaurantId'] as String?,
      restaurantName: m['restaurantName'] as String?,
      veg: (m['veg'] as bool?) ?? false,
      egg: (m['egg'] as bool?) ?? false,
      description: (m['description'] as String?) ?? '',
      imageUrl: m['imageUrl'] as String?,
    );
  }

  static String inr(int v) {
    // 7838 -> ₹7,838 (Indian grouping).
    final s = v.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    return '₹${parts.join(',')},$last3';
  }
}

final homeBanners = [
  HomeBanner(
    title: 'ITEMS AT 50% OFF',
    sub: 'On your favourites this week',
    cta: 'Order now',
    colors: [const Color(0xFFE23744), const Color(0xFFB3121C)],
    icon: Icons.bolt_rounded,
    imageUrl: FoodMedia.heroBiryani,
    tag: '50% OFF',
    style: BannerStyle.sale,
  ),
  HomeBanner(
    title: 'FREE DELIVERY',
    sub: 'above ₹199',
    cta: 'Join PREMIUM for 3 months at ₹1',
    colors: [const Color(0xFFFFF7EC), const Color(0xFF4A0E24)],
    icon: Icons.workspace_premium_rounded,
    imageUrl: FoodMedia.heroThali,
    style: BannerStyle.premium,
  ),
  HomeBanner(
    title: 'Biryani Fest',
    sub: 'Flat 30% OFF on Dum Biryani',
    cta: 'Order Biryani',
    colors: [const Color(0xFFFF8A00), const Color(0xFFFF4D00)],
    icon: Icons.rice_bowl_outlined,
    imageUrl: FoodMedia.heroBiryani,
    tag: '30% OFF',
  ),
  HomeBanner(
    title: 'Pizza Party',
    sub: 'Buy 1 Get 1 Free',
    cta: 'Grab Deal',
    colors: [const Color(0xFF0A8CFF), const Color(0xFF004E92)],
    icon: Icons.local_pizza_outlined,
    imageUrl: FoodMedia.heroPizza,
    tag: 'BOGO FREE',
  ),
  HomeBanner(
    title: 'South Indian Breakfast',
    sub: 'From ₹99 + Free Filter Coffee',
    cta: 'Wake Up',
    colors: [const Color(0xFF0E9F6E), const Color(0xFF03543F)],
    icon: Icons.breakfast_dining_outlined,
    imageUrl: FoodMedia.heroSouthIndian,
    tag: 'FROM ₹99',
  ),
  HomeBanner(
    title: 'Sweet Cravings',
    sub: 'Desserts & Ice Cream 40% OFF',
    cta: 'Treat Me',
    colors: [const Color(0xFFE91E63), const Color(0xFF9C27B0)],
    icon: Icons.icecream_outlined,
    imageUrl: FoodMedia.heroDessert,
    tag: '40% OFF',
  ),
  HomeBanner(
    title: 'Healthy Bowls',
    sub: 'Salads & Grills under 400 kcal',
    cta: 'Eat Clean',
    colors: [const Color(0xFF65A30D), const Color(0xFF1A2E05)],
    icon: Icons.eco_outlined,
    imageUrl: FoodMedia.heroHealthy,
    tag: '400 KCAL',
  ),
  HomeBanner(
    title: 'Chai & Snacks',
    sub: 'Evening combos from ₹49',
    cta: 'Sip Now',
    colors: [const Color(0xFFD97706), const Color(0xFF78350F)],
    icon: Icons.coffee_outlined,
    imageUrl: FoodMedia.coffee,
    tag: 'FROM ₹49',
  ),
  HomeBanner(
    title: 'BBQ & Grills',
    sub: 'Tandoori & Kebabs 25% OFF',
    cta: 'Fire Up',
    colors: [const Color(0xFF475569), const Color(0xFF0F172A)],
    icon: Icons.outdoor_grill_outlined,
    imageUrl: FoodMedia.heroBbq,
    tag: '25% OFF',
  ),
  HomeBanner(
    title: 'Street Food Corner',
    sub: 'Chaat & Rolls from ₹39',
    cta: 'Dig In',
    colors: [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
    icon: Icons.storefront_outlined,
    imageUrl: FoodMedia.streetFood,
    tag: 'FROM ₹39',
  ),
];

/// Banner i opens this homeCategories index.
/// Index 0-1 are promo heroes (Categories tab, -1 sentinel); the rest are
/// 1:1 with the food categories below (Biryani at 0, Pizza at 4, …).
const bannerCategoryIndex = [-1, -1, 0, 4, 2, 18, 24, 23, 27, 16];

/// Inline mid-scroll ads (Blinkit-style native promos, fashion catalogue).
/// Shown as full-width strips: one static before the feed +
/// one repeating after every 10 feed items. [target] is the
/// homeCategories index to open on tap (-1 = Categories tab).
class HomeInlineAd {
  const HomeInlineAd({
    required this.title,
    required this.sub,
    required this.cta,
    required this.colors,
    required this.icon,
    required this.target,
  });

  final String title;
  final String sub;
  final String cta;
  final List<Color> colors;
  final IconData icon;
  final int target;
}

const homeInlineAds = [
  HomeInlineAd(
    title: 'Weekend Biryani Fest — 30% OFF',
    sub: 'Dum • Hyderabadi • Lucknowi',
    cta: 'Order Now',
    colors: [Color(0xFFFF6A00), Color(0xFFFFB25E)],
    icon: Icons.rice_bowl_outlined,
    target: 0,
  ),
  HomeInlineAd(
    title: 'Pizza Party — Buy 1 Get 1',
    sub: 'Margherita • Farmhouse • Peppy',
    cta: 'Grab Deal',
    colors: [Color(0xFF082B66), Color(0xFF27A9E1)],
    icon: Icons.local_pizza_outlined,
    target: 4,
  ),
  HomeInlineAd(
    title: 'Sweet Tooth — Flat 40% OFF',
    sub: 'Cakes • Ice Cream • Halwa',
    cta: 'Treat Me',
    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
    icon: Icons.cake_outlined,
    target: 18,
  ),
];

/// Flat 2-level food taxonomy: 30 categories (see [foodCategories]).
const homeCategories = foodCategories;

const homeDeals = [
  Product(
    id: 1,
    name: 'Hyderabadi Chicken Biryani',
    brand: 'Paradise Biryani',
    restaurantName: 'Paradise Biryani',
    price: 289,
    mrp: 349,
    rating: 4.5,
    reviews: 12400,
    veg: false,
    description:
        'Long-grain basmati layered with spicy chicken, '
        'saffron and fried onions. Served with raita and salan.',
    icon: Icons.rice_bowl_outlined,
    colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
    imageUrl: FoodMedia.biryaniAlt,
  ),
  Product(
    id: 2,
    name: 'Paneer Butter Masala',
    brand: 'Sangeetha Veg',
    restaurantName: 'Sangeetha Veg',
    price: 249,
    mrp: 299,
    rating: 4.3,
    reviews: 8200,
    veg: true,
    description:
        'Soft paneer cubes simmered in a creamy tomato '
        'and cashew gravy. Best with butter naan.',
    icon: Icons.dinner_dining_outlined,
    colors: [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
    imageUrl: FoodMedia.northIndian,
  ),
  Product(
    id: 3,
    name: 'Farmhouse Pizza',
    brand: 'Domino’s',
    restaurantName: 'Domino’s',
    price: 319,
    mrp: 399,
    rating: 4.4,
    reviews: 21800,
    veg: true,
    description:
        'Onion, capsicum, tomato and mushroom over '
        '100% mozzarella on a hand-tossed base.',
    icon: Icons.local_pizza_outlined,
    colors: [Color(0xFFE6E6FA), Color(0xFFC4B5FD)],
    imageUrl: FoodMedia.pizza,
  ),
  Product(
    id: 4,
    name: 'Masala Dosa',
    brand: 'Saravana Bhavan',
    restaurantName: 'Saravana Bhavan',
    price: 129,
    mrp: 159,
    rating: 4.6,
    reviews: 15100,
    veg: true,
    description:
        'Crispy rice crêpe with spiced potato filling, '
        'coconut chutney and sambar.',
    icon: Icons.breakfast_dining_outlined,
    colors: [Color(0xFFD9F2E6), Color(0xFFA7DFC3)],
    imageUrl: FoodMedia.dosa,
  ),
  Product(
    id: 5,
    name: 'Chicken Cheese Burger',
    brand: 'Burger King',
    restaurantName: 'Burger King',
    price: 199,
    mrp: 249,
    rating: 4.2,
    reviews: 9700,
    veg: false,
    description:
        'Crispy chicken patty, cheese slice, lettuce and '
        'smoky mayo in a toasted sesame bun.',
    icon: Icons.lunch_dining_outlined,
    colors: [Color(0xFFFFE8EE), Color(0xFFFFC2D4)],
    imageUrl: FoodMedia.burger,
  ),
  Product(
    id: 6,
    name: 'Death by Chocolate Sundae',
    brand: 'Cream Stone',
    restaurantName: 'Cream Stone',
    price: 179,
    mrp: 219,
    rating: 4.7,
    reviews: 6800,
    veg: true,
    description:
        'Warm brownie, chocolate ice cream, fudge and '
        'roasted nuts layered in a tall glass.',
    icon: Icons.icecream_outlined,
    colors: [Color(0xFFFFF3D6), Color(0xFFFFDFA3)],
    imageUrl: FoodMedia.dessertBrownie,
  ),
];
