import 'package:oxro/app/data/food_media.dart';

class DineoutRestaurant {
  const DineoutRestaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cuisines,
    required this.area,
    required this.rating,
    required this.ratingCount,
    required this.costForTwo,
    required this.offerText,
    required this.distanceKm,
    required this.slots,
    this.pureVeg = false,
  });

  final String id;
  final String name;
  final String imageUrl;
  final List<String> cuisines;
  final String area;
  final double rating;
  final int ratingCount;
  final int costForTwo;
  final String offerText;
  final double distanceKm;
  final List<String> slots;
  final bool pureVeg;

  bool get hasOffer => offerText.isNotEmpty;

  String get cuisineLabel => cuisines.join(' • ');

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';
}

class DineoutRepo {
  DineoutRepo._();

  static const cuisines = ['All', 'Italian', 'North Indian', 'Asian', 'Cafe'];

  static const all = <DineoutRestaurant>[
    DineoutRestaurant(
      id: 'd_verandah',
      name: 'The Verandah',
      imageUrl: FoodMedia.pasta,
      cuisines: ['Italian', 'Continental'],
      area: 'Anna Nagar',
      rating: 4.6,
      ratingCount: 2140,
      costForTwo: 1800,
      offerText: '25% off on the food bill',
      distanceKm: 2.1,
      slots: ['7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM'],
    ),
    DineoutRestaurant(
      id: 'd_copper_clay',
      name: 'Copper & Clay',
      imageUrl: FoodMedia.curry,
      cuisines: ['North Indian', 'Mughlai'],
      area: 'Nungambakkam',
      rating: 4.5,
      ratingCount: 3400,
      costForTwo: 1600,
      offerText: 'Complimentary dessert',
      distanceKm: 3.4,
      slots: ['6:30 PM', '7:00 PM', '7:30 PM', '8:30 PM'],
    ),
    DineoutRestaurant(
      id: 'd_miso_street',
      name: 'Miso Street',
      imageUrl: FoodMedia.chinese,
      cuisines: ['Asian', 'Japanese'],
      area: 'Alwarpet',
      rating: 4.4,
      ratingCount: 1800,
      costForTwo: 2000,
      offerText: 'Buy 1 get 1 on cocktails',
      distanceKm: 4.0,
      slots: ['7:00 PM', '8:00 PM', '9:00 PM'],
    ),
    DineoutRestaurant(
      id: 'd_filter_room',
      name: 'The Filter Room',
      imageUrl: FoodMedia.coffee,
      cuisines: ['Cafe', 'Bakery'],
      area: 'T. Nagar',
      rating: 4.3,
      ratingCount: 1200,
      costForTwo: 900,
      offerText: '20% off on brunch',
      distanceKm: 1.7,
      slots: ['10:00 AM', '12:30 PM', '4:00 PM', '6:30 PM'],
      pureVeg: true,
    ),
    DineoutRestaurant(
      id: 'd_saffron_house',
      name: 'Saffron House',
      imageUrl: FoodMedia.thali,
      cuisines: ['North Indian', 'Rajasthani'],
      area: 'Adyar',
      rating: 4.7,
      ratingCount: 4100,
      costForTwo: 2200,
      offerText: "Chef's tasting menu",
      distanceKm: 5.2,
      slots: ['7:30 PM', '8:00 PM', '8:30 PM'],
      pureVeg: true,
    ),
    DineoutRestaurant(
      id: 'd_basil_bloom',
      name: 'Basil & Bloom',
      imageUrl: FoodMedia.salad,
      cuisines: ['Italian', 'Healthy'],
      area: 'Besant Nagar',
      rating: 4.2,
      ratingCount: 980,
      costForTwo: 1400,
      offerText: 'Free mocktail on arrival',
      distanceKm: 6.1,
      slots: ['12:00 PM', '1:00 PM', '7:00 PM', '8:00 PM'],
    ),
  ];

  static DineoutRestaurant? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  static List<DineoutRestaurant> filter({
    String cuisine = 'All',
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return [
      for (final r in all)
        if ((cuisine == 'All' || r.cuisines.contains(cuisine)) &&
            (q.isEmpty ||
                r.name.toLowerCase().contains(q) ||
                r.area.toLowerCase().contains(q) ||
                r.cuisines.any((c) => c.toLowerCase().contains(q))))
          r,
    ];
  }
}
