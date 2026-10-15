import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logged-in profile persisted on device (Supabase auth replaces later).
class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  /// Global instance (tests drive via [resetForTests] + [load]).
  static final ProfileStore instance = ProfileStore._();

  static const _kName = 'oxro_name';
  static const _kEmail = 'oxro_email';
  static const _kPhone = 'oxro_phone';
  static const _kSeenOnboarding = 'oxro_seen_onboarding';

  @visibleForTesting
  static void resetForTests() {
    instance._name = null;
    instance._email = null;
    instance._phone = null;
    instance._seenOnboarding = false;
    instance._loaded = false;
    instance.notifyListeners();
  }

  String? _name;
  String? _email;
  String? _phone;
  bool _seenOnboarding = false;
  bool _loaded = false;

  String? get name => _name;
  String? get email => _email;
  String? get phone => _phone;
  bool get seenOnboarding => _seenOnboarding;
  bool get loaded => _loaded;

  /// Logged in via email OTP or phone OTP (either identity counts).
  bool get isLoggedIn =>
      (_email != null && _email!.isNotEmpty) ||
      (_phone != null && _phone!.isNotEmpty);

  /// Indian 10-digit mobile ([6-9] start). Empty = not set (allowed).
  static String? validatePhone(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(t)) {
      return 'Enter valid 10-digit mobile';
    }
    return null;
  }

  static String? validateName(String v) {
    final t = v.trim();
    if (!RegExp(r'^[A-Za-z][A-Za-z ]{2,}$').hasMatch(t)) {
      return 'Enter a valid name (min 3 letters)';
    }
    return null;
  }

  String get displayName {
    final n = _name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = _email?.trim() ?? '';
    final at = e.indexOf('@');
    if (at > 0) return e.substring(0, at);
    return 'Guest User';
  }

  /// Loads persisted profile (call once at splash).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _name = p.getString(_kName);
    _email = p.getString(_kEmail);
    _phone = p.getString(_kPhone);
    _seenOnboarding = p.getBool(_kSeenOnboarding) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Saves login (called after OTP verify).
  /// Email and phone are independent identities — pass whichever
  /// the OTP was sent to (never store a phone number in the email
  /// field). Empty values clear that identity.
  Future<void> save(
      {String? email, String? name, String? phone}) async {
    final p = await SharedPreferences.getInstance();
    if (email != null) {
      final e = email.trim();
      _email = e.isEmpty ? null : e;
    }
    if (name != null) _name = name.trim();
    if (phone != null) {
      final t = phone.trim();
      _phone = t.isEmpty ? null : t;
    }
    if (_email == null) {
      await p.remove(_kEmail);
    } else {
      await p.setString(_kEmail, _email!);
    }
    if (_name != null) await p.setString(_kName, _name!);
    if (_phone == null) {
      await p.remove(_kPhone);
    } else {
      await p.setString(_kPhone, _phone!);
    }
    notifyListeners();
  }

  /// Updates display name (edit profile).
  Future<bool> updateName(String name) async {
    if (validateName(name) != null) return false;
    final p = await SharedPreferences.getInstance();
    _name = name.trim();
    await p.setString(_kName, _name!);
    notifyListeners();
    return true;
  }

  /// Updates phone (edit profile). Empty clears it.
  Future<bool> updatePhone(String phone) async {
    if (validatePhone(phone) != null) return false;
    final p = await SharedPreferences.getInstance();
    final t = phone.trim();
    _phone = t.isEmpty ? null : t;
    if (_phone == null) {
      await p.remove(_kPhone);
    } else {
      await p.setString(_kPhone, _phone!);
    }
    notifyListeners();
    return true;
  }

  /// Updates name + phone together (edit screen save).
  /// Returns error string or null on success.
  Future<String?> updateProfile(
      {required String name, required String phone}) async {
    final nameErr = validateName(name);
    if (nameErr != null) return nameErr;
    final phoneErr = validatePhone(phone);
    if (phoneErr != null) return phoneErr;
    final p = await SharedPreferences.getInstance();
    _name = name.trim();
    final t = phone.trim();
    _phone = t.isEmpty ? null : t;
    await p.setString(_kName, _name!);
    if (_phone == null) {
      await p.remove(_kPhone);
    } else {
      await p.setString(_kPhone, _phone!);
    }
    notifyListeners();
    return null;
  }

  Future<void> markOnboardingSeen() async {
    final p = await SharedPreferences.getInstance();
    _seenOnboarding = true;
    await p.setBool(_kSeenOnboarding, true);
    notifyListeners();
  }

  /// Logs out (keeps onboarding flag so flow is not repeated).
  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    _name = null;
    _email = null;
    _phone = null;
    await p.remove(_kName);
    await p.remove(_kEmail);
    await p.remove(_kPhone);
    notifyListeners();
  }
}
