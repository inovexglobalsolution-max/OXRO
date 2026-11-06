import 'dart:io';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';

/// Stable customer identity shared by every API call.
///
/// Login stays on-device, so the backend keys data by this client id
/// (`cust-<phone|email>`, else a stable device-scoped `cust-guest-*`). It
/// is not an authentication token — bearer auth/OTP wiring is a later phase.
class CustomerIdentity {
  static const _kGuestId = 'oxro_guest_customer_id';
  static String? _storedGuestId;
  static String? _volatileGuestId;

  static String _newGuestId() =>
      'cust-guest-${DateTime.now().microsecondsSinceEpoch}'
      '${math.Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0')}';

  /// Loads the stable device-scoped identity used before a phone/email
  /// login. Call this once before any network-backed store boots.
  static Future<void> ensureIdentityLoaded() async {
    if (!networkEnabled) return;
    try {
      final p = await SharedPreferences.getInstance();
      var id = p.getString(_kGuestId);
      if (id == null || id.isEmpty) {
        id = _newGuestId();
        await p.setString(_kGuestId, id);
      }
      _storedGuestId = id;
    } catch (_) {
      // Fall back to a volatile device-scoped id below.
    }
  }

  static String get customerId {
    final phone = ProfileStore.instance.phone?.trim() ?? '';
    if (phone.isNotEmpty) return 'cust-$phone';
    final email = ProfileStore.instance.email?.trim() ?? '';
    if (email.isNotEmpty) return 'cust-$email';
    return _storedGuestId ??= _volatileGuestId ??= _newGuestId();
  }

  /// Network calls stay off under `flutter test` (fake-async + no server).
  static bool get networkEnabled =>
      Platform.environment['FLUTTER_TEST'] != 'true';
}
