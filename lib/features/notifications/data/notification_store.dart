import 'package:flutter/material.dart';

/// Notification kind: order updates vs offers.
enum NotifKind { order, offer }

/// One inbox row.
class OxroNotif {
  const OxroNotif({
    required this.id,
    required this.title,
    required this.sub,
    required this.time,
    required this.icon,
    required this.kind,
    this.unread = true,
  });

  final String id;
  final String title;
  final String sub;
  final String time;
  final IconData icon;
  final NotifKind kind;
  final bool unread;

  OxroNotif copyWith({bool? unread}) => OxroNotif(
        id: id,
        title: title,
        sub: sub,
        time: time,
        icon: icon,
        kind: kind,
        unread: unread ?? this.unread,
      );
}

/// Notifications inbox (mock, in-memory).
/// Backend push replaces seeding later.
class NotifStore extends ChangeNotifier {
  NotifStore._() {
    _items.addAll(_seed);
  }

  /// Global instance (tests call [resetForTests] in setUp).
  static final NotifStore instance = NotifStore._();

  @visibleForTesting
  static void resetForTests() {
    instance._items
      ..clear()
      ..addAll(_seed);
    instance._enabled = true;
    instance._lastRemoved = null;
    instance._lastIndex = 0;
    instance.notifyListeners();
  }

  static const _seed = [
    OxroNotif(
      id: 'n1',
      title: 'Order shipped!',
      sub: 'Your Nike Air Max 270 is on the way',
      time: '2m ago',
      icon: Icons.local_shipping_outlined,
      kind: NotifKind.order,
    ),
    OxroNotif(
      id: 'n2',
      title: 'Delivered',
      sub: 'Casual Shirt Slim-Fit delivered — rate it',
      time: '1h ago',
      icon: Icons.check_circle_outline,
      kind: NotifKind.order,
    ),
    OxroNotif(
      id: 'n3',
      title: 'OXRO500 is live',
      sub: 'Flat ₹500 OFF above ₹2,999 at checkout',
      time: '3h ago',
      icon: Icons.local_offer_outlined,
      kind: NotifKind.offer,
    ),
    OxroNotif(
      id: 'n4',
      title: 'Electronics Fest',
      sub: 'From ₹999 + No-Cost EMI ends tonight',
      time: '5h ago',
      icon: Icons.smartphone_outlined,
      kind: NotifKind.offer,
    ),
    OxroNotif(
      id: 'n5',
      title: 'Price drop!',
      sub: 'Wireless Earbuds Pro down to ₹2,499',
      time: '1d ago',
      icon: Icons.trending_down_outlined,
      kind: NotifKind.offer,
    ),
    OxroNotif(
      id: 'n6',
      title: 'Out for delivery',
      sub: 'Smart Watch Fit 2 arrives today by 9 PM',
      time: '1d ago',
      icon: Icons.delivery_dining_outlined,
      kind: NotifKind.order,
    ),
  ];

  final List<OxroNotif> _items = [];
  bool _enabled = true;

  bool get enabled => _enabled;

  List<OxroNotif> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => n.unread).length;

  List<OxroNotif> byKind(NotifKind? kind) =>
      kind == null ? items : items.where((n) => n.kind == kind).toList();

  void setEnabled(bool v) {
    if (_enabled == v) return;
    _enabled = v;
    notifyListeners();
  }

  void markRead(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || !_items[i].unread) return;
    _items[i] = _items[i].copyWith(unread: false);
    notifyListeners();
  }

  void markAllRead() {
    if (unreadCount == 0) return;
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(unread: false);
    }
    notifyListeners();
  }

  /// Swipe-right toggle: unread <-> read.
  void toggleRead(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(unread: !_items[i].unread);
    notifyListeners();
  }

  OxroNotif? _lastRemoved;
  int _lastIndex = 0;

  /// Swipe-left delete (buffers for Undo).
  bool remove(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0) return false;
    _lastRemoved = _items[i];
    _lastIndex = i;
    _items.removeAt(i);
    notifyListeners();
    return true;
  }

  /// Restores the last swiped-away row. False when nothing to undo.
  bool restoreLast() {
    final r = _lastRemoved;
    if (r == null) return false;
    final i = _lastIndex.clamp(0, _items.length);
    _items.insert(i, r);
    _lastRemoved = null;
    notifyListeners();
    return true;
  }
}
