import 'package:flutter/foundation.dart';
import 'package:oxro_pricing/oxro_pricing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';

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
///
/// The bill is computed by [PricingEngine] from [PricingConfigStore] so the
/// platform fee, taxes, delivery and tip all come from one versioned source.
/// Totals: items + delivery + platform fee + GST + tip − coupon.
class PaymentStore extends ChangeNotifier {
  PaymentStore._();

  /// Global instance (tests call [resetForTests] in setUp).
  static final PaymentStore instance = PaymentStore._();

  @visibleForTesting
  static void resetForTests() {
    instance._method = PaymentMethod.upi;
    instance._coupon = '';
    instance._tipPaise = 0;
    PricingConfigStore.instance.resetToInitial();
    instance.notifyListeners();
  }

  PaymentMethod _method = PaymentMethod.upi;

  /// Applied coupon code only — discount/shipping are recomputed live
  /// from the current cart so shrinking the bag auto-invalidates
  /// stale savings (no money-loss window).
  /// The code itself is persisted; savings always re-derive.
  String _coupon = '';

  /// Customer tip in paise (100% passed to the delivery partner).
  int _tipPaise = 0;

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

  /// Delivery fee charged to the customer (rupees).
  static int get shippingFee =>
      PricingConfigStore.instance.config.customerDeliveryFeePaise ~/ 100;

  PaymentMethod get method => _method;
  String get coupon => _coupon;
  int get tipPaise => _tipPaise;

  Coupon? get _applied => _coupon.isEmpty ? null : CouponStore.byCode(_coupon);

  /// Live discount for the current cart (0 when below minOrder).
  int get discount => _applied?.discountFor(itemsTotal) ?? 0;

  /// Live free-shipping (valid only while cart meets minOrder).
  bool get freeShip {
    final k = _applied;
    if (k == null || !k.freeShip) return false;
    return itemsTotal >= k.minOrder;
  }

  /// PREMIUM members get free delivery above the membership threshold.
  bool get premiumFreeDelivery =>
      PremiumStore.instance.isMember &&
      itemsTotal >= PremiumStore.freeDeliveryMinOrder;

  /// Delivery fee after FREESHIP or the PREMIUM benefit (rupees).
  int get deliveryFee => freeShip || premiumFreeDelivery ? 0 : shippingFee;

  /// Customer platform fee in rupees (₹0 during a promo).
  int get platformFee =>
      PricingConfigStore.instance.effectivePlatformFeePaise ~/ 100;

  /// Tip in rupees.
  int get tip => _tipPaise ~/ 100;

  void setTipPaise(int paise) {
    final v = paise < 0 ? 0 : paise;
    if (v == _tipPaise) return;
    _tipPaise = v;
    notifyListeners();
  }

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

  /// Builds the bill for an explicit cart subtotal. Callers that already
  /// hold the live [CartStore] total pass it here so the quote can never be
  /// rebuilt from an empty/stale cart.
  OrderQuote quoteForItemsTotal(int itemsTotalRupees) {
    final total = itemsTotalRupees < 0 ? 0 : itemsTotalRupees;
    final cfg = PricingConfigStore.instance.config;
    final discountPaise = discount * 100;
    final sub = SubOrderInput(
      restaurantId: 'oxro',
      foodSubtotalPaise: total * 100,
      packagingPaise: cfg.customerPackagingFeePaise,
      deliveryFeePaise: deliveryFee * 100,
      oxroDiscountPaise: discountPaise,
      tipPaise: _tipPaise,
    );
    final platformFee =
        PricingConfigStore.instance.effectivePlatformFeePaise;
    final quote = PricingEngine(cfg).quoteOrder(
      OrderQuoteInput(
        subOrders: [sub],
        platformFeeOverridePaise: platformFee,
      ),
    );
    if (total == 0 || quote.grandTotalPaise > 0 || discountPaise > 0) {
      return quote;
    }
    final itemSubtotal = total * 100;
    final smallCartFee =
        PricingEngine.smallCartFeePaiseFor(itemSubtotal);
    final tax = Money.applyBps(itemSubtotal, cfg.customerGstBps);
    return OrderQuote(
      itemSubtotalPaise: itemSubtotal,
      packagingPaise: cfg.customerPackagingFeePaise,
      deliveryFeePaise: deliveryFee * 100,
      platformFeePaise: platformFee,
      smallCartFeePaise: smallCartFee,
      taxPaise: tax,
      tipPaise: _tipPaise,
      discountPaise: 0,
      grandTotalPaise:
          itemSubtotal +
          cfg.customerPackagingFeePaise +
          deliveryFee * 100 +
          platformFee +
          smallCartFee +
          tax +
          _tipPaise,
      subOrders: quote.subOrders,
      configVersion: cfg.version,
    );
  }

  /// The engine bill for the current cart. Single restaurant today; the
  /// food-conversion phase groups this per restaurant for split orders.
  OrderQuote get quote => quoteForItemsTotal(itemsTotal);

  int get toPay => quote.grandTotalPaise ~/ 100;

  /// Exact grand total in paise (for invoices/tests).
  int get toPayPaise => quote.grandTotalPaise;
}
