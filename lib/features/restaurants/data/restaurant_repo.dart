import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/features/detail/data/dish_options.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

class RestaurantFilters {
  const RestaurantFilters({
    this.pureVeg = false,
    this.under30 = false,
    this.rating4 = false,
    this.offers = false,
    this.maxCostForTwo,
    this.foodPreference,
  });

  final bool pureVeg;
  final bool under30;
  final bool rating4;
  final bool offers;

  /// Global veg/non-veg preference applied from the home header.
  final FoodPreference? foodPreference;

  /// Maximum cost for two, used by the "Under ₹250" / budget rails.
  final int? maxCostForTwo;

  bool get isActive =>
      pureVeg ||
      under30 ||
      rating4 ||
      offers ||
      maxCostForTwo != null ||
      foodPreference != null;

  int get count =>
      (pureVeg ? 1 : 0) +
      (under30 ? 1 : 0) +
      (rating4 ? 1 : 0) +
      (offers ? 1 : 0) +
      (maxCostForTwo != null ? 1 : 0) +
      (foodPreference != null ? 1 : 0);

  RestaurantFilters copyWith({
    bool? pureVeg,
    bool? under30,
    bool? rating4,
    bool? offers,
    int? maxCostForTwo,
    FoodPreference? foodPreference,
    bool clearMaxCost = false,
    bool clearFoodPreference = false,
  }) {
    return RestaurantFilters(
      pureVeg: pureVeg ?? this.pureVeg,
      under30: under30 ?? this.under30,
      rating4: rating4 ?? this.rating4,
      offers: offers ?? this.offers,
      maxCostForTwo: clearMaxCost ? null : maxCostForTwo ?? this.maxCostForTwo,
      foodPreference: clearFoodPreference
          ? null
          : foodPreference ?? this.foodPreference,
    );
  }
}

enum RestaurantSort { relevance, eta, rating, costLow }

const restaurantSortLabels = {
  RestaurantSort.relevance: 'Relevance',
  RestaurantSort.eta: 'Delivery time',
  RestaurantSort.rating: 'Rating',
  RestaurantSort.costLow: 'Cost: low to high',
};

List<Restaurant> filterRestaurants(
  Iterable<Restaurant> source,
  RestaurantFilters filters,
) {
  return [
    for (final r in source)
      if ((!filters.pureVeg || r.pureVeg) &&
          (!filters.under30 || r.etaMinutes <= 30) &&
          (!filters.rating4 || r.rating >= 4.0) &&
          (!filters.offers || r.hasOffer) &&
          (filters.maxCostForTwo == null ||
              r.costForTwo <= filters.maxCostForTwo!) &&
          (filters.foodPreference == null ||
              (filters.foodPreference == FoodPreference.veg
                  ? r.hasVegDish
                  : r.hasNonVegDish)))
        r,
  ];
}

List<Restaurant> sortRestaurants(
  Iterable<Restaurant> source,
  RestaurantSort sort,
) {
  final list = List<Restaurant>.of(source);
  switch (sort) {
    case RestaurantSort.relevance:
      break;
    case RestaurantSort.eta:
      list.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
    case RestaurantSort.rating:
      list.sort((a, b) => b.rating.compareTo(a.rating));
    case RestaurantSort.costLow:
      list.sort((a, b) => a.costForTwo.compareTo(b.costForTwo));
  }
  return list;
}

class _RestaurantDef {
  const _RestaurantDef({
    required this.id,
    required this.name,
    required this.cuisines,
    required this.rating,
    required this.ratingCount,
    required this.etaMinutes,
    required this.distanceKm,
    required this.locality,
    required this.costForTwo,
    this.offerText = '',
    this.pureVeg = false,
  });

  final String id;
  final String name;
  final List<String> cuisines;
  final double rating;
  final int ratingCount;
  final int etaMinutes;
  final double distanceKm;
  final String locality;
  final int costForTwo;
  final String offerText;
  final bool pureVeg;
}

