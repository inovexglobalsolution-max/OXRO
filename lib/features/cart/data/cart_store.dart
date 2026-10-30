import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/data/delivery_schedule.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// One cart row — same product in two sizes = two rows.
class CartLine {
  CartLine({
    required this.product,
    required this.qty,
    this.size,
    this.schedule,
  });
  final Product product;
  int qty;

  /// Apparel/footwear pick (e.g. 'M', 'UK 9'); null = one-size
  /// or legacy line persisted before sizes existed.
  final String? size;

  /// Per-line delivery slot for food items; null = no scheduled time.
  DeliverySchedule? schedule;
}

/// App-wide cart (mock, in-memory).
/// Screens share one instance so Home + Listing + PDP stay in sync.
/// Backend cart replaces this later. Riverpod migration noted then.
class CartStore extends ChangeNotifier {
  CartStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final CartStore instance = CartStore._();

  static const _kCache = 'oxro_cart_v2';
  static const _kNote = 'oxro_bag_note_v1';
  static const _kCutlery = 'oxro_bag_cutlery_v1';
  static const _kBagSchedule = 'oxro_bag_schedule_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._lines.clear();
    instance._instructions = '';
    instance._cutleryOptIn = false;
    instance._bagSchedule = null;
    instance.notifyListeners();
  }

  final Map<String, CartLine> _lines = {};
  String _instructions = '';
  bool _cutleryOptIn = false;
  DeliverySchedule? _bagSchedule;

  static String _key(int id, String? size) =>
      size == null || size.isEmpty ? '$id' : '${id}__$size';

  Iterable<CartLine> _forId(int id) =>
      _lines.values.where((l) => l.product.id == id);

  /// Loads persisted bag (call once at splash; corrupt cache → empty).
  /// Pre-size caches (no 'size' field) load as size-less lines.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final product = Product.fromJson(
            m['product'] as Map<String, dynamic>,
          );
          final qty = (m['qty'] as num?)?.toInt() ?? 1;
          final size = m['size'] as String?;
          final schedule = DeliverySchedule.tryFromJson(m['schedule']);
          if (qty > 0) {
            final k = _key(product.id, size);
            final prev = _lines[k];
            if (prev == null) {
              _lines[k] = CartLine(
                product: product,
                qty: qty.clamp(1, 99),
                size: size?.isEmpty == true ? null : size,
                schedule: schedule,
              );
            } else {
              prev.qty = (prev.qty + qty).clamp(1, 99);
              prev.schedule ??= schedule;
            }
          }
        }
      }
      _instructions = p.getString(_kNote) ?? '';
      _cutleryOptIn = p.getBool(_kCutlery) ?? false;
      final bsRaw = p.getString(_kBagSchedule);
      if (bsRaw != null) {
        final bsMap = jsonDecode(bsRaw) as Map?;
        if (bsMap != null) _bagSchedule = DeliverySchedule.tryFromJson(bsMap);
      }
      notifyListeners();
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
          for (final l in _lines.values)
            {
              'qty': l.qty,
              'product': l.product.toJson(),
              if (l.size != null) 'size': l.size,
              if (l.schedule != null) 'schedule': l.schedule!.toJson(),
            },
        ]),
      );
      await p.setString(_kNote, _instructions);
      await p.setBool(_kCutlery, _cutleryOptIn);
      if (_bagSchedule != null) {
        await p.setString(_kBagSchedule, jsonEncode(_bagSchedule!.toJson()));
      }
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  void add(Product p, {String? size}) {
    size = size?.isEmpty == true ? null : size;
    final k = _key(p.id, size);
    final line = _lines[k];
    if (line == null) {
      _lines[k] = CartLine(product: p, qty: 1, size: size);
    } else {
      line.qty++;
    }
    _changed();
  }

  CartLine? _pick(int id, String? size) {
    if (size != null && size.isNotEmpty) {
      return _lines[_key(id, size)];
    }
    final matches = _forId(id).toList();
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.single;
    // Ambiguous (multi-size product, no size given): prefer the
    // size-less line, else the earliest added.
    for (final m in matches) {
      if (m.size == null) return m;
    }
    return matches.first;
  }

  void increment(int id, {String? size}) {
    final line = _pick(id, size);
    if (line == null) return;
    line.qty++;
    _changed();
  }

  void decrement(int id, {String? size}) {
    final line = _pick(id, size);
    if (line == null) return;
    line.qty--;
    if (line.qty <= 0) {
      _lines.remove(_key(line.product.id, line.size));
    }
    _changed();
  }

  void remove(int id, {String? size}) {
    if (size != null && size.isNotEmpty) {
      if (_lines.remove(_key(id, size)) != null) _changed();
      return;
    }
    final keys = [
      for (final e in _lines.entries)
        if (e.value.product.id == id) e.key,
    ];
    if (keys.isEmpty) return;
    for (final k in keys) {
      _lines.remove(k);
    }
    _changed();
  }

  void clear() {
    final hadFoodPrefs = _instructions.isNotEmpty || _cutleryOptIn;
    if (_lines.isEmpty && !hadFoodPrefs) return;
    _lines.clear();
    _instructions = '';
    _cutleryOptIn = false;
    _bagSchedule = null;
    _changed();
  }

  /// Kitchen note for the current food bag (trimmed, max 140 chars).
  String get instructions => _instructions;

  /// Whether the customer wants cutlery included.
  bool get cutleryOptIn => _cutleryOptIn;

  /// Whole-bag delivery slot for the complete meal (null = not scheduled).
  DeliverySchedule? get bagSchedule => _bagSchedule;

  void setInstructions(String value) {
    final next = value.trim();
    final safe = next.length > 140 ? next.substring(0, 140) : next;
    if (safe == _instructions) return;
    _instructions = safe;
    _changed();
  }

  void setCutlery(bool value) {
    if (value == _cutleryOptIn) return;
    _cutleryOptIn = value;
    _changed();
  }

  /// Sets or clears the delivery slot for one product + size line.
  void setSchedule(
    int id, {
    String? size,
    required DeliverySchedule? schedule,
  }) {
    final line = _pick(id, size);
    if (line == null || line.schedule == schedule) return;
    line.schedule = schedule;
    _changed();
  }

  /// Sets or clears the delivery slot for the whole meal (all bag lines).
  void setBagSchedule(DeliverySchedule? schedule) {
    if (_bagSchedule == schedule) return;
    _bagSchedule = schedule;
    _changed();
  }

  /// Total units for a product across all its sizes
  /// (card steppers show the combined count).
  int qty(int id) => _forId(id).fold(0, (sum, l) => sum + l.qty);

  /// Exact units for one product + size.
  int qtyOf(int id, String? size) => _lines[_key(id, size)]?.qty ?? 0;

  bool contains(int id) => _forId(id).isNotEmpty;

  bool containsSize(int id, String size) => _lines.containsKey(_key(id, size));

  /// Total units (bag badge).
  int get count => _lines.values.fold(0, (sum, l) => sum + l.qty);

  /// Distinct products.
  int get distinct => _lines.length;

  /// Restaurant the current bag belongs to (first bound line).
  String? get restaurantId {
    for (final l in _lines.values) {
      final id = l.product.restaurantId;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  String? get restaurantName {
    for (final l in _lines.values) {
      final name = l.product.restaurantName;
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  /// True when [p] comes from a different kitchen than the bag.
  bool belongsToOtherRestaurant(Product p) {
    final current = restaurantId;
    final next = p.restaurantId;
    return _lines.isNotEmpty &&
        current != null &&
        next != null &&
        next.isNotEmpty &&
        current != next;
  }

  /// Replace the whole bag with one line from another kitchen.
  void replaceWith(Product p, {String? size}) {
    size = size?.isEmpty == true ? null : size;
    _lines.clear();
    _lines[_key(p.id, size)] = CartLine(product: p, qty: 1, size: size);
    _changed();
  }

  int get totalMrp =>
      _lines.values.fold(0, (s, l) => s + l.product.mrp * l.qty);

  int get totalPrice =>
      _lines.values.fold(0, (s, l) => s + l.product.price * l.qty);

  int get savings => totalMrp - totalPrice;

  List<CartLine> get lines => List.unmodifiable(_lines.values);
}
