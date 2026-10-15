import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';

/// Payment method for 15 Checkout.
enum PaymentMethod { upi, card, wallet, cod }

const paymentLabels = {
  PaymentMethod.upi: 'UPI',
  PaymentMethod.card: 'Card',
  PaymentMethod.wallet: 'Wallet',
  PaymentMethod.cod: 'COD',
};

const paymentSubs = {
  PaymentMethod.upi: 'GooglePay / PhonePe',
  PaymentMethod.card: 'Visa / Mastercard / RuPay',
  PaymentMethod.wallet: 'OXRO Balance',
  PaymentMethod.cod: 'Cash on Delivery',
};

/// Checkout state (mock, in-memory).
/// Totals mirror ref 15: items + ₹40 ship − coupon.
class PaymentStore extends ChangeNotifier {
  PaymentStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final PaymentStore instance = PaymentStore._();

  @visibleForTesting
  static void resetForTests() {
    instance._method = PaymentMethod.upi;
    instance._coupon = '';
    instance.notifyListeners();
  }

  PaymentMethod _method = PaymentMethod.upi;

  /// Applied coupon code only — discount/shipping are recomputed live
  /// from the current cart so shrinking the bag auto-invalidates
  /// stale savings (no money-loss window).
  /// The code itself is persisted; savings always re-derive.
  String _coupon = '';

  static const _kCoupon = 'oxro_coupon_v1';

  /// Loads persisted coupon code (call once at splash).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final code = p.getString(_kCoupon) ?? '';
      if (code.isEmpty) return;
      if (CouponStore.byCode(code) == null) return;
      _coupon = code;
      notifyListeners();
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<void> _persistCoupon() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_coupon.isEmpty) {
        await p.remove(_kCoupon);
      } else {
        await p.setString(_kCoupon, _coupon);
      }
    } catch (_) {
      // Best-effort cache only.
    }
  }

  static const shippingFee = 40;
  static const couponCode = 'OXRO500';
  static const couponOff = 500;

  PaymentMethod get method => _method;
  String get coupon => _coupon;

  Coupon? get _applied =>
      _coupon.isEmpty ? null : CouponStore.byCode(_coupon);

  /// Live discount for the current cart (0 when below minOrder).
  int get discount =>
      _applied?.discountFor(itemsTotal) ?? 0;

  /// Live free-shipping (valid only while cart meets minOrder).
  bool get freeShip {
    final k = _applied;
    if (k == null || !k.freeShip) return false;
    return itemsTotal >= k.minOrder;
  }

  /// Shipping after FREESHIP.
  int get effectiveShipping => freeShip ? 0 : shippingFee;

  void select(PaymentMethod m) {
    if (_method == m) return;
    _method = m;
    notifyListeners();
  }

  /// Returns true when code accepted for current cart total.
  /// Unknown codes and below-minimum carts are rejected.
  bool applyCoupon(String code) {
    final k = CouponStore.byCode(code);
    if (k == null) return false;
    final off = k.discountFor(itemsTotal);
    if (itemsTotal < k.minOrder || (off <= 0 && !k.freeShip)) {
      return false;
    }
    _coupon = k.code;
    notifyListeners();
    _persistCoupon();
    return true;
  }

  void clearCoupon() {
    if (_coupon.isEmpty) return;
    _coupon = '';
    notifyListeners();
    _persistCoupon();
  }

  int get itemsTotal => CartStore.instance.totalPrice;

  int get itemsCount => CartStore.instance.count;

  int get toPay =>
      (itemsTotal + effectiveShipping - discount).clamp(0, 1 << 31);
}