const _defs = [
  _RestaurantDef(
    id: 'r_paradise',
    name: 'Paradise Biryani',
    cuisines: ['Biryani', 'North Indian', 'Mughlai'],
    rating: 4.5,
    ratingCount: 18400,
    etaMinutes: 28,
    distanceKm: 1.8,
    locality: 'Anna Nagar',
    costForTwo: 450,
    offerText: '50% OFF up to ₹100',
  ),
  _RestaurantDef(
    id: 'r_saravana',
    name: 'Saravana Bhavan',
    cuisines: ['South Indian', 'Breakfast'],
    rating: 4.6,
    ratingCount: 15100,
    etaMinutes: 32,
    distanceKm: 2.4,
    locality: 'T. Nagar',
    costForTwo: 350,
    offerText: 'Free delivery above ₹199',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_a2b',
    name: 'A2B Veg',
    cuisines: ['South Indian', 'North Indian'],
    rating: 4.3,
    ratingCount: 9200,
    etaMinutes: 25,
    distanceKm: 1.2,
    locality: 'Adyar',
    costForTwo: 300,
    offerText: '20% OFF up to ₹80',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_dominos',
    name: "Domino's",
    cuisines: ['Pizza', 'Pasta & Italian'],
    rating: 4.4,
    ratingCount: 21800,
    etaMinutes: 30,
    distanceKm: 3.1,
    locality: 'Velachery',
    costForTwo: 500,
    offerText: 'Buy 1 Get 1 Free',
  ),
  _RestaurantDef(
    id: 'r_burger_king',
    name: 'Burger King',
    cuisines: ['Burgers', 'Sandwiches'],
    rating: 4.2,
    ratingCount: 9700,
    etaMinutes: 24,
    distanceKm: 2.0,
    locality: 'Guindy',
    costForTwo: 400,
    offerText: '60% OFF up to ₹120',
  ),
  _RestaurantDef(
    id: 'r_kfc',
    name: 'KFC',
    cuisines: ['Burgers', 'BBQ & Grills'],
    rating: 4.3,
    ratingCount: 12600,
    etaMinutes: 26,
    distanceKm: 2.7,
    locality: 'Ashok Nagar',
    costForTwo: 450,
    offerText: 'Free delivery above ₹149',
  ),
  _RestaurantDef(
    id: 'r_sangeetha',
    name: 'Sangeetha Veg',
    cuisines: ['South Indian', 'North Indian'],
    rating: 4.4,
    ratingCount: 8200,
    etaMinutes: 29,
    distanceKm: 2.2,
    locality: 'Mylapore',
    costForTwo: 320,
    offerText: '30% OFF up to ₹75',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_anandhas',
    name: 'Anandhas Kitchen',
    cuisines: ['Biryani', 'North Indian', 'Mughlai'],
    rating: 4.1,
    ratingCount: 5400,
    etaMinutes: 35,
    distanceKm: 4.0,
    locality: 'Chromepet',
    costForTwo: 380,
    offerText: 'Flat ₹50 OFF',
  ),
  _RestaurantDef(
    id: 'r_pizza_hut',
    name: 'Pizza Hut',
    cuisines: ['Pizza', 'Pasta & Italian'],
    rating: 4.2,
    ratingCount: 11300,
    etaMinutes: 33,
    distanceKm: 3.6,
    locality: 'OMR',
    costForTwo: 550,
    offerText: '50% OFF up to ₹150',
  ),
  _RestaurantDef(
    id: 'r_cream_stone',
    name: 'Cream Stone',
    cuisines: ['Desserts', 'Beverages'],
    rating: 4.7,
    ratingCount: 6800,
    etaMinutes: 22,
    distanceKm: 1.5,
    locality: 'Besant Nagar',
    costForTwo: 250,
    offerText: '40% OFF up to ₹60',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_chai_snacks',
    name: 'Chai & Snacks',
    cuisines: ['Street Food', 'Chaat', 'Beverages'],
    rating: 4.0,
    ratingCount: 3900,
    etaMinutes: 18,
    distanceKm: 0.8,
    locality: 'Saidapet',
    costForTwo: 150,
    offerText: 'Free delivery above ₹99',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_bbq',
    name: 'BBQ Nation',
    cuisines: ['BBQ & Grills', 'Mughlai'],
    rating: 4.5,
    ratingCount: 7400,
    etaMinutes: 38,
    distanceKm: 4.8,
    locality: 'Nungambakkam',
    costForTwo: 900,
    offerText: '25% OFF up to ₹200',
  ),
  _RestaurantDef(
    id: 'r_shanghai',
    name: 'Shanghai Darbar',
    cuisines: ['Chinese', 'Momos'],
    rating: 4.2,
    ratingCount: 6100,
    etaMinutes: 27,
    distanceKm: 2.6,
    locality: 'Velachery',
    costForTwo: 420,
    offerText: '50% OFF select items',
  ),
  _RestaurantDef(
    id: 'r_roll_nation',
    name: 'Roll Nation',
    cuisines: ['Rolls & Wraps', 'Street Food'],
    rating: 4.1,
    ratingCount: 4700,
    etaMinutes: 21,
    distanceKm: 1.4,
    locality: 'T. Nagar',
    costForTwo: 250,
    offerText: '40% OFF up to ₹120',
  ),
  _RestaurantDef(
    id: 'r_momo_hut',
    name: 'Momo Hut',
    cuisines: ['Momos', 'Tibetan'],
    rating: 4.4,
    ratingCount: 5300,
    etaMinutes: 24,
    distanceKm: 1.9,
    locality: 'Adyar',
    costForTwo: 300,
    offerText: '₹80 OFF above ₹249',
  ),
  _RestaurantDef(
    id: 'r_kolkata_bites',
    name: 'Kolkata Bites',
    cuisines: ['Bengali', 'Street Food'],
    rating: 4.3,
    ratingCount: 3800,
    etaMinutes: 29,
    distanceKm: 2.8,
    locality: 'Park Town',
    costForTwo: 340,
    offerText: '30% OFF select items',
  ),
  _RestaurantDef(
    id: 'r_punjab_dhaba',
    name: 'Punjab Dhaba',
    cuisines: ['Punjabi', 'North Indian'],
    rating: 4.5,
    ratingCount: 8900,
    etaMinutes: 34,
    distanceKm: 3.4,
    locality: 'Anna Nagar',
    costForTwo: 480,
    offerText: '50% OFF up to ₹150',
  ),
  _RestaurantDef(
    id: 'r_coastal_catch',
    name: 'Coastal Catch',
    cuisines: ['Seafood', 'Kerala'],
    rating: 4.4,
    ratingCount: 4200,
    etaMinutes: 36,
    distanceKm: 3.9,
    locality: 'Besant Nagar',
    costForTwo: 600,
    offerText: 'Flat ₹100 OFF',
  ),
  _RestaurantDef(
    id: 'r_kerala_kitchen',
    name: 'Kerala Kitchen',
    cuisines: ['Kerala', 'South Indian'],
    rating: 4.3,
    ratingCount: 5100,
    etaMinutes: 31,
    distanceKm: 2.9,
    locality: 'Mylapore',
    costForTwo: 380,
    offerText: 'Free delivery above ₹199',
  ),
  _RestaurantDef(
    id: 'r_frost_fold',
    name: 'Frost & Fold',
    cuisines: ['Ice Cream', 'Desserts'],
    rating: 4.6,
    ratingCount: 3400,
    etaMinutes: 19,
    distanceKm: 1.1,
    locality: 'Nungambakkam',
    costForTwo: 220,
    offerText: 'Buy 1 Get 1 Free',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_cake_corner',
    name: 'Cake Corner',
    cuisines: ['Bakery & Cakes', 'Desserts'],
    rating: 4.5,
    ratingCount: 4600,
    etaMinutes: 23,
    distanceKm: 1.7,
    locality: 'Velachery',
    costForTwo: 300,
    offerText: '20% OFF up to ₹90',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_shake_street',
    name: 'Shake Street',
    cuisines: ['Juices & Shakes', 'Beverages'],
    rating: 4.2,
    ratingCount: 2900,
    etaMinutes: 17,
    distanceKm: 0.9,
    locality: 'Guindy',
    costForTwo: 200,
    offerText: 'Free delivery above ₹149',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_kaapi_express',
    name: 'Kaapi Express',
    cuisines: ['Tea & Coffee', 'Breakfast'],
    rating: 4.4,
    ratingCount: 3600,
    etaMinutes: 16,
    distanceKm: 0.7,
    locality: 'Saidapet',
    costForTwo: 150,
    offerText: 'Flat ₹40 OFF',
    pureVeg: true,
  ),
  _RestaurantDef(
    id: 'r_green_bowl',
    name: 'Green Bowl',
    cuisines: ['Healthy & Salads', 'Beverages'],
    rating: 4.6,
    ratingCount: 2700,
    etaMinutes: 26,
    distanceKm: 2.1,
    locality: 'Adyar',
    costForTwo: 350,
    offerText: '30% OFF up to ₹100',
    pureVeg: true,
  ),
];

