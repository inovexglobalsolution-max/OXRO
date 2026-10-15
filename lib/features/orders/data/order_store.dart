import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Order status buckets: active vs past.
enum OrderStatus { processing, shipped, outForDelivery, delivered, cancelled }

/// Delivered + cancelled live in the Past column.

bool isPast(OrderStatus s) =>
    s == OrderStatus.delivered || s == OrderStatus.cancelled;

/// Mock order snapshot for 19 My Orders + 18 Tracking.
class MockOrder {
  const MockOrder({
    required this.id,
    required this.date,
    required this.status,
    required this.products,
    this.deliveredAt,
  });

  final String id;

  /// Display string (UI + tracking).
  final String date;
  final OrderStatus status;
  final List<Product> products;

  /// Real delivery timestamp; null = not delivered yet.
  /// Drives the 48-hr review window (ReviewRepo.canReview).
  final DateTime? deliveredAt;

  int get total =>
      products.fold(0, (s, p) => s + p.price);
}

/// One tracking step (done/current/pending derived by index).
class TrackingStep {
  const TrackingStep({
    required this.label,
    required this.time,
    required this.icon,
  });

  final String label;
  final String time;
  final IconData icon;
}

/// App-wide orders (mock, in-memory).
/// Checkout place appends here later; seeded with ref-like history.
class OrderStore extends ChangeNotifier {
  OrderStore._() {
    _seed();
  }

  /// Global instance (tests call [resetForTests] in setUp).
  static final OrderStore instance = OrderStore._();

