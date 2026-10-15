import 'package:flutter/material.dart';

import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';

/// One mock review (deterministic per product).
/// [photos] are mock gradient-seed indices (0-5); [hasVideo] is a
/// mock 6-sec clip ([videoSecs]). Supabase Storage URLs replace later.
class Review {
  const Review({
    required this.id,
    required this.name,
    required this.city,
    required this.date,
    required this.rating,
    required this.title,
    required this.body,
    required this.helpful,
    this.verified = true,
    this.photos = const [],
    this.hasVideo = false,
    this.videoSecs = 0,
  });

  final String id;
  final String name;
  final String city;
  final String date;
  final int rating;
  final String title;
  final String body;
  final int helpful;
  final bool verified;
  final List<int> photos;
  final bool hasVideo;
  final int videoSecs;

  bool get hasMedia => photos.isNotEmpty || hasVideo;

  Review copyWith({List<int>? photos, bool? hasVideo, int? videoSecs}) {
    return Review(
      id: id,
      name: name,
      city: city,
      date: date,
      rating: rating,
      title: title,
      body: body,
      helpful: helpful,
      verified: verified,
      photos: photos ?? this.photos,
      hasVideo: hasVideo ?? this.hasVideo,
      videoSecs: videoSecs ?? this.videoSecs,
    );
  }
}

/// Deterministic mock reviews — same product → same reviews every run.
/// Backend review API replaces this later.
class ReviewRepo {
  /// Mock photo tints for review media (Supabase URLs replace later).
  static const mediaTints = [
    [Color(0xFFFFE3CB), Color(0xFFFF8A00)],
    [Color(0xFFD8EBFF), Color(0xFF0A8CFF)],
    [Color(0xFFE6E6FA), Color(0xFF8B5CF6)],
    [Color(0xFFD9F2E6), Color(0xFF0E9F6E)],
    [Color(0xFFFFE8EE), Color(0xFFE91E63)],
    [Color(0xFFFFF3D6), Color(0xFFD97706)],
  ];
  static const _names = [
    ('Priya', 'Chennai'),
    ('Karthik', 'Madurai'),
    ('Divya', 'Coimbatore'),
    ('Arun', 'Trichy'),
    ('Meena', 'Salem'),
    ('Suresh', 'Chennai'),
    ('Kavya', 'Erode'),
    ('Ravi', 'Vellore'),
    ('Anitha', 'Tirunelveli'),
    ('Vikram', 'Chennai'),
    ('Deepa', 'Madurai'),
    ('Manoj', 'Coimbatore'),
  ];

  static const _titles = [
    'Value for money!',
    'Exceeded expectations',
    'Good quality, fast delivery',
    'Genuine product',
    'Nice, but packing could improve',
    'Worth every rupee',
    'Perfect for daily use',
    'Quality is top-notch',
    'Decent for the price',
    'Highly recommended',
  ];

  static const _bodies = [
    'Ordered last week, delivery in 2 days. Packing neat, product exactly as shown. Using daily, no issues so far.',
    'Original product with bill. Quality super, OXRO delivery fast. Cash on delivery available, very convenient.',
    'Price compared with shop — here ₹500 less. Fitting and finish good. Seller response quick on chat.',
    'My second purchase. First one still working fine after 6 months. Genuine, 7-day return gives confidence.',
    'Delivery one day late but product good. Rating 4 star only for delay, otherwise fully satisfied.',
    'Photo same as real product. Working perfectly. Family members also ordered after seeing mine.',
    'Good for this price range. EMI option helped. Installation/demo not needed, easy to use directly.',
    'Checked originality via brand website — 100% genuine. Warranty card included in box.',
    'Size/fit as per chart. Return process simple if needed, but I kept it. Recommend for new buyers.',
    'Bought during sale, big savings. Daily use rough ga kuda paiya use panninen — still perfect.',
  ];

