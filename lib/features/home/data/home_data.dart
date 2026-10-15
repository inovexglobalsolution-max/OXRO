import 'package:flutter/material.dart';

/// Mock catalogue for 06 Home (Fashion + Electronics).
/// Real Supabase catalogue replaces this later.

class HomeBanner {
  const HomeBanner({
    required this.title,
    required this.sub,
    required this.cta,
    required this.colors,
    required this.icon,
    this.image,
  });

  final String title;
  final String sub;
  final String cta;
  final List<Color> colors;
  final IconData icon;

  /// Bundled art (null = code-rendered gradient + icon fallback).
  final String? image;
}

class HomeCategory {
  const HomeCategory({
    required this.label,
    required this.short,
    required this.icon,
    required this.items,
  });

  /// Full spec name (listing title).
  final String label;

  /// Compact circle text.
  final String short;
  final IconData icon;

  /// Mock catalogue size (backend replaces later).
  final String items;
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

  int get off =>
      mrp <= 0 ? 0 : ((1 - price / mrp) * 100).round();

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
      };

  static Product fromJson(Map<String, dynamic> m) {
    final codePoint = (m['icon'] as num?)?.toInt() ?? 0xe000;
    final rawColors = m['colors'];
    final colorList = [
      for (final v in (rawColors is List
          ? rawColors
          : const [0xFFFFFFFF, 0xFF000000]))
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

const homeBanners = [
  HomeBanner(
    title: 'OXRO Mega Store',
    sub: 'Everything in one app',
    cta: 'Start Shopping',
    colors: [Color(0xFF082B66), Color(0xFF0A8CFF)],
    icon: Icons.shopping_bag_outlined,
    image: 'assets/banners/all_in_one.png',
  ),
  HomeBanner(
    title: 'Big Fashion Sale',
    sub: 'Up to 70% OFF',
    cta: 'Shop Now',
    colors: [Color(0xFFFF8A00), Color(0xFFFF4D00)],
    icon: Icons.checkroom_outlined,
    image: 'assets/banners/fashion.png',
  ),
  HomeBanner(
    title: 'Electronics Fest',
    sub: 'From ₹999 + No-Cost EMI',
    cta: 'Explore',
    colors: [Color(0xFF0A8CFF), Color(0xFF004E92)],
    icon: Icons.smartphone_outlined,
    image: 'assets/banners/electronics.png',
  ),
  HomeBanner(
    title: 'Home Makeover',
    sub: 'From ₹499 + Free Delivery',
    cta: 'Refresh',
    colors: [Color(0xFF0E9F6E), Color(0xFF03543F)],
    icon: Icons.kitchen_outlined,
    image: 'assets/banners/home_kitchen.png',
  ),
  HomeBanner(
    title: 'Beauty Picks',
    sub: 'Flat 40% OFF top brands',
    cta: 'Glow Now',
    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
    icon: Icons.spa_outlined,
    image: 'assets/banners/beauty.png',
  ),
  HomeBanner(
    title: 'Sport On',
    sub: 'Min 50% OFF + Extra 10%',
    cta: 'Train Now',
    colors: [Color(0xFF65A30D), Color(0xFF1A2E05)],
    icon: Icons.fitness_center_outlined,
    image: 'assets/banners/sports.png',
  ),
  HomeBanner(
    title: 'Study & Office',
    sub: 'From ₹99 + Bulk Deals',
    cta: 'Stock Up',
    colors: [Color(0xFFD97706), Color(0xFF78350F)],
    icon: Icons.menu_book_outlined,
    image: 'assets/banners/books_office.png',
  ),
  HomeBanner(
    title: 'Auto Gear',
    sub: 'Up to 60% OFF accessories',
    cta: 'Upgrade',
    colors: [Color(0xFF475569), Color(0xFF0F172A)],
    icon: Icons.directions_car_outlined,
    image: 'assets/banners/auto.png',
  ),
  HomeBanner(
    title: 'Kids & Pets',
    sub: 'Flat 30% OFF toys',
    cta: 'Play Now',
    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    icon: Icons.pets_outlined,
    image: 'assets/banners/toys_kids_pets.png',
  ),
];

/// Banner i opens this homeCategories index.
/// Index 0 (All-in-One) opens the Categories tab (-1 sentinel);
/// rest stay 1:1 with the 8 categories (Big Fashion kept at 1).
const bannerCategoryIndex = [-1, 1, 0, 2, 3, 4, 5, 6, 7];

/// Spec § Main categories (exact 8).
const homeCategories = [
  HomeCategory(
      label: 'Electronics',
      short: 'Electro',
      icon: Icons.devices_outlined,
      items: '2.1k items'),
  HomeCategory(
      label: 'Fashion & Clothing',
      short: 'Fashion',
      icon: Icons.checkroom_outlined,
      items: '5.4k items'),
  HomeCategory(
      label: 'Home & Kitchen',
      short: 'Home',
      icon: Icons.kitchen_outlined,
      items: '3.2k items'),
  HomeCategory(
      label: 'Beauty & Personal Care',
      short: 'Beauty',
      icon: Icons.spa_outlined,
      items: '1.8k items'),
  HomeCategory(
      label: 'Sports & Fitness',
      short: 'Sports',
      icon: Icons.fitness_center_outlined,
      items: '960 items'),
  HomeCategory(
      label: 'Books, Stationery & Office',
      short: 'Books',
      icon: Icons.menu_book_outlined,
      items: '1.2k items'),
  HomeCategory(
      label: 'Automotive & Accessories',
      short: 'Auto',
      icon: Icons.directions_car_outlined,
      items: '740 items'),
  HomeCategory(
      label: 'Toys, Kids & Pet Supplies',
      short: 'Toys',
      icon: Icons.pets_outlined,
      items: '1.5k items'),
];

const homeDeals = [
  Product(
    id: 1,
    name: 'Nike Air Max 270',
    brand: 'Nike',
    price: 6099,
    mrp: 8999,
    rating: 4.3,
    reviews: 12400,
    icon: Icons.directions_run_outlined,
    colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
  ),
  Product(
    id: 2,
    name: 'Casual Shirt Slim-Fit',
    brand: 'OXRO Select',
    price: 1399,
    mrp: 1999,
    rating: 4.1,
    reviews: 3200,
    icon: Icons.person_outline,
    colors: [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
  ),
  Product(
    id: 3,
    name: 'Wireless Earbuds Pro',
    brand: 'SonicX',
    price: 2499,
    mrp: 4999,
    rating: 4.5,
    reviews: 21800,
    icon: Icons.headphones_outlined,
    colors: [Color(0xFFE6E6FA), Color(0xFFC4B5FD)],
  ),
  Product(
    id: 4,
    name: 'Travel Backpack 32L',
    brand: 'TrekGo',
    price: 1599,
    mrp: 2999,
    rating: 4.2,
    reviews: 5100,
    icon: Icons.backpack_outlined,
    colors: [Color(0xFFD9F2E6), Color(0xFFA7DFC3)],
  ),
  Product(
    id: 5,
    name: 'Smart Watch Fit 2',
    brand: 'PulseFit',
    price: 3999,
    mrp: 7999,
    rating: 4.4,
    reviews: 15700,
    icon: Icons.watch_outlined,
    colors: [Color(0xFFFFE8EE), Color(0xFFFFC2D4)],
  ),
  Product(
    id: 6,
    name: 'Men Polo T-Shirt',
    brand: 'OXRO Select',
    price: 1289,
    mrp: 1899,
    rating: 4.0,
    reviews: 1800,
    icon: Icons.dry_cleaning_outlined,
    colors: [Color(0xFFFFF3D6), Color(0xFFFFDFA3)],
  ),
];
