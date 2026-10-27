import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/detail/data/product_sizes.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';

/// Order status buckets: active vs past.
enum OrderStatus { processing, shipped, outForDelivery, delivered, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.processing => 'Order confirmed',
    OrderStatus.shipped => 'Preparing',
    OrderStatus.outForDelivery => 'On the way',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };
}

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
    this.restaurantId,
    this.restaurantName,
    this.instructions,
    this.cutleryOptIn,
    this.deliveredAt,
    this.bill,
  });

  final String id;

  /// Display string (UI + tracking).
  final String date;
  final OrderStatus status;
  final List<Product> products;

  /// Kitchen this order was placed with (null on legacy orders).
  final String? restaurantId;
  final String? restaurantName;

  /// Kitchen note captured at checkout (null when none).
  final String? instructions;

  /// Cutlery choice captured at checkout (null on legacy/seeded orders).
  final bool? cutleryOptIn;

  String? get kitchenName {
    if (restaurantName != null && restaurantName!.isNotEmpty) {
      return restaurantName;
    }
    if (products.isEmpty) return null;
    final name = products.first.restaurantName;
    return name == null || name.isEmpty ? null : name;
  }

  /// Real delivery timestamp; null = not delivered yet.
  /// Drives the 48-hr review window (ReviewRepo.canReview).
  final DateTime? deliveredAt;

  /// Frozen bill snapshot; null on legacy/seeded orders.
  final OrderBill? bill;

  int get total => products.fold(0, (s, p) => s + p.price);

  /// Amount charged to the customer in paise (bill snapshot when present).
  int get payablePaise => bill?.grandTotalPaise ?? total * 100;
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

  static const _kCache = 'oxro_orders_v2';

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
          for (final v
              in (m['products'] is List ? m['products'] as List : const []))
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
        out.add(
          MockOrder(
            id: (m['id'] as String?) ?? '',
            date: (m['date'] as String?) ?? 'Today',
            status: status,
            products: List<Product>.unmodifiable(products),
            restaurantId: m['restaurantId'] as String?,
            restaurantName: m['restaurantName'] as String?,
            instructions: m['instructions'] as String?,
            cutleryOptIn: m['cutleryOptIn'] as bool?,
            deliveredAt: deliveredAt,
            bill: m['bill'] is Map<String, dynamic>
                ? OrderBill.fromJson(m['bill'] as Map<String, dynamic>)
                : null,
          ),
        );
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
              if (o.restaurantId != null) 'restaurantId': o.restaurantId,
              if (o.restaurantName != null) 'restaurantName': o.restaurantName,
              if (o.instructions != null) 'instructions': o.instructions,
              if (o.cutleryOptIn != null) 'cutleryOptIn': o.cutleryOptIn,
              'products': [for (final pr in o.products) pr.toJson()],
              'deliveredAt': o.deliveredAt?.toIso8601String(),
              if (o.bill != null) 'bill': o.bill!.toJson(),
            },
        ]),
      );
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

  static Product _dishAt(Restaurant restaurant, int index) {
    final dishes = restaurant.dishes.toList();
    return dishes[index % dishes.length];
  }

  static OrderBill _seedBill(List<Product> items) {
    final subtotal = items.fold(0, (s, p) => s + p.price) * 100;
    const packaging = 2000;
    final delivery = subtotal >= 49900 ? 0 : 3000;
    const platform = 500;
    final tax = (subtotal * 5 / 100).round();
    return OrderBill(
      itemSubtotalPaise: subtotal,
      packagingPaise: packaging,
      deliveryPaise: delivery,
      platformFeePaise: platform,
      taxPaise: tax,
      tipPaise: 0,
      discountPaise: 0,
      grandTotalPaise: subtotal + packaging + delivery + platform + tax,
      configVersion: 1,
    );
  }

  void _seed() {
    final now = DateTime.now();
    final paradise = RestaurantRepo.byId('r_paradise')!;
    final saravana = RestaurantRepo.byId('r_saravana')!;
    final dominos = RestaurantRepo.byId('r_dominos')!;
    final bbq = RestaurantRepo.byId('r_bbq')!;

    final paradiseItems = [_dishAt(paradise, 0), _dishAt(paradise, 1)];
    final saravanaDosa = _dishAt(saravana, 0);
    final saravanaIdli = _dishAt(saravana, 2);
    final dominosItems = [_dishAt(dominos, 0), _dishAt(dominos, 1)];
    final bbqItems = [_dishAt(bbq, 0), _dishAt(bbq, 1)];

    _orders.addAll([
      MockOrder(
        id: 'OXRO123457',
        date: '12 Aug',
        status: OrderStatus.shipped,
        products: paradiseItems,
        restaurantId: paradise.id,
        restaurantName: paradise.name,
        bill: _seedBill(paradiseItems),
      ),
      MockOrder(
        id: 'OXRO123458',
        date: '13 Aug',
        status: OrderStatus.processing,
        products: [saravanaDosa],
        restaurantId: saravana.id,
        restaurantName: saravana.name,
        bill: _seedBill([saravanaDosa]),
      ),
      MockOrder(
        id: 'OXRO123456',
        date: 'Today',
        status: OrderStatus.delivered,
        products: dominosItems,
        restaurantId: dominos.id,
        restaurantName: dominos.name,
        deliveredAt: now.subtract(const Duration(hours: 10)),
        bill: _seedBill(dominosItems),
      ),
      MockOrder(
        id: 'OXRO123455',
        date: '3 days ago',
        status: OrderStatus.delivered,
        products: [saravanaIdli],
        restaurantId: saravana.id,
        restaurantName: saravana.name,
        deliveredAt: now.subtract(const Duration(days: 3)),
        bill: _seedBill([saravanaIdli]),
      ),
      MockOrder(
        id: 'OXRO123454',
        date: 'Last week',
        status: OrderStatus.delivered,
        products: bbqItems,
        restaurantId: bbq.id,
        restaurantName: bbq.name,
        deliveredAt: now.subtract(const Duration(days: 10)),
        bill: _seedBill(bbqItems),
      ),
    ]);
  }

  List<MockOrder> get active =>
      List.unmodifiable(_orders.where((o) => !isPast(o.status)));

  List<MockOrder> get past =>
      List.unmodifiable(_orders.where((o) => isPast(o.status)));

  List<MockOrder> get all => List.unmodifiable(_orders);

  MockOrder? byId(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Reorder: puts all past-order items back into the bag.
  /// Returns units added.
  int reorder(String id) {
    final o = byId(id);
    if (o == null) return 0;
    final kitchen = o.restaurantId;
    if (kitchen != null &&
        kitchen.isNotEmpty &&
        CartStore.instance.restaurantId != kitchen) {
      CartStore.instance.clear();
    }
    var n = 0;
    for (final p in o.products) {
      CartStore.instance.add(p, size: defaultSizeFor(p));
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
    String? restaurantId,
    String? restaurantName,
    String? instructions,
    bool? cutleryOptIn,
    String date = 'Today',
    DateTime? deliveredAt,
    OrderBill? bill,
  }) {
    _orders.insert(
      0,
      MockOrder(
        id: id,
        date: date,
        status: OrderStatus.processing,
        products: List<Product>.unmodifiable(products),
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        instructions: instructions,
        cutleryOptIn: cutleryOptIn,
        deliveredAt: deliveredAt,
        bill: bill,
      ),
    );
    _changed();
    return id;
  }

  /// Status for an id; unknown ids fall back to shipped mock.
  OrderStatus statusOf(String id) {
    return byId(id)?.status ?? OrderStatus.shipped;
  }

  /// 5 tracking steps with mock times per status.
  /// Index < doneCount → done; == doneCount → current (unless
  /// delivered: all done).
  List<TrackingStep> trackingSteps(String id) {
    final st = statusOf(id);
    final date = byId(id)?.date ?? 'Today';
    const times = ['10:30 AM', '10:36 AM', '10:42 AM', '10:55 AM', '11:10 AM'];
    const labels = [
      'Order Placed',
      'Restaurant accepted',
      'Being prepared',
      'On the way',
      'Delivered',
    ];
    const icons = [
      Icons.receipt_outlined,
      Icons.storefront_outlined,
      Icons.restaurant_outlined,
      Icons.delivery_dining,
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
                              st != OrderStatus.delivered &&
                              st != OrderStatus.cancelled
                          ? 'now'
                          : (st == OrderStatus.delivered
                                ? '$date, 11:10 AM'
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
    if (st == OrderStatus.cancelled) return 'Cancelled';
    return 'ETA ${arrivalWindowFor(id)}';
  }

  /// Customer-facing arrival window for an active order.
  /// Terminal statuses return their label instead of a window.
  String arrivalWindowFor(String id) {
    final st = statusOf(id);
    final order = byId(id);
    final kitchen = order?.restaurantId == null
        ? null
        : RestaurantRepo.byId(order!.restaurantId!);
    final base = kitchen?.etaMinutes ?? 35;
    return switch (st) {
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.outForDelivery => '10-15 mins',
      OrderStatus.shipped => '${_lo(base, 10)}-$base mins',
      _ => '${_lo(base, 5)}-${base + 5} mins',
    };
  }

  int _lo(int base, int offset) {
    final v = base - offset;
    return v < 15 ? 15 : v;
  }
}