  static const _dates = [
    '2 days ago',
    '1 week ago',
    '2 weeks ago',
    '1 month ago',
    '2 months ago',
    '3 months ago',
  ];

  static int _rand(int seed) =>
      ((seed * 1103515245 + 12345) & 0x7fffffff);

  /// 3 reviews for every product (deterministic, ratings near product).
  static List<Review> reviewsFor(Product p, {int count = 3}) {
    var s = _rand(p.id);
    final out = <Review>[];
    for (var i = 0; i < count; i++) {
      s = _rand(s + i * 97);
      final ni = s % _names.length;
      s = _rand(s + 13);
      final ti = s % _titles.length;
      s = _rand(s + 29);
      final bi = s % _bodies.length;
      s = _rand(s + 7);
      final di = s % _dates.length;
      // Ratings cluster around product rating; low products get a critic.
      var r = p.rating.round() + ((i == 0) ? 0 : (i == 1 ? 0 : -1));
      if (p.rating < 3.8 && i == 2) r = 2;
      r = r.clamp(2, 5);
      s = _rand(s + 5);
      final helpful = 5 + (s % 40);
      // Media: review 0 always has photos (2-3), review 1 gets the
      // 6-sec video on even seeds, review 2 has 1 photo on 2/3 seeds.
      // Guarantees every product shows photo + video somewhere.
      s = _rand(s + 11);
      final List<int> photos;
      var hasVideo = false;
      if (i == 0) {
        photos = [s % 6, (s ~/ 7) % 6];
        if (s.isEven) photos.add((s ~/ 13) % 6);
      } else if (i == 1) {
        photos = const [];
        hasVideo = s.isEven;
      } else {
        photos = s % 3 == 0 ? const [] : [(s ~/ 3) % 6];
        hasVideo = s % 3 == 0;
      }
      out.add(Review(
        id: '${p.id}_r$i',
        name: _names[ni].$1,
        city: _names[ni].$2,
        date: _dates[di],
        rating: r,
        title: _titles[ti],
        body: _bodies[bi],
        helpful: helpful,
        verified: true,
        photos: photos,
        hasVideo: hasVideo,
        videoSecs: hasVideo ? 6 : 0,
      ));
    }
    // Every product shows at least one 6-sec clip.
    if (!out.any((r) => r.hasVideo)) {
      out[1] = out[1].copyWith(hasVideo: true, videoSecs: 6);
    }
    return out;
  }

  /// 5★..1★ percentages summing to 100, derived from product rating.
  static List<int> breakdown(Product p) {
    final p5 = ((p.rating - 2.5) * 30).clamp(15, 70).round();
    const p4 = 20;
    const p3 = 10;
    const p2 = 5;
    final p1 = (100 - p5 - p4 - p3 - p2).clamp(2, 20);
    // Rebalance rounding drift into p5.
    final total = p5 + p4 + p3 + p2 + p1;
    return [p5 + (100 - total), p4, p3, p2, p1];
  }

  /// 48-hr post-delivery review window (pure, testable).
  /// [orders] is OrderStore.instance.all in app; custom lists in tests.
  static const reviewWindow = Duration(hours: 48);

  /// Who may write: delivered this product within [reviewWindow].
  /// Cancelled orders never count; undelivered never count.
  static ReviewAccess canReview({
    required int productId,
    required List<MockOrder> orders,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    var bought = false;
    for (final o in orders) {
      if (o.status == OrderStatus.cancelled) continue;
      if (!o.products.any((p) => p.id == productId)) continue;
      bought = true;
      final d = o.deliveredAt;
      if (o.status == OrderStatus.delivered &&
          d != null &&
          !d.isAfter(at) &&
          at.difference(d) <= reviewWindow) {
        return ReviewAccess.ok;
      }
    }
    return bought ? ReviewAccess.expired : ReviewAccess.notBought;
  }
}

/// Review write access for a product.
enum ReviewAccess { ok, notBought, expired }
