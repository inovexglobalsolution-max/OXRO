import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/address_repo.dart';

/// Why checkout cannot use the current address yet.
enum AddressIssue { none, missing, doorMissing, incomplete }

/// Delivery address model (multi-address: Home/Office/Other).
/// Includes coordinates captured from the customer's GPS pin —
/// never hardcoded, always from the location picker.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line,
    required this.city,
    required this.pin,
    this.state,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String name;
  final String phone;
  final String line;
  final String city;
  final String pin;
  final String? state;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  /// Snapshot stored on the order at placement time.
  Map<String, dynamic> toOrderSnapshot() => {
    'id': id,
    'label': label,
    'name': name,
    'phone': phone,
    'line': line,
    'city': city,
    if (state != null) 'state': state,
    if (landmark != null) 'landmark': landmark,
    'pin': pin,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  Address copyWith({
    String? id,
    String? label,
    String? name,
    String? phone,
    String? line,
    String? city,
    String? pin,
    String? state,
    String? landmark,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      line: line ?? this.line,
      city: city ?? this.city,
      pin: pin ?? this.pin,
      state: state ?? this.state,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
  bool _serverEmpty = false;

  static String _normalizeForSignature(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _signature(Address a) => [
    _normalizeForSignature(a.label),
    _normalizeForSignature(a.name),
    a.phone.replaceAll(RegExp(r'\D'), ''),
    _normalizeForSignature(a.line),
    _normalizeForSignature(a.city),
    a.pin.trim(),
    // Coordinates disambiguate same-text addresses on a different door/pin.
    a.latitude?.toStringAsFixed(4) ?? '',
    a.longitude?.toStringAsFixed(4) ?? '',
  ].join('|');

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static Address _fromMap(Map<String, dynamic> a) {
    return Address(
      id: (a['id'] as String?) ?? '',
      label: (a['label'] as String?) ?? 'Home',
      name: (a['name'] as String?) ?? '',
      phone: (a['phone'] as String?) ?? '',
      line: (a['line'] as String?) ?? '',
      city: (a['city'] as String?) ?? '',
      pin: (a['pin'] as String?) ?? '',
      state: (a['state'] as String?)?.trim().isEmpty == true
          ? null
          : (a['state'] as String?)?.trim(),
      landmark: (a['landmark'] as String?)?.trim().isEmpty == true
          ? null
          : (a['landmark'] as String?)?.trim(),
      latitude: _toDouble(a['latitude']),
      longitude: _toDouble(a['longitude']),
    );
  }

  /// Loads addresses (call once at splash). The server wins when reachable;
  /// SharedPreferences is the offline fallback.
  Future<void> load() async {
    _serverEmpty = false;
    if (CustomerIdentity.networkEnabled) {
      try {
        final data = await AddressRepo().fetchAddresses();
        if (data != null) {
          final items = data['addresses'];
          if (items is List && items.isNotEmpty) {
            _items.clear();
            for (final e in items) {
              if (e is! Map<String, dynamic>) continue;
              final a = _fromMap(e);
              if (a.id.isEmpty) continue;
              _items[a.id] = a;
            }
            final def = data['defaultId'] as String?;
            _defaultId = def != null && _items.containsKey(def)
                ? def
                : (_items.isEmpty ? null : _items.keys.first);
            await _persist();
            notifyListeners();
            return;
          }
          // Empty server — seed it from the local cache after it loads.
          _serverEmpty = true;
        }
      } catch (_) {
        // Offline — use the local cache.
      }
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final items = (m['items'] as List?) ?? const [];
        for (final e in items) {
          if (e is! Map<String, dynamic>) continue;
          final a = _fromMap(e);
          if (a.id.isEmpty) continue;
          _items[a.id] = a;
        }
        final def = m['defaultId'] as String?;
        if (def != null && _items.containsKey(def)) {
          _defaultId = def;
        } else if (_items.isNotEmpty) {
          _defaultId = _items.keys.first;
        }
        notifyListeners();
      }
    } catch (_) {
      // Best-effort cache only.
    }
    await _maybeSeedServer();
  }

  /// Pushes locally cached addresses to an empty server so data saved
  /// offline lands in the DB instead of being wiped on the next load.
  Future<void> _maybeSeedServer() async {
    if (!_serverEmpty || !CustomerIdentity.networkEnabled || _items.isEmpty) {
      _serverEmpty = false;
      return;
    }
    try {
      for (final a in _items.values) {
        await AddressRepo().createAddress(_toMap(a));
      }
      final def = _defaultId;
      if (def != null) {
        await AddressRepo().selectAddress(def);
      }
    } catch (_) {
      // Local cache remains authoritative; next sync can retry.
    } finally {
      _serverEmpty = false;
    }
  }

  static void _sync(Future<void> Function() action) {
    if (!CustomerIdentity.networkEnabled) return;
    unawaited(action().catchError((_) {}));
  }

  Map<String, dynamic> _toMap(Address a) => {
    'id': a.id,
    'label': a.label,
    'name': a.name,
    'phone': a.phone,
    'line': a.line,
    'city': a.city,
    'pin': a.pin,
    if (a.state != null) 'state': a.state,
    if (a.landmark != null) 'landmark': a.landmark,
    if (a.latitude != null) 'latitude': a.latitude,
    if (a.longitude != null) 'longitude': a.longitude,
  };

  void _pushCreate(Address a) {
    _sync(() async {
      await AddressRepo().createAddress(_toMap(a));
    });
  }

  void _pushUpdate(Address a) {
    _sync(() async {
      await AddressRepo().updateAddress(a.id, _toMap(a));
    });
  }

  void _pushSelect(String id) {
    _sync(() async {
      await AddressRepo().selectAddress(id);
    });
  }

  void _pushDelete(String id) {
    _sync(() async {
      await AddressRepo().deleteAddress(id);
    });
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
                'state': a.state,
                'landmark': a.landmark,
                'latitude': a.latitude,
                'longitude': a.longitude,
              },
          ],
        }),
      );
    } catch (_) {
      // Best-effort cache only.
    }
  }

  void _changed() {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('address store notify failed: $e');
    }
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

  Address? get _firstOrNull => _items.isEmpty ? null : _items.values.first;

  /// Effective address drives validity AND display together —
  /// previously hasValid checked only [_default] while displayLine
  /// fell back to the first entry, blocking checkout on a screen
  /// that showed a valid address.
  bool get hasValid {
    final a = address;
    return a != null && isValidAddress(a);
  }

  /// Address is present but the flat / door line (or another field)
  /// is missing. Drives the checkout popup copy.
  AddressIssue get issue {
    final a = address;
    if (a == null) return AddressIssue.missing;
    if (isValidAddress(a)) return AddressIssue.none;
    if (validateLine(a.line) != null && validateCity(a.city) == null) {
      return AddressIssue.doorMissing;
    }
    return AddressIssue.incomplete;
  }

  bool get hasAny => _items.isNotEmpty;

  List<Address> get items => List.unmodifiable(_items.values);

  String? get defaultId => _defaultId;

  /// One-line display for checkout rows.
  String get displayLine {
    final a = _default ?? _firstOrNull;
    if (a == null) return '';
    final tail = [
      if (a.state != null && a.state!.trim().isNotEmpty) ', ${a.state!.trim()}',
      ' — ${a.pin}',
    ].join();
    return '${a.name} • ${a.phone}\n${a.line}, ${a.city}$tail';
  }

  /// Adds a new address (id auto) and selects it when first/valid.
  /// Exact duplicates are reused instead of being inserted again.
  String add(Address a) {
    final signature = _signature(a);
    for (final existing in _items.values) {
      if (_signature(existing) == signature) {
        if (isValidAddress(existing) && _defaultId != existing.id) {
          _defaultId = existing.id;
          _changed();
          _pushSelect(existing.id);
        }
        return existing.id;
      }
    }

    var id = a.id.trim();
    if (id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toString();
    }
    if (_items.containsKey(id)) {
      final requested = id;
      var suffix = 1;
      while (_items.containsKey(id)) {
        id = '${requested}_$suffix';
        suffix += 1;
      }
    }
    _items[id] = a.copyWith(id: id);
    _defaultId ??= id;
    if (isValidAddress(_items[id]!)) _defaultId = id;
    _changed();
    _pushCreate(_items[id]!);
    return id;
  }

  /// Back-compat single save (first slot).
  void save(Address a) {
    if (_items.isEmpty) {
      add(a);
      return;
    }
    update(_defaultId ?? _items.keys.first, a);
  }

  void update(String id, Address a) {
    final current = _items[id];
    if (current == null) {
      add(a.copyWith(id: id));
      return;
    }

    final signature = _signature(a);
    Address? duplicate;
    for (final existing in _items.values) {
      if (existing.id != id && _signature(existing) == signature) {
        duplicate = existing;
        break;
      }
    }
    if (duplicate != null) {
      final merged = duplicate;
      final duplicateId = merged.id;
      _items.remove(id);
      if (_defaultId == id ||
          _defaultId == null ||
          !_items.containsKey(_defaultId)) {
        _defaultId = duplicateId;
      }
      _changed();
      _pushDelete(id);
      _pushSelect(duplicateId);
      return;
    }

    _items[id] = a.copyWith(id: id);
    _changed();
    _pushUpdate(_items[id]!);
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
    _pushSelect(id);
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
    _pushDelete(id);
  }

  void clear() {
    if (_items.isEmpty && _defaultId == null) return;
    _items.clear();
    _defaultId = null;
    _changed();
  }
}
