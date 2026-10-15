import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/reviews/data/review_repo.dart';

/// User-written reviews (one per product).
/// Mock catalogue reviews stay in [ReviewRepo]; this store holds only
/// the device user's own submissions so past-order + PDP stay in sync
/// and duplicates are blocked. Persisted via SharedPreferences.
class ReviewStore extends ChangeNotifier {
  ReviewStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final ReviewStore instance = ReviewStore._();

  static const _kMine = 'oxro_my_reviews_v1';

  final Map<int, Review> _mine = {};

  @visibleForTesting
  static void resetForTests() {
    instance._mine.clear();
    instance.notifyListeners();
  }

  /// Loads persisted submissions (call once at splash).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kMine);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final id = m['productId'] as int;
        _mine[id] = Review(
          id: 'mine_$id',
          name: (m['name'] as String?) ?? 'You',
          city: 'You',
          date: 'Just now',
          rating: (m['rating'] as int?) ?? 5,
          title: 'My review',
          body: (m['body'] as String?) ?? '',
          helpful: 0,
          verified: true,
          photos: [
            for (final v in (m['photos'] is List
                ? m['photos'] as List
                : const []))
              if (v is num) v.toInt(),
          ],
          hasVideo: (m['hasVideo'] as bool?) ?? false,
          videoSecs: (m['hasVideo'] as bool?) == true ? 6 : 0,
        );
      }
      notifyListeners();
    } catch (_) {
      // Corrupt cache -> start fresh, never crash splash.
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = [
        for (final e in _mine.entries)
          {
            'productId': e.key,
            'name': e.value.name,
            'rating': e.value.rating,
            'body': e.value.body,
            'photos': e.value.photos,
            'hasVideo': e.value.hasVideo,
          },
      ];
      await p.setString(_kMine, jsonEncode(list));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  bool hasReviewed(int productId) => _mine.containsKey(productId);

  Review? myReviewFor(int productId) => _mine[productId];

  /// Saves a new submission. Returns null when already reviewed.
  Future<Review?> submit({
    required int productId,
    required String name,
    required int rating,
    required String body,
    List<int> photos = const [],
    bool hasVideo = false,
  }) async {
    if (_mine.containsKey(productId)) return null;
    final r = Review(
      id: 'mine_$productId',
      name: name.trim(),
      city: 'You',
      date: 'Just now',
      rating: rating.clamp(1, 5),
      title: 'My review',
      body: body.trim(),
      helpful: 0,
      verified: true,
      photos: List.of(photos),
      hasVideo: hasVideo,
      videoSecs: hasVideo ? 6 : 0,
    );
    _mine[productId] = r;
    notifyListeners();
    // Fire-and-forget: UI must update instantly even if prefs is slow
    // (and widget tests run without a prefs mock).
    _persist();
    return r;
  }
}
