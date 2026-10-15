import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Delivery address model (14 multi-address: Home/Office/Other).
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line,
    required this.city,
    required this.pin,
  });

  final String id;
  final String label;
  final String name;
  final String phone;
  final String line;
  final String city;
  final String pin;

  Address copyWith({
    String? id,
    String? label,
    String? name,
    String? phone,
    String? line,
    String? city,
    String? pin,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      line: line ?? this.line,
      city: city ?? this.city,
      pin: pin ?? this.pin,
    );
  }
}

/// App-wide addresses (mock, in-memory).
/// Bag checkout guards on [hasValid]: empty/invalid → 14 screen,
/// valid default → auto-move to payment (15).
class AddressStore extends ChangeNotifier {
  AddressStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final AddressStore instance = AddressStore._();

  static const labels = ['Home', 'Office', 'Other'];
  static const _kCache = 'oxro_addresses_v1';

  @visibleForTesting
  static void resetForTests() {
    instance._items.clear();
    instance._defaultId = null;
    instance.notifyListeners();
  }

  final Map<String, Address> _items = {};
  String? _defaultId;

  /// Loads persisted addresses (call once at splash).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final items = (m['items'] as List?) ?? const [];
      for (final e in items) {
        final a = e as Map<String, dynamic>;
        final id = (a['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        _items[id] = Address(
          id: id,
          label: (a['label'] as String?) ?? 'Home',
          name: (a['name'] as String?) ?? '',
          phone: (a['phone'] as String?) ?? '',
          line: (a['line'] as String?) ?? '',
          city: (a['city'] as String?) ?? '',
          pin: (a['pin'] as String?) ?? '',
        );
      }
      final def = m['defaultId'] as String?;
      if (def != null && _items.containsKey(def)) {
        _defaultId = def;
      } else if (_items.isNotEmpty) {
        _defaultId = _items.keys.first;
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
          jsonEncode({
            'defaultId': _defaultId,
            'items': [
              for (final a in _items.values)
                {
                  'id': a.id,
                  'label': a.label,
                  'name': a.name,
                  'phone': a.phone,
                  'line': a.line,
                  'city': a.city,
                  'pin': a.pin,
                },
            ],
          }));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  static final _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final _pinRegex = RegExp(r'^\d{6}$');

  static String? validateName(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter full name';
    if (!RegExp(r'^[A-Za-z][A-Za-z ]{2,}$').hasMatch(t)) {
      return 'Enter a valid name (min 3 letters)';
    }
    return null;
  }

  static String? validatePhone(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter mobile number';
    if (!_phoneRegex.hasMatch(t)) {
      return 'Enter valid 10-digit mobile';
    }
    return null;
  }

  static String? validateLine(String v) {
    if (v.trim().isEmpty) return 'Enter address';
    if (v.trim().length < 6) return 'Enter complete address';
    return null;
  }

  static String? validateCity(String v) {
    if (v.trim().isEmpty) return 'Enter city';
    return null;
  }

  static String? validatePin(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter pincode';
    if (!_pinRegex.hasMatch(t)) return 'Enter valid 6-digit pincode';
    return null;
  }

  static bool isValidAddress(Address a) {
    return validateName(a.name) == null &&
        validatePhone(a.phone) == null &&
        validateLine(a.line) == null &&
        validateCity(a.city) == null &&
        validatePin(a.pin) == null;
  }

  Address? get address => _default ?? _firstOrNull;

  Address? get _default {
    final id = _defaultId;
    if (id == null) return null;
    return _items[id];
  }

  Address? get _firstOrNull =>
      _items.isEmpty ? null : _items.values.first;

  /// Effective address drives validity AND display together —
  /// previously hasValid checked only [_default] while displayLine
  /// fell back to the first entry, blocking checkout on a screen
  /// that showed a valid address.
  bool get hasValid {
    final a = address;
    return a != null && isValidAddress(a);
  }

  bool get hasAny => _items.isNotEmpty;

  List<Address> get items =>
      List.unmodifiable(_items.values);

  String? get defaultId => _defaultId;

  /// One-line display for checkout rows.
  String get displayLine {
    final a = _default ?? _firstOrNull;
    if (a == null) return '';
    return '${a.name} • ${a.phone}\n${a.line}, ${a.city} — ${a.pin}';
  }

  /// Adds a new address (id auto) and selects it when first/valid.
  String add(Address a) {
    final id = a.id.isEmpty
        ? DateTime.now()
            .millisecondsSinceEpoch
            .toString()
        : a.id;
    _items[id] = a.copyWith(id: id);
    _defaultId ??= id;
    if (isValidAddress(_items[id]!)) _defaultId = id;
    _changed();
    return id;
  }

  /// Back-compat single save (first slot).
  void save(Address a) {
    if (_items.isEmpty) {
      add(a);
      return;
    }
    final id = _defaultId ?? _items.keys.first;
    _items[id] = a.copyWith(id: id);
    _defaultId = id;
    _changed();
  }

  void update(String id, Address a) {
    if (!_items.containsKey(id)) return;
    _items[id] = a.copyWith(id: id);
    _changed();
  }

  /// Switches the default only to a valid address — selecting an
  /// invalid entry no longer poisons checkout while the UI shows
  /// another address. Returns false when rejected.
  bool select(String id) {
    final a = _items[id];
    if (a == null) return false;
    if (_defaultId == id) return true;
    if (!isValidAddress(a)) return false;
    _defaultId = id;
    _changed();
    return true;
  }

  void remove(String id) {
    if (_items.remove(id) == null) return;
    if (_defaultId == id) {
      String? firstValid;
      for (final e in _items.values) {
        if (isValidAddress(e)) {
          firstValid = e.id;
          break;
        }
      }
      _defaultId = firstValid ?? (_items.isEmpty ? null : _items.keys.first);
    }
    _changed();
  }

  void clear() {
    if (_items.isEmpty && _defaultId == null) return;
    _items.clear();
    _defaultId = null;
    _changed();
  }
}
