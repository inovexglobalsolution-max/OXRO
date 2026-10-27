/// Bundled food photography used across the delivery experience.
///
/// Keeping images local guarantees every card has a real photo even when the
/// device is offline or the remote CDN is slow. Category/dish names fall back
/// to the closest visual so generated catalogue items never render an icon.
class FoodMedia {
  FoodMedia._();

  static const biryani = 'assets/food/biryani.jpg';
  static const biryaniAlt = 'assets/food/biryani_alt.jpg';
  static const curry = 'assets/food/curry.jpg';
  static const northIndian = 'assets/food/north_indian.jpg';
  static const dosa = 'assets/food/dosa.jpg';
  static const chinese = 'assets/food/chinese.jpg';
  static const pizza = 'assets/food/pizza.jpg';
  static const burger = 'assets/food/burger.jpg';
  static const burgerFries = 'assets/food/burger_fries.jpg';
  static const wrap = 'assets/food/wrap.jpg';
  static const sandwich = 'assets/food/sandwich.jpg';
  static const momos = 'assets/food/momos.jpg';
  static const pasta = 'assets/food/pasta.jpg';
  static const streetFood = 'assets/food/street_food.jpg';
  static const dessert = 'assets/food/dessert.jpg';
  static const dessertBrownie = 'assets/food/dessert_brownie.jpg';
  static const coffee = 'assets/food/coffee.jpg';
  static const healthy = 'assets/food/healthy.jpg';
  static const salad = 'assets/food/salad.jpg';
  static const seafood = 'assets/food/seafood.jpg';
  static const bbq = 'assets/food/bbq.jpg';
  static const grill = 'assets/food/grill.jpg';
  static const milkshake = 'assets/food/milkshake.jpg';
  static const thali = 'assets/food/thali.jpg';

  static const heroBiryani = 'assets/food/hero_biryani.jpg';
  static const heroPizza = 'assets/food/hero_pizza.jpg';
  static const heroSouthIndian = 'assets/food/hero_south_indian.jpg';
  static const heroDessert = 'assets/food/hero_dessert.jpg';
  static const heroThali = 'assets/food/hero_thali.jpg';
  static const heroBbq = 'assets/food/hero_bbq.jpg';
  static const heroHealthy = 'assets/food/hero_healthy.jpg';

  static const all = <String>[
    biryani,
    biryaniAlt,
    curry,
    northIndian,
    dosa,
    chinese,
    pizza,
    burger,
    burgerFries,
    wrap,
    sandwich,
    momos,
    pasta,
    streetFood,
    dessert,
    dessertBrownie,
    coffee,
    healthy,
    salad,
    seafood,
    bbq,
    grill,
    milkshake,
    thali,
    heroBiryani,
    heroPizza,
    heroSouthIndian,
    heroDessert,
    heroThali,
    heroBbq,
    heroHealthy,
  ];

  static const _biryaniPool = [biryani, biryaniAlt];
  static const _southPool = [dosa, heroSouthIndian];
  static const _pizzaPool = [pizza, heroPizza];
  static const _burgerPool = [burger, burgerFries];
  static const _wrapPool = [wrap, sandwich];
  static const _momoPool = [momos, chinese];
  static const _pastaPool = [pasta, northIndian];
  static const _chinesePool = [chinese, streetFood, momos];
  static const _dessertPool = [dessert, dessertBrownie, heroDessert];
  static const _coffeePool = [coffee, milkshake];
  static const _shakePool = [milkshake, coffee];
  static const _healthyPool = [healthy, salad, heroHealthy];
  static const _seafoodPool = [seafood, grill];
  static const _bbqPool = [bbq, grill, heroBbq];
  static const _breadPool = [thali, curry];
  static const _curryPool = [northIndian, curry, thali];

  static bool isAsset(String? path) =>
      path != null && path.startsWith('assets/');

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.toLowerCase().codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Stable pick from a category pool. Passing a catalogue index makes
  /// adjacent dishes alternate instead of repeating one hero photo.
  static String _pick(List<String> pool, String name, {int? variant}) {
    final index = (variant ?? _stableHash(name)).abs() % pool.length;
    return pool[index];
  }

  static String forCategory(String label) {
    switch (label) {
      case 'Biryani':
        return biryani;
      case 'North Indian':
        return northIndian;
      case 'South Indian':
        return dosa;
      case 'Chinese':
      case 'Thai':
        return chinese;
      case 'Pizza':
        return pizza;
      case 'Burgers':
        return burger;
      case 'Rolls & Wraps':
        return wrap;
      case 'Sandwiches':
        return sandwich;
      case 'Momos':
      case 'Tibetan':
        return momos;
      case 'Pasta & Italian':
        return pasta;
      case 'Mughlai':
      case 'Bengali':
      case 'Kerala':
        return curry;
      case 'Punjabi':
        return northIndian;
      case 'Gujarati':
      case 'Rajasthani':
        return thali;
      case 'Street Food':
      case 'Chaat':
        return streetFood;
      case 'Desserts':
      case 'Bakery & Cakes':
        return dessert;
      case 'Ice Cream':
        return dessertBrownie;
      case 'Beverages':
      case 'Tea & Coffee':
        return coffee;
      case 'Juices & Shakes':
        return milkshake;
      case 'Healthy & Salads':
        return healthy;
      case 'Breakfast':
        return dosa;
      case 'Seafood':
        return seafood;
      case 'BBQ & Grills':
        return bbq;
      default:
        return thali;
    }
  }

