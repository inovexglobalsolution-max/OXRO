/// One promo coupon (mock, in-memory).
/// Percent coupons use [off] as % with [cap] max rupees.
class Coupon {
  const Coupon({
    required this.code,
    required this.title,
    required this.sub,
    required this.off,
    this.percent = false,
    this.cap = 0,
    required this.minOrder,
    this.freeShip = false,
  });

  final String code;
  final String title;
  final String sub;
  final int off;
  final bool percent;
  final int cap;
  final int minOrder;
  final bool freeShip;

  /// Rupees saved on [total]; 0 when below [minOrder].
  int discountFor(int total) {
    if (total < minOrder) return 0;
    if (percent) return ((total * off / 100).round()).clamp(0, cap);
    return off;
  }
}

/// All coupons (Supabase promos replace later).
class CouponStore {
  static const coupons = [
    Coupon(
      code: 'OXRO500',
      title: 'Flat Rs.500 OFF',
      sub: 'On orders above Rs.2,999',
      off: 500,
      minOrder: 2999,
    ),
    Coupon(
      code: 'WELCOME10',
      title: '10% OFF up to Rs.300',
      sub: 'On orders above Rs.999',
      off: 10,
      percent: true,
      cap: 300,
      minOrder: 999,
    ),
    Coupon(
      code: 'FEST200',
      title: 'Flat Rs.200 OFF',
      sub: 'On orders above Rs.1,499',
      off: 200,
      minOrder: 1499,
    ),
    Coupon(
      code: 'FREESHIP',
      title: 'Free Delivery',
      sub: 'No shipping fee above Rs.499',
      off: 0,
      minOrder: 499,
      freeShip: true,
    ),
  ];

  /// Case-insensitive lookup; null when unknown.
  static Coupon? byCode(String code) {
    final c = code.trim().toUpperCase();
    for (final k in coupons) {
      if (k.code == c) return k;
    }
    return null;
  }

  /// Eligible for [total], best saving first.
  /// Free-ship valued at [shipValue] for ranking.
  static List<Coupon> eligibleFor(int total, {int shipValue = 40}) {
    final list = [
      for (final k in coupons)
        if (total >= k.minOrder) k,
    ];
    list.sort((a, b) {
      final va = a.discountFor(total) + (a.freeShip ? shipValue : 0);
      final vb = b.discountFor(total) + (b.freeShip ? shipValue : 0);
      return vb.compareTo(va);
    });
    return list;
  }
}
