import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock (4-digit PIN) persisted on device.
/// Demo-grade obfuscation only (NOT real security):
/// Supabase Auth + biometrics replace this later.
class ApplockStore extends ChangeNotifier {
  ApplockStore._();

  /// Global instance (tests drive via [resetForTests]).
  static final ApplockStore instance = ApplockStore._();

  static const _kEnabled = 'oxro_lock_enabled';
  static const _kHash = 'oxro_lock_hash';

  @visibleForTesting
  static void resetForTests() {
    instance._enabled = false;
    instance._hash = null;
    instance._fails = 0;
    instance._lockedUntil = null;
    instance.notifyListeners();
  }

  /// Tests only: clears the brute-force lockout (DateTime-based,
  /// so fake-async pumps can't advance it) without wiping the PIN.
  @visibleForTesting
  static void clearLockoutForTests() {
    instance._fails = 0;
    instance._lockedUntil = null;
    instance.notifyListeners();
  }

  bool _enabled = false;
  String? _hash;

  /// Brute-force guard (memory-only): wrong PINs back off
  /// 5s → 10s → 20s → 30s cap. Correct PIN resets the counter.
  int _fails = 0;
  DateTime? _lockedUntil;

  bool get enabled => _enabled && _hash != null;

  /// Seconds remaining on the current lockout (0 = free to try).
  int get lockLeft {
    final until = _lockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _lockedUntil = null;
      return 0;
    }
    return left;
  }

  bool get locked => lockLeft > 0;

  /// FNV-1a demo hash with app salt (obfuscation, not security).
  static String hashPin(String pin) {
    final salted = 'oxro::$pin::lock';
    var h = 0x811c9dc5;
    for (final c in salted.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  static bool validFormat(String pin) =>
      RegExp(r'^\d{4}$').hasMatch(pin);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _enabled = p.getBool(_kEnabled) ?? false;
    _hash = p.getString(_kHash);
    notifyListeners();
  }

  /// Enables lock with [pin] (must match [confirm], both 4 digits).
  Future<bool> enable(String pin, String confirm) async {
    if (!validFormat(pin) || pin != confirm) return false;
    final p = await SharedPreferences.getInstance();
    _hash = hashPin(pin);
    _enabled = true;
    await p.setString(_kHash, _hash!);
    await p.setBool(_kEnabled, true);
    notifyListeners();
    return true;
  }

  Future<bool> verify(String pin) async {
    final h = _hash;
    if (h == null) return false;
    if (locked) return false;
    if (hashPin(pin) == h) {
      _fails = 0;
      _lockedUntil = null;
      return true;
    }
    _fails++;
    final backoff = [5, 10, 20, 30][(_fails - 1).clamp(0, 3)];
    _lockedUntil =
        DateTime.now().add(Duration(seconds: backoff));
    notifyListeners();
    return false;
  }

  Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    _enabled = false;
    _hash = null;
    await p.remove(_kHash);
    await p.setBool(_kEnabled, false);
    notifyListeners();
  }
}