  static String forRestaurant(String? id, [String? name]) {
    switch (id) {
      case 'r_paradise':
        return heroBiryani;
      case 'r_anandhas':
        return curry;
      case 'r_saravana':
      case 'r_a2b':
        return heroSouthIndian;
      case 'r_dominos':
      case 'r_pizza_hut':
        return heroPizza;
      case 'r_burger_king':
        return burgerFries;
      case 'r_kfc':
        return grill;
      case 'r_sangeetha':
        return heroThali;
      case 'r_cream_stone':
        return heroDessert;
      case 'r_chai_snacks':
        return streetFood;
      case 'r_bbq':
        return heroBbq;
      case 'r_shanghai':
        return chinese;
      case 'r_roll_nation':
        return wrap;
      case 'r_momo_hut':
        return momos;
      case 'r_kolkata_bites':
        return streetFood;
      case 'r_punjab_dhaba':
        return northIndian;
      case 'r_coastal_catch':
      case 'r_kerala_kitchen':
        return seafood;
      case 'r_frost_fold':
      case 'r_cake_corner':
        return heroDessert;
      case 'r_shake_street':
        return milkshake;
      case 'r_kaapi_express':
        return coffee;
      case 'r_green_bowl':
        return healthy;
    }
    final n = (name ?? '').toLowerCase();
    if (n.contains('biryani')) return biryaniAlt;
    if (n.contains('pizza')) return pizza;
    if (n.contains('burger') || n.contains('kfc')) return burger;
    if (n.contains('veg') || n.contains('bhavan')) return dosa;
    if (n.contains('cream') || n.contains('dessert')) return dessertBrownie;
    if (n.contains('chai') || n.contains('snack')) return streetFood;
    if (n.contains('bbq') || n.contains('grill')) return bbq;
    return thali;
  }

  static String forDish(String name, {String? category, int? variant}) {
    final n = name.toLowerCase();
    if (n.contains('biryani') || n.contains('pulao')) {
      return _pick(_biryaniPool, name, variant: variant);
    }
    if (n.contains('dosa') ||
        n.contains('idli') ||
        n.contains('vada') ||
        n.contains('uttapam') ||
        n.contains('upma') ||
        n.contains('pongal')) {
      return _pick(_southPool, name, variant: variant);
    }
    if (n.contains('pizza') || n.contains('garlic bread')) {
      return _pick(_pizzaPool, name, variant: variant);
    }
    if (n.contains('burger')) {
      return _pick(_burgerPool, name, variant: variant);
    }
    if (n.contains('fries')) return burgerFries;
    if (n.contains('roll') || n.contains('wrap')) {
      return _pick(_wrapPool, name, variant: variant);
    }
    if (n.contains('sandwich')) {
      return _pick(_wrapPool, name, variant: variant);
    }
    if (n.contains('momo') || n.contains('dumpling')) {
      return _pick(_momoPool, name, variant: variant);
    }
    if (n.contains('pasta') ||
        n.contains('spaghetti') ||
        n.contains('macaroni')) {
      return _pick(_pastaPool, name, variant: variant);
    }
    if (n.contains('noodle') ||
        n.contains('fried rice') ||
        n.contains('manchurian') ||
        n.contains('chilli') ||
        n.contains('spring roll')) {
      return _pick(_chinesePool, name, variant: variant);
    }
    if (n.contains('cake') ||
        n.contains('brownie') ||
        n.contains('ice cream') ||
        n.contains('sundae') ||
        n.contains('gulab') ||
        n.contains('jamun') ||
        n.contains('halwa') ||
        n.contains('dessert')) {
      return _pick(_dessertPool, name, variant: variant);
    }
    if (n.contains('coffee') || n.contains('tea') || n.contains('chai')) {
      return _pick(_coffeePool, name, variant: variant);
    }
    if (n.contains('shake') ||
        n.contains('smoothie') ||
        n.contains('juice') ||
        n.contains('lassi')) {
      return _pick(_shakePool, name, variant: variant);
    }
    if (n.contains('salad') ||
        n.contains('healthy') ||
        n.contains('bowl') ||
        n.contains('grilled chicken')) {
      return _pick(_healthyPool, name, variant: variant);
    }
    if (n.contains('fish') ||
        n.contains('prawn') ||
        n.contains('seafood') ||
        n.contains('crab')) {
      return _pick(_seafoodPool, name, variant: variant);
    }
    if (n.contains('tandoori') ||
        n.contains('kebab') ||
        n.contains('kabab') ||
        n.contains('bbq') ||
        n.contains('grill')) {
      return _pick(_bbqPool, name, variant: variant);
    }
    if (n.contains('naan') ||
        n.contains('roti') ||
        n.contains('paratha') ||
        n.contains('thali') ||
        n.contains('combo')) {
      return _pick(_breadPool, name, variant: variant);
    }
    if (n.contains('paneer') ||
        n.contains('curry') ||
        n.contains('masala') ||
        n.contains('butter chicken') ||
        n.contains('dal')) {
      return _pick(_curryPool, name, variant: variant);
    }
    return category == null ? thali : forCategory(category);
  }
}
