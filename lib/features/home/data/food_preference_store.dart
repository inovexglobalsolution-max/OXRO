import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two food choices shown in the preference sheet.
enum FoodPreference { veg, nonVeg }

/// App-wide food preference. When enabled, home, listings and menus show
/// only the selected diet. When disabled, everything is visible.
class FoodPreferenceStore extends ChangeNotifier {
  FoodPreferenceStore._();

  static final FoodPreferenceStore instance = FoodPreferenceStore._();

  static const _kEnabled = 'oxro_food_preference_enabled';
  static const _kPreference = 'oxro_food_preference';
  static const _kLegacyEnabled = 'oxro_veg_mode_enabled';
  static const _kLegacyScope = 'oxro_veg_mode_scope';

  @visibleForTesting
  static void resetForTests() {
    instance._enabled = false;
    instance._preference = FoodPreference.veg;
    instance.notifyListeners();
  }

  bool _enabled = false;
  FoodPreference _preference = FoodPreference.veg;

  bool get enabled => _enabled;
  FoodPreference get preference => _preference;

  bool get vegOnly => _enabled && _preference == FoodPreference.veg;
  bool get nonVegOnly => _enabled && _preference == FoodPreference.nonVeg;

  /// The active filter, or null when every kind of food is shown.
  FoodPreference? get activeFilter => _enabled ? _preference : null;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _enabled = p.getBool(_kEnabled) ?? p.getBool(_kLegacyEnabled) ?? false;
      final saved = p.getString(_kPreference);
      if (saved != null) {
        _preference = saved == 'nonveg'
            ? FoodPreference.nonVeg
            : FoodPreference.veg;
      } else {
        // Older builds only had an all/pure-veg scope. Any enabled veg mode
        // maps to the new veg preference.
        final legacyScope = p.getString(_kLegacyScope);
        _preference = legacyScope == 'pure'
            ? FoodPreference.veg
            : FoodPreference.veg;
      }
      notifyListeners();
    } catch (_) {
      // Best-effort preference only.
    }
  }

  Future<void> apply(FoodPreference preference) async {
    _enabled = true;
    _preference = preference;
    notifyListeners();
    await _persist();
  }

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    notifyListeners();
    await _persist();
  }

  Future<void> setPreference(FoodPreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kEnabled, _enabled);
      await p.setString(
        _kPreference,
        _preference == FoodPreference.nonVeg ? 'nonveg' : 'veg',
      );
    } catch (_) {
      // Best-effort preference only.
    }
  }
}
