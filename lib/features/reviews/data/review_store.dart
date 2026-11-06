import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/review_repo.dart' as api;
import 'package:oxro/features/reviews/data/review_repo.dart';

/// User-written reviews (one per product).
/// Catalogue reviews stay in [ReviewRepo]; this store holds only
/// the device user's own submissions so past-order + PDP stay in sync
/// and duplicates are blocked. Local cache + backend sync.
class ReviewStore extends ChangeNotifier {
  ReviewStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final ReviewStore instance = ReviewStore._();

  static const _kMine = 'oxro_my_reviews_v1';

  final Map<int, Review> _mine = {};
  bool _serverEmpty = false;

  @visibleForTesting
  static void resetForTests() {
    instance._mine.clear();
    instance.notifyListeners();
  }

  static Review _fromRow(Map<String, dynamic> m) {
    final id = (m['productId'] as num?)?.toInt() ?? 0;
    final hasVideo = (m['hasVideo'] as bool?) ?? false;
    return Review(
      id: 'mine_$id',
      name: (m['name'] as String?) ?? 'You',
      city: 'You',
      date: 'Just now',
      rating: ((m['rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      title: 'My review',
      body: (m['body'] as String?) ?? '',
      helpful: 0,
      verified: true,
      photos: [
        for (final v in (m['photos'] is List ? m['photos'] as List : const []))
          if (v is num) v.toInt(),
      ],
      hasVideo: hasVideo,
      videoSecs: hasVideo ? 6 : 0,
    );
  }

  /// Loads persisted submissions (call once at splash).
  Future<void> _maybeSeedServer() async {
    if (!_serverEmpty || !CustomerIdentity.networkEnabled || _mine.isEmpty) {
      _serverEmpty = false;
      return;
    }
    try {
      for (final entry in _mine.entries) {
        await api.ReviewRepo().upsert(
          productId: entry.key,
          rating: entry.value.rating,
          body: entry.value.body,
          photos: entry.value.photos,
          hasVideo: entry.value.hasVideo,
        );
      }
    } catch (_) {
      // Local cache remains authoritative; the next sync can retry.
    } finally {
      _serverEmpty = false;
    }
  }

  Future<void> load() async {
    _serverEmpty = false;
    if (CustomerIdentity.networkEnabled) {
      try {
        final remote = await api.ReviewRepo().list();
        if (remote != null) {
          if (remote.isNotEmpty) {
            _mine.clear();
            for (final e in remote) {
              if (e is! Map<String, dynamic>) continue;
              final r = _fromRow(e);
              final id = (e['productId'] as num?)?.toInt();
              if (id != null) _mine[id] = r;
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
      if (_mine.isNotEmpty) {
        await _maybeSeedServer();
        return;
      }
      final raw = p.getString(_kMine);
      if (raw == null || raw.isEmpty) {
        await _maybeSeedServer();
        return;
      }
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final id = m['productId'] as int;
        _mine[id] = _fromRow({
          'productId': id,
          'name': m['name'],
          'rating': m['rating'],
          'body': m['body'],
          'photos': m['photos'],
          'hasVideo': m['hasVideo'],
        });
      }
      notifyListeners();
    } catch (_) {
      await _maybeSeedServer();
      return;
    }
    await _maybeSeedServer();
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
    if (CustomerIdentity.networkEnabled) {
      unawaited(() async {
        try {
          await api.ReviewRepo().upsert(
            productId: productId,
            rating: r.rating,
            body: r.body,
            photos: r.photos,
            hasVideo: r.hasVideo,
          );
        } catch (_) {
          // Best-effort sync only.
        }
      }());
    }
    return r;
  }
}
