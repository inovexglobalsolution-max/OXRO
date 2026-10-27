import 'package:oxro/features/home/data/home_data.dart';

class MenuSection {
  const MenuSection({required this.title, required this.dishes});

  final String title;
  final List<Product> dishes;
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cuisines,
    required this.rating,
    required this.ratingCount,
    required this.etaMinutes,
    required this.distanceKm,
    required this.locality,
    required this.costForTwo,
    required this.menu,
    this.gallery = const [],
    this.offerText = '',
    this.pureVeg = false,
    this.isOpen = true,
    this.minOrder = 199,
  });

  final String id;
  final String name;
  final String imageUrl;

  /// Extra restaurant photos shown after [imageUrl] in the home card gallery.
  final List<String> gallery;
  final List<String> cuisines;
  final double rating;
  final int ratingCount;
  final int etaMinutes;
  final double distanceKm;
  final String locality;
  final int costForTwo;
  final List<MenuSection> menu;
  final String offerText;
  final bool pureVeg;
  final bool isOpen;

  /// Minimum bag value before checkout (Swiggy-style restaurant rule).
  final int minOrder;

  bool get hasOffer => offerText.isNotEmpty;

  int get dishCount =>
      menu.fold(0, (sum, section) => sum + section.dishes.length);

  String get etaLabel => '$etaMinutes mins';

  String get etaRangeLabel {
    final lo = (etaMinutes ~/ 5) * 5;
    return '$lo-${lo + 5} mins';
  }

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';

  /// Swipeable card gallery: hero first, then up to six extra photos.
  List<String> get photos {
    final out = <String>[];
    void add(String? url) {
      if (out.length >= 7) return;
      final value = url?.trim();
      if (value == null || value.isEmpty || out.contains(value)) return;
      out.add(value);
    }

    add(imageUrl);
    for (final url in gallery) {
      add(url);
    }
    return out;
  }

  String get cuisineLabel => cuisines.join(', ');

  Iterable<Product> get dishes sync* {
    for (final section in menu) {
      yield* section.dishes;
    }
  }

  bool get hasVegDish => dishes.any((dish) => dish.veg);

  bool get hasNonVegDish => dishes.any((dish) => !dish.veg);
}

class RestaurantCollection {
  const RestaurantCollection({
    required this.title,
    required this.subtitle,
    required this.restaurants,
  });

  final String title;
  final String subtitle;
  final List<Restaurant> restaurants;
}
