/// A configurable peak-hour window that pays an extra flat bonus when a
/// delivery is *accepted* inside the window. Windows may wrap midnight.
class PeakWindow {
  const PeakWindow({
    required this.id,
    required this.label,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.bonusPaise,
  });

  final String id;
  final String label;

  /// Minutes since local midnight, 0..1440.
  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final int bonusPaise;

  bool covers(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (startMinuteOfDay <= endMinuteOfDay) {
      return m >= startMinuteOfDay && m < endMinuteOfDay;
    }
    // Wraps midnight, e.g. 22:00 -> 02:00.
    return m >= startMinuteOfDay || m < endMinuteOfDay;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startMinuteOfDay': startMinuteOfDay,
        'endMinuteOfDay': endMinuteOfDay,
        'bonusPaise': bonusPaise,
      };

  static PeakWindow fromJson(Map<String, dynamic> m) => PeakWindow(
        id: (m['id'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        startMinuteOfDay:
            (m['startMinuteOfDay'] as num?)?.toInt() ?? 0,
        endMinuteOfDay:
            (m['endMinuteOfDay'] as num?)?.toInt() ?? 0,
        bonusPaise: (m['bonusPaise'] as num?)?.toInt() ?? 0,
      );
}

/// An admin-defined special bonus, e.g. "long trip" or "stacked orders".
class SpecialIncentive {
  const SpecialIncentive({
    required this.id,
    required this.label,
    required this.bonusPaise,
    this.minDistanceMetres = 0,
    this.maxDistanceMetres,
    this.minOrderCount = 1,
  });

  final String id;
  final String label;
  final int bonusPaise;
  final int minDistanceMetres;
  final int? maxDistanceMetres;
  final int minOrderCount;

  bool matches({required int roadMetres, required int orderCount}) {
    if (orderCount < minOrderCount) return false;
    if (roadMetres < minDistanceMetres) return false;
    final max = maxDistanceMetres;
    if (max != null && roadMetres > max) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'bonusPaise': bonusPaise,
        'minDistanceMetres': minDistanceMetres,
        if (maxDistanceMetres != null)
          'maxDistanceMetres': maxDistanceMetres,
        'minOrderCount': minOrderCount,
      };

  static SpecialIncentive fromJson(Map<String, dynamic> m) =>
      SpecialIncentive(
        id: (m['id'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        bonusPaise: (m['bonusPaise'] as num?)?.toInt() ?? 0,
        minDistanceMetres:
            (m['minDistanceMetres'] as num?)?.toInt() ?? 0,
        maxDistanceMetres:
            (m['maxDistanceMetres'] as num?)?.toInt(),
        minOrderCount:
            (m['minOrderCount'] as num?)?.toInt() ?? 1,
      );
}

/// Versioned pricing configuration. Admin edits create a new [version];
/// orders snapshot the config they were priced with, so edits never
/// rewrite history.
class PricingConfig {
  const PricingConfig({
    required this.version,
    required this.effectiveFromIso,
    this.commissionBps = 500,
    this.platformFeePaise = 200,
    this.customerDeliveryFeePaise = 4000,
    this.customerPackagingFeePaise = 0,
    this.customerGstBps = 500,
    this.commissionGstBps = 1800,
    this.tdsBps = 100,
    this.basePayoutPaise = 2500,
    this.includedDistanceMetres = 3000,
    this.perKmPaise = 700,
    this.stackingBonusPaise = 0,
    this.freeWaitingMinutes = 5,
    this.waitingCompPerMinutePaise = 0,
    this.peakWindows = const <PeakWindow>[],
    this.specialIncentives = const <SpecialIncentive>[],
  });

  /// Initial OXRO configuration confirmed by the business.
  static const PricingConfig initial = PricingConfig(
    version: 1,
    effectiveFromIso: '2026-01-01T00:00:00Z',
  );

  final int version;
  final String effectiveFromIso;

  /// Seller commission on the post-restaurant-discount food subtotal.
  final int commissionBps;

  /// Customer platform fee, per order (not per restaurant).
  final int platformFeePaise;

  /// Customer delivery fee, charged per restaurant.
  final int customerDeliveryFeePaise;

  /// Customer packaging fee, charged per restaurant.
  final int customerPackagingFeePaise;

  /// GST charged to the customer on the food subtotal.
  final int customerGstBps;

  /// GST the platform charges the seller on the commission.
  final int commissionGstBps;

  /// TDS withheld from seller settlement (1% under 194-O).
  final int tdsBps;

  /// Rider base payout covering [includedDistanceMetres].
  final int basePayoutPaise;
  final int includedDistanceMetres;

  /// Per-km payout beyond the included distance.
  final int perKmPaise;

  /// Flat bonus per extra order in a stacked trip.
  final int stackingBonusPaise;

  final int freeWaitingMinutes;
  final int waitingCompPerMinutePaise;

  final List<PeakWindow> peakWindows;
  final List<SpecialIncentive> specialIncentives;

  PricingConfig copyWith({
    int? version,
    String? effectiveFromIso,
    int? commissionBps,
    int? platformFeePaise,
    int? customerDeliveryFeePaise,
    int? customerPackagingFeePaise,
    int? customerGstBps,
    int? commissionGstBps,
    int? tdsBps,
    int? basePayoutPaise,
    int? includedDistanceMetres,
    int? perKmPaise,
    int? stackingBonusPaise,
    int? freeWaitingMinutes,
    int? waitingCompPerMinutePaise,
    List<PeakWindow>? peakWindows,
    List<SpecialIncentive>? specialIncentives,
  }) {
    return PricingConfig(
      version: version ?? this.version,
      effectiveFromIso: effectiveFromIso ?? this.effectiveFromIso,
      commissionBps: commissionBps ?? this.commissionBps,
      platformFeePaise: platformFeePaise ?? this.platformFeePaise,
      customerDeliveryFeePaise:
          customerDeliveryFeePaise ?? this.customerDeliveryFeePaise,
      customerPackagingFeePaise:
          customerPackagingFeePaise ??
              this.customerPackagingFeePaise,
      customerGstBps: customerGstBps ?? this.customerGstBps,
      commissionGstBps: commissionGstBps ?? this.commissionGstBps,
      tdsBps: tdsBps ?? this.tdsBps,
      basePayoutPaise: basePayoutPaise ?? this.basePayoutPaise,
      includedDistanceMetres:
          includedDistanceMetres ?? this.includedDistanceMetres,
      perKmPaise: perKmPaise ?? this.perKmPaise,
      stackingBonusPaise:
          stackingBonusPaise ?? this.stackingBonusPaise,
      freeWaitingMinutes:
          freeWaitingMinutes ?? this.freeWaitingMinutes,
      waitingCompPerMinutePaise:
          waitingCompPerMinutePaise ??
              this.waitingCompPerMinutePaise,
      peakWindows: peakWindows ?? this.peakWindows,
      specialIncentives:
          specialIncentives ?? this.specialIncentives,
    );
  }

  /// Throws [ArgumentError] on any rate that would corrupt a bill.
  void validate() {
    void nonNeg(String name, int v) {
      if (v < 0) {
        throw ArgumentError('$name must be >= 0, got $v');
      }
    }

    nonNeg('commissionBps', commissionBps);
    nonNeg('platformFeePaise', platformFeePaise);
    nonNeg('customerDeliveryFeePaise', customerDeliveryFeePaise);
    nonNeg('customerPackagingFeePaise', customerPackagingFeePaise);
    nonNeg('customerGstBps', customerGstBps);
    nonNeg('commissionGstBps', commissionGstBps);
    nonNeg('tdsBps', tdsBps);
    nonNeg('basePayoutPaise', basePayoutPaise);
    nonNeg('includedDistanceMetres', includedDistanceMetres);
    nonNeg('perKmPaise', perKmPaise);
    nonNeg('stackingBonusPaise', stackingBonusPaise);
    nonNeg('freeWaitingMinutes', freeWaitingMinutes);
    nonNeg('waitingCompPerMinutePaise', waitingCompPerMinutePaise);
    if (commissionBps > 10000) {
      throw ArgumentError(
          'commissionBps must be <= 10000, got $commissionBps');
    }
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'effectiveFromIso': effectiveFromIso,
        'commissionBps': commissionBps,
        'platformFeePaise': platformFeePaise,
        'customerDeliveryFeePaise': customerDeliveryFeePaise,
        'customerPackagingFeePaise': customerPackagingFeePaise,
        'customerGstBps': customerGstBps,
        'commissionGstBps': commissionGstBps,
        'tdsBps': tdsBps,
        'basePayoutPaise': basePayoutPaise,
        'includedDistanceMetres': includedDistanceMetres,
        'perKmPaise': perKmPaise,
        'stackingBonusPaise': stackingBonusPaise,
        'freeWaitingMinutes': freeWaitingMinutes,
        'waitingCompPerMinutePaise': waitingCompPerMinutePaise,
        'peakWindows':
            [for (final w in peakWindows) w.toJson()],
        'specialIncentives':
            [for (final s in specialIncentives) s.toJson()],
      };

  static PricingConfig fromJson(Map<String, dynamic> m) {
    return PricingConfig(
      version: (m['version'] as num?)?.toInt() ?? 1,
      effectiveFromIso:
          (m['effectiveFromIso'] as String?) ?? '',
      commissionBps: (m['commissionBps'] as num?)?.toInt() ?? 500,
      platformFeePaise:
          (m['platformFeePaise'] as num?)?.toInt() ?? 200,
      customerDeliveryFeePaise:
          (m['customerDeliveryFeePaise'] as num?)?.toInt() ?? 4000,
      customerPackagingFeePaise:
          (m['customerPackagingFeePaise'] as num?)?.toInt() ?? 0,
      customerGstBps:
          (m['customerGstBps'] as num?)?.toInt() ?? 500,
      commissionGstBps:
          (m['commissionGstBps'] as num?)?.toInt() ?? 1800,
      tdsBps: (m['tdsBps'] as num?)?.toInt() ?? 100,
      basePayoutPaise:
          (m['basePayoutPaise'] as num?)?.toInt() ?? 2500,
      includedDistanceMetres:
          (m['includedDistanceMetres'] as num?)?.toInt() ?? 3000,
      perKmPaise: (m['perKmPaise'] as num?)?.toInt() ?? 700,
      stackingBonusPaise:
          (m['stackingBonusPaise'] as num?)?.toInt() ?? 0,
      freeWaitingMinutes:
          (m['freeWaitingMinutes'] as num?)?.toInt() ?? 5,
      waitingCompPerMinutePaise:
          (m['waitingCompPerMinutePaise'] as num?)?.toInt() ?? 0,
      peakWindows: [
        for (final w in (m['peakWindows'] is List
            ? m['peakWindows'] as List
            : const []))
          PeakWindow.fromJson(w as Map<String, dynamic>),
      ],
      specialIncentives: [
        for (final s in (m['specialIncentives'] is List
            ? m['specialIncentives'] as List
            : const []))
          SpecialIncentive.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}