class RestaurantRepo {
  static List<Restaurant>? _cache;

  static List<Restaurant> get all =>
      _cache ??= [for (final d in _defs) _build(d)];

  static Restaurant? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  static Restaurant? byName(String? name) {
    if (name == null) return null;
    for (final r in all) {
      if (r.name == name) return r;
    }
    return null;
  }

  static int _itemId(String restaurantId, int productId) {
    var h = 0x811c9dc5;
    for (final c in '$restaurantId::$productId'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  static Product _dish(Product p, _RestaurantDef d) {
    return Product(
      id: _itemId(d.id, p.id),
      name: p.name,
      brand: d.name,
      restaurantId: d.id,
      restaurantName: d.name,
      veg: p.veg,
      egg: p.egg,
      description: p.description,
      price: p.price,
      mrp: p.mrp,
      rating: p.rating,
      reviews: p.reviews,
      icon: p.icon,
      colors: p.colors,
      imageUrl: p.imageUrl,
      options: dishOptionsFor(p.name),
    );
  }

  static List<MenuSection> _menu(_RestaurantDef d) {
    final sections = <MenuSection>[];
    final seenNames = <String>{};

    List<MenuSection> sectionsFor(String cuisine) {
      final out = <MenuSection>[];
      for (final sub in subcategoriesFor(cuisine).take(2)) {
        final dishes = <Product>[];
        for (final p in ProductRepo.allFor(cuisine, sub)) {
          if (d.pureVeg && !p.veg) continue;
          if (!seenNames.add(p.name.trim().toLowerCase())) continue;
          dishes.add(_dish(p, d));
          if (dishes.length >= 6) break;
        }
        if (dishes.isNotEmpty) {
          out.add(MenuSection(title: sub, dishes: dishes));
        }
      }
      return out;
    }

    for (final cuisine in d.cuisines) {
      sections.addAll(sectionsFor(cuisine));
    }
    if (sections.isEmpty) {
      sections.addAll(sectionsFor('South Indian'));
    }
    return sections;
  }

  /// Cuisine-matched photos used to fill a restaurant gallery when its menu
  /// does not expose seven distinct photos on its own.
  static const _galleryPools = <String, List<String>>{
    'Biryani': [
      FoodMedia.heroBiryani,
      FoodMedia.biryani,
      FoodMedia.biryaniAlt,
      FoodMedia.curry,
      FoodMedia.northIndian,
      FoodMedia.bbq,
      FoodMedia.thali,
    ],
    'Mughlai': [
      FoodMedia.curry,
      FoodMedia.northIndian,
      FoodMedia.bbq,
      FoodMedia.grill,
      FoodMedia.thali,
      FoodMedia.biryaniAlt,
      FoodMedia.biryani,
    ],
    'North Indian': [
      FoodMedia.northIndian,
      FoodMedia.curry,
      FoodMedia.thali,
      FoodMedia.heroThali,
      FoodMedia.bbq,
      FoodMedia.biryani,
      FoodMedia.dessert,
    ],
    'Punjabi': [
      FoodMedia.northIndian,
      FoodMedia.curry,
      FoodMedia.thali,
      FoodMedia.heroThali,
      FoodMedia.bbq,
      FoodMedia.biryani,
      FoodMedia.dessert,
    ],
    'South Indian': [
      FoodMedia.heroSouthIndian,
      FoodMedia.dosa,
      FoodMedia.thali,
      FoodMedia.curry,
      FoodMedia.northIndian,
      FoodMedia.healthy,
      FoodMedia.coffee,
    ],
    'Breakfast': [
      FoodMedia.dosa,
      FoodMedia.heroSouthIndian,
      FoodMedia.thali,
      FoodMedia.healthy,
      FoodMedia.coffee,
      FoodMedia.dessert,
      FoodMedia.streetFood,
    ],
    'Pizza': [
      FoodMedia.heroPizza,
      FoodMedia.pizza,
      FoodMedia.pasta,
      FoodMedia.northIndian,
      FoodMedia.dessert,
      FoodMedia.coffee,
      FoodMedia.salad,
    ],
    'Pasta & Italian': [
      FoodMedia.pasta,
      FoodMedia.heroPizza,
      FoodMedia.pizza,
      FoodMedia.northIndian,
      FoodMedia.dessert,
      FoodMedia.salad,
      FoodMedia.coffee,
    ],
    'Burgers': [
      FoodMedia.burgerFries,
      FoodMedia.burger,
      FoodMedia.grill,
      FoodMedia.sandwich,
      FoodMedia.wrap,
      FoodMedia.dessert,
      FoodMedia.milkshake,
    ],
    'Sandwiches': [
      FoodMedia.sandwich,
      FoodMedia.wrap,
      FoodMedia.burger,
      FoodMedia.burgerFries,
      FoodMedia.healthy,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'BBQ & Grills': [
      FoodMedia.heroBbq,
      FoodMedia.bbq,
      FoodMedia.grill,
      FoodMedia.curry,
      FoodMedia.northIndian,
      FoodMedia.thali,
      FoodMedia.seafood,
    ],
    'Desserts': [
      FoodMedia.heroDessert,
      FoodMedia.dessert,
      FoodMedia.dessertBrownie,
      FoodMedia.milkshake,
      FoodMedia.coffee,
      FoodMedia.streetFood,
      FoodMedia.thali,
    ],
    'Bakery & Cakes': [
      FoodMedia.heroDessert,
      FoodMedia.dessert,
      FoodMedia.dessertBrownie,
      FoodMedia.milkshake,
      FoodMedia.coffee,
      FoodMedia.streetFood,
      FoodMedia.thali,
    ],
    'Ice Cream': [
      FoodMedia.heroDessert,
      FoodMedia.dessertBrownie,
      FoodMedia.dessert,
      FoodMedia.milkshake,
      FoodMedia.coffee,
      FoodMedia.streetFood,
      FoodMedia.thali,
    ],
    'Beverages': [
      FoodMedia.coffee,
      FoodMedia.milkshake,
      FoodMedia.dessert,
      FoodMedia.dessertBrownie,
      FoodMedia.streetFood,
      FoodMedia.sandwich,
      FoodMedia.healthy,
    ],
    'Tea & Coffee': [
      FoodMedia.coffee,
      FoodMedia.milkshake,
      FoodMedia.dessert,
      FoodMedia.dessertBrownie,
      FoodMedia.streetFood,
      FoodMedia.sandwich,
      FoodMedia.healthy,
    ],
    'Juices & Shakes': [
      FoodMedia.milkshake,
      FoodMedia.coffee,
      FoodMedia.dessert,
      FoodMedia.dessertBrownie,
      FoodMedia.healthy,
      FoodMedia.sandwich,
      FoodMedia.streetFood,
    ],
    'Street Food': [
      FoodMedia.streetFood,
      FoodMedia.momos,
      FoodMedia.sandwich,
      FoodMedia.wrap,
      FoodMedia.chinese,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Chaat': [
      FoodMedia.streetFood,
      FoodMedia.momos,
      FoodMedia.sandwich,
      FoodMedia.wrap,
      FoodMedia.chinese,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Chinese': [
      FoodMedia.chinese,
      FoodMedia.streetFood,
      FoodMedia.momos,
      FoodMedia.bbq,
      FoodMedia.grill,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Momos': [
      FoodMedia.momos,
      FoodMedia.chinese,
      FoodMedia.streetFood,
      FoodMedia.grill,
      FoodMedia.bbq,
      FoodMedia.wrap,
      FoodMedia.dessert,
    ],
    'Tibetan': [
      FoodMedia.momos,
      FoodMedia.chinese,
      FoodMedia.streetFood,
      FoodMedia.grill,
      FoodMedia.bbq,
      FoodMedia.wrap,
      FoodMedia.dessert,
    ],
    'Rolls & Wraps': [
      FoodMedia.wrap,
      FoodMedia.sandwich,
      FoodMedia.streetFood,
      FoodMedia.burger,
      FoodMedia.grill,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Bengali': [
      FoodMedia.curry,
      FoodMedia.thali,
      FoodMedia.seafood,
      FoodMedia.northIndian,
      FoodMedia.streetFood,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Kerala': [
      FoodMedia.seafood,
      FoodMedia.curry,
      FoodMedia.thali,
      FoodMedia.grill,
      FoodMedia.northIndian,
      FoodMedia.dessert,
      FoodMedia.coffee,
    ],
    'Seafood': [
      FoodMedia.seafood,
      FoodMedia.grill,
      FoodMedia.curry,
      FoodMedia.thali,
      FoodMedia.northIndian,
      FoodMedia.bbq,
      FoodMedia.dessert,
    ],
    'Healthy & Salads': [
      FoodMedia.heroHealthy,
      FoodMedia.healthy,
      FoodMedia.salad,
      FoodMedia.grill,
      FoodMedia.seafood,
      FoodMedia.wrap,
      FoodMedia.dessert,
    ],
  };

  /// Up to seven unique photos: hero, menu dishes, then cuisine-matched fill.
  static List<String> _gallery(_RestaurantDef d, List<MenuSection> menu) {
    final out = <String>[];
    void add(String? url) {
      if (out.length >= 7) return;
      final value = url?.trim();
      if (value == null || value.isEmpty || out.contains(value)) return;
      out.add(value);
    }

    add(FoodMedia.forRestaurant(d.id, d.name));
    for (final section in menu) {
      for (final dish in section.dishes) {
        add(dish.imageUrl);
        if (out.length >= 7) return out;
      }
    }
    for (final cuisine in d.cuisines) {
      for (final url in _galleryPools[cuisine] ?? const <String>[]) {
        add(url);
        if (out.length >= 7) return out;
      }
    }
    for (final url in FoodMedia.all) {
      add(url);
      if (out.length >= 7) break;
    }
    return out;
  }

  static Restaurant _build(_RestaurantDef d) {
    final menu = _menu(d);
    return Restaurant(
      id: d.id,
      name: d.name,
      imageUrl: FoodMedia.forRestaurant(d.id, d.name),
      gallery: _gallery(d, menu),
      cuisines: d.cuisines,
      rating: d.rating,
      ratingCount: d.ratingCount,
      etaMinutes: d.etaMinutes,
      distanceKm: d.distanceKm,
      locality: d.locality,
      costForTwo: d.costForTwo,
      offerText: d.offerText,
      pureVeg: d.pureVeg,
      menu: menu,
    );
  }

  static List<Restaurant> forCuisine(String cuisine) {
    final n = cuisine.toLowerCase();
    return [
      for (final r in all)
        if (r.cuisines.any((c) => c.toLowerCase() == n) ||
            r.menu.any((s) => s.title.toLowerCase() == n))
          r,
    ];
  }

  static List<Restaurant> search(String query) {
    final n = query.trim().toLowerCase();
    if (n.isEmpty) return all;
    final scored = <MapEntry<int, Restaurant>>[];
    for (final r in all) {
      var score = 0;
      final name = r.name.toLowerCase();
      if (name == n) {
        score += 100;
      } else if (name.startsWith(n)) {
        score += 60;
      } else if (name.contains(n)) {
        score += 40;
      }
      if (r.cuisines.any((c) => c.toLowerCase().contains(n))) {
        score += 30;
      }
      if (r.locality.toLowerCase().contains(n)) score += 10;
      if (r.dishes.any((p) => p.name.toLowerCase().contains(n))) {
        score += 15;
      }
      if (score > 0) scored.add(MapEntry(score, r));
    }
    scored.sort((a, b) {
      final byScore = b.key.compareTo(a.key);
      return byScore != 0
          ? byScore
          : a.value.etaMinutes.compareTo(b.value.etaMinutes);
    });
    return [for (final e in scored) e.value];
  }

  static List<Restaurant> dishesFor(String query) {
    final n = query.trim().toLowerCase();
    if (n.isEmpty) return all;
    return [
      for (final r in all)
        if (r.dishes.any((p) => p.name.toLowerCase().contains(n))) r,
    ];
  }

  static List<Restaurant> get topRated {
    final list = List<Restaurant>.of(all)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return list.take(8).toList();
  }

  static List<Restaurant> get fastDelivery {
    final list = List<Restaurant>.of(all)
      ..sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
    return list.take(8).toList();
  }

  static List<Restaurant> get pureVeg => [
    for (final r in all)
      if (r.pureVeg) r,
  ];

  static List<Restaurant> get offers => [
    for (final r in all)
      if (r.hasOffer) r,
  ];

  static List<RestaurantCollection> get collections => [
    RestaurantCollection(
      title: 'Top rated near you',
      subtitle: 'Loved by your neighbourhood',
      restaurants: topRated,
    ),
    RestaurantCollection(
      title: 'Delivered in 30 mins',
      subtitle: 'Fast favourites around you',
      restaurants: fastDelivery,
    ),
    RestaurantCollection(
      title: 'Best offers',
      subtitle: 'Save more on every order',
      restaurants: offers.take(8).toList(),
    ),
  ];
}