  static const _kCache = 'oxro_orders_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._orders.clear();
    instance._seed();
    instance.notifyListeners();
  }

  /// Loads persisted orders incl. user-placed ones (call at splash).
  /// No cache → keeps the seeded history.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      final out = <MockOrder>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final products = [
          for (final v in (m['products'] is List
              ? m['products'] as List
              : const []))
            Product.fromJson(v as Map<String, dynamic>),
        ];
        if (products.isEmpty) continue;
        final statusName = m['status'] as String?;
        final status = OrderStatus.values.cast<OrderStatus?>().firstWhere(
              (s) => s?.name == statusName,
              orElse: () => null,
            );
        if (status == null) continue;
        DateTime? deliveredAt;
        final d = m['deliveredAt'];
        if (d is String) deliveredAt = DateTime.tryParse(d);
        out.add(MockOrder(
          id: (m['id'] as String?) ?? '',
          date: (m['date'] as String?) ?? 'Today',
          status: status,
          products: List<Product>.unmodifiable(products),
          deliveredAt: deliveredAt,
        ));
      }
      if (out.isNotEmpty) {
        _orders
          ..clear()
          ..addAll(out);
        notifyListeners();
      }
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kCache,
          jsonEncode([
            for (final o in _orders)
              {
                'id': o.id,
                'date': o.date,
                'status': o.status.name,
                'products': [
                  for (final pr in o.products) pr.toJson()
                ],
                'deliveredAt':
                    o.deliveredAt?.toIso8601String(),
              },
          ]));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  /// Tests only: prepend a custom order (e.g. delivered for reviews).
  @visibleForTesting
  void injectForTests(MockOrder o) {
    _orders.insert(0, o);
    notifyListeners();
  }

  final List<MockOrder> _orders = [];

  static const _p1 = Product(
    id: 1001,
    name: 'Nike Air Max 270',
    brand: 'Nike',
    price: 6099,
    mrp: 8999,
    rating: 4.3,
    reviews: 12400,
    icon: Icons.directions_run_outlined,
    colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
  );
  static const _p2 = Product(
    id: 1002,
    name: 'Casual Shirt Slim-Fit',
    brand: 'OXRO Select',
    price: 1399,
    mrp: 1999,
    rating: 4.1,
    reviews: 3200,
    icon: Icons.person_outline,
    colors: [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
  );
  static const _p3 = Product(
    id: 1003,
    name: 'Wireless Earbuds Pro',
    brand: 'SonicX',
    price: 2499,
    mrp: 4999,
    rating: 4.5,
    reviews: 21800,
    icon: Icons.headphones_outlined,
    colors: [Color(0xFFE6E6FA), Color(0xFFC4B5FD)],
  );

  void _seed() {
    final now = DateTime.now();
    _orders.addAll([
      MockOrder(
        id: 'OXRO123457',
        date: '12 Aug',
        status: OrderStatus.shipped,
        products: const [_p1, _p2],
      ),
      MockOrder(
        id: 'OXRO123458',
        date: '13 Aug',
        status: OrderStatus.processing,
        products: const [_p3],
      ),
      MockOrder(
        id: 'OXRO123456',
        date: 'Today',
        status: OrderStatus.delivered,
        products: const [_p1, _p2],
        deliveredAt: now.subtract(const Duration(hours: 10)),
      ),
      MockOrder(
        id: 'OXRO123455',
        date: '3 days ago',
        status: OrderStatus.delivered,
        products: const [_p2],
        deliveredAt: now.subtract(const Duration(days: 3)),
      ),
      MockOrder(
        id: 'OXRO123454',
        date: 'Last week',
        status: OrderStatus.delivered,
        products: const [_p3, _p1],
        deliveredAt: now.subtract(const Duration(days: 10)),
      ),
    ]);
  }

  List<MockOrder> get active =>
      List.unmodifiable(_orders.where((o) => !isPast(o.status)));

  List<MockOrder> get past =>
      List.unmodifiable(_orders.where((o) => isPast(o.status)));

  List<MockOrder> get all => List.unmodifiable(_orders);

  /// Reorder: puts all past-order items back into the bag.
  /// Returns units added.
  int reorder(String id) {
    final o = _orders.where((e) => e.id == id);
    if (o.isEmpty) return 0;
    var n = 0;
    for (final p in o.first.products) {
      CartStore.instance.add(p);
      n++;
    }
    return n;
  }

  /// Persists a just-placed order snapshot (qty-expanded products).
  /// Prepends so it tops the Active column. Returns the id.
  /// [deliveredAt] stays null until delivery (drives review window).
  String placeOrder({
    required String id,
    required List<Product> products,
    String date = 'Today',
    DateTime? deliveredAt,
  }) {
    _orders.insert(
      0,
      MockOrder(
        id: id,
        date: date,
        status: OrderStatus.processing,
        products: List<Product>.unmodifiable(products),
        deliveredAt: deliveredAt,
      ),
    );
    _changed();
    return id;
  }

  /// Status for an id; unknown ids fall back to shipped mock.
  OrderStatus statusOf(String id) {
    final o = _orders.where((e) => e.id == id);
    if (o.isEmpty) return OrderStatus.shipped;
    return o.first.status;
  }

  /// 5 tracking steps with mock times per status.
  /// Index < doneCount → done; == doneCount → current (unless
  /// delivered: all done).
  List<TrackingStep> trackingSteps(String id) {
    final st = statusOf(id);
    final date = _orders
            .where((e) => e.id == id)
            .map((e) => e.date)
            .firstOrNull ??
        '12 Aug';
    const times = [
      '10:30 AM',
      '02:15 PM',
      '09:00 AM',
      '04:00 PM',
      '06:00 PM',
    ];
    const labels = [
      'Order Placed',
      'Processing',
      'Shipped',
      'Out for Delivery',
      'Delivered',
    ];
    const icons = [
      Icons.receipt_outlined,
      Icons.hourglass_bottom_outlined,
      Icons.inventory_2_outlined,
      Icons.local_shipping_outlined,
      Icons.home_outlined,
    ];
    return [
      for (var i = 0; i < 5; i++)
        TrackingStep(
          label: labels[i],
          time: i == 0
              ? '$date, ${times[i]}'
              : (i < _doneCount(st)
                  ? '$date, ${times[i]}'
                  : (i == _doneCount(st) &&
                          st != OrderStatus.delivered
                      ? 'now'
                      : (st == OrderStatus.delivered
                          ? '$date, 06:00 PM'
                          : '—'))),
          icon: icons[i],
        ),
    ];
  }

  static int _doneCount(OrderStatus s) {
    return switch (s) {
      OrderStatus.processing => 1,
      OrderStatus.shipped => 3,
      OrderStatus.outForDelivery => 4,
      OrderStatus.delivered => 5,
      OrderStatus.cancelled => 1,
    };
  }

  /// ETA label for the hero pill.
  String etaFor(String id) {
    final st = statusOf(id);
    if (st == OrderStatus.delivered) return 'Delivered';
    final d = DateTime.now().add(const Duration(days: 2));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'ETA ${days[d.weekday - 1]}';
  }
}
