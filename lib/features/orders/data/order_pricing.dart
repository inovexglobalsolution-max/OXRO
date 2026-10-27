/// Immutable customer bill snapshot stored on an order.
///
/// Prices come from the [PricingEngine] at checkout time and are frozen
/// here, so later admin changes never rewrite a past invoice.
class OrderBill {
  const OrderBill({
    required this.itemSubtotalPaise,
    required this.packagingPaise,
    required this.deliveryPaise,
    required this.platformFeePaise,
    this.smallCartFeePaise = 0,
    required this.taxPaise,
    required this.tipPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
    required this.configVersion,
  });

  final int itemSubtotalPaise;
  final int packagingPaise;
  final int deliveryPaise;
  final int platformFeePaise;
  final int smallCartFeePaise;
  final int taxPaise;
  final int tipPaise;
  final int discountPaise;
  final int grandTotalPaise;
  final int configVersion;

  Map<String, dynamic> toJson() => {
        'itemSubtotalPaise': itemSubtotalPaise,
        'packagingPaise': packagingPaise,
        'deliveryPaise': deliveryPaise,
        'platformFeePaise': platformFeePaise,
        'smallCartFeePaise': smallCartFeePaise,
        'taxPaise': taxPaise,
        'tipPaise': tipPaise,
        'discountPaise': discountPaise,
        'grandTotalPaise': grandTotalPaise,
        'configVersion': configVersion,
      };

  static OrderBill fromJson(Map<String, dynamic> m) => OrderBill(
        itemSubtotalPaise:
            (m['itemSubtotalPaise'] as num?)?.toInt() ?? 0,
        packagingPaise:
            (m['packagingPaise'] as num?)?.toInt() ?? 0,
        deliveryPaise:
            (m['deliveryPaise'] as num?)?.toInt() ?? 0,
        platformFeePaise:
            (m['platformFeePaise'] as num?)?.toInt() ?? 0,
        smallCartFeePaise:
            (m['smallCartFeePaise'] as num?)?.toInt() ?? 0,
        taxPaise: (m['taxPaise'] as num?)?.toInt() ?? 0,
        tipPaise: (m['tipPaise'] as num?)?.toInt() ?? 0,
        discountPaise:
            (m['discountPaise'] as num?)?.toInt() ?? 0,
        grandTotalPaise:
            (m['grandTotalPaise'] as num?)?.toInt() ?? 0,
        configVersion:
            (m['configVersion'] as num?)?.toInt() ?? 1,
      );
}
