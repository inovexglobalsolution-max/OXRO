import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

File _goldenFile() {
  const candidates = [
    'test/golden_vectors.json',
    'packages/oxro_pricing/test/golden_vectors.json',
  ];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f;
  }
  throw StateError('golden_vectors.json not found');
}

void main() {
  final golden = jsonDecode(_goldenFile().readAsStringSync())
      as Map<String, dynamic>;
  const engine = PricingEngine(PricingConfig.initial);

  group('golden delivery payouts', () {
    final cases = golden['delivery'] as List;
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final payout = engine.payoutFor(DeliveryPayoutInput(
          roadMetres: (c['roadMetres'] as num).toInt(),
          orderCount: (c['orderCount'] as num).toInt(),
          tipPaise: (c['tipPaise'] as num).toInt(),
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ));
        final e = c['expected'] as Map<String, dynamic>;
        expect(payout.billableKm,
            (e['billableKm'] as num).toDouble(),
            reason: 'billable km');
        expect(payout.basePayoutPaise, e['basePayoutPaise'],
            reason: 'base');
        expect(payout.distancePayPaise, e['distancePayPaise'],
            reason: 'distance pay');
        expect(payout.totalPaise, e['totalPaise'],
            reason: 'total');
      });
    }
  });

  group('golden order bills', () {
    final cases = golden['orders'] as List;
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final subs = [
          for (final s in c['subOrders'] as List)
            _subOrder(s as Map<String, dynamic>),
        ];
        final fee = c['platformFeeOverridePaise'];
        final quote = engine.quoteOrder(OrderQuoteInput(
          subOrders: subs,
          platformFeeOverridePaise: fee == null
              ? null
              : (fee as num).toInt(),
        ));
        final e = c['expected'] as Map<String, dynamic>;
        expect(quote.itemSubtotalPaise, e['itemSubtotalPaise']);
        expect(quote.packagingPaise, e['packagingPaise']);
        expect(quote.deliveryFeePaise, e['deliveryFeePaise']);
        expect(quote.platformFeePaise, e['platformFeePaise']);
        expect(quote.smallCartFeePaise, e['smallCartFeePaise']);
        expect(quote.taxPaise, e['taxPaise']);
        expect(quote.tipPaise, e['tipPaise']);
        expect(quote.discountPaise, e['discountPaise']);
        expect(quote.grandTotalPaise, e['grandTotalPaise']);
        expect(quote.commissionPaise, e['commissionPaise']);
        expect(quote.commissionGstPaise, e['commissionGstPaise']);
        expect(quote.tdsPaise, e['tdsPaise']);
        expect(quote.sellerSettlementPaise, e['sellerSettlementPaise']);
      });
    }
  });

  group('bill invariants', () {
    test('grand total reconciles line by line', () {
      final quote = engine.quoteOrder(const OrderQuoteInput(
        subOrders: [
          SubOrderInput(
            restaurantId: 'r1',
            foodSubtotalPaise: 30000,
            packagingPaise: 2000,
            deliveryFeePaise: 3000,
            restaurantDiscountPaise: 5000,
            oxroDiscountPaise: 1000,
            tipPaise: 1000,
          ),
        ],
      ));
      final sum = quote.itemSubtotalPaise +
          quote.packagingPaise +
          quote.deliveryFeePaise +
          quote.platformFeePaise +
          quote.smallCartFeePaise +
          quote.taxPaise +
          quote.tipPaise -
          quote.discountPaise;
      expect(quote.grandTotalPaise, sum);
    });

    test('platform fee is charged once per order', () {
      final quote = engine.quoteOrder(const OrderQuoteInput(
        subOrders: [
          SubOrderInput(restaurantId: 'r1', foodSubtotalPaise: 20000),
          SubOrderInput(restaurantId: 'r2', foodSubtotalPaise: 10000),
        ],
      ));
      expect(quote.platformFeePaise, 200);
      expect(quote.subOrders.length, 2);
    });

    test('commission + gst + tds + settlement equals base', () {
      final quote = engine.quoteOrder(const OrderQuoteInput(
        subOrders: [
          SubOrderInput(
            restaurantId: 'r1',
            foodSubtotalPaise: 30000,
            restaurantDiscountPaise: 5000,
          ),
        ],
      ));
      final s = quote.subOrders.single;
      expect(
        s.commissionPaise +
            s.commissionGstPaise +
            s.tdsPaise +
            s.settlementPaise,
        s.commissionBasePaise,
      );
    });
  });

  group('small cart fee', () {
    test('slabs match the business rule', () {
      for (final (paise, fee) in [
        (0, 0),
        (100, 2000),
        (4999, 2000),
        (5000, 1500),
        (6999, 1500),
        (7000, 1000),
        (9899, 1000),
        (9900, 0),
        (10000, 0),
        (15000, 0),
      ]) {
        expect(
          PricingEngine.smallCartFeePaiseFor(paise),
          fee,
          reason: '$paise paise',
        );
      }
    });

    test('waiver remaining reaches zero at ₹99 and on an empty cart', () {
      for (final (paise, remaining) in [
        (0, 0),
        (1, 9899),
        (4200, 5700),
        (8500, 1400),
        (9899, 1),
        (9900, 0),
        (10000, 0),
      ]) {
        expect(
          PricingEngine.smallCartFeeWaiverRemainingPaise(paise),
          remaining,
          reason: '$paise paise',
        );
      }
    });

    test('quote adds fee separately from delivery', () {
      final quote = engine.quoteOrder(const OrderQuoteInput(
        subOrders: [
          SubOrderInput(restaurantId: 'r1', foodSubtotalPaise: 4200),
        ],
      ));
      expect(quote.smallCartFeePaise, 2000);
      expect(quote.deliveryFeePaise, 0);
      expect(quote.itemSubtotalPaise, 4200);
      expect(quote.grandTotalPaise, 4200 + 200 + 210 + 2000);
    });

    test('fee is based on the subtotal before a coupon and counted once', () {
      final quote = engine.quoteOrder(const OrderQuoteInput(
        subOrders: [
          SubOrderInput(
            restaurantId: 'r1',
            foodSubtotalPaise: 8500,
            deliveryFeePaise: 3000,
            oxroDiscountPaise: 2000,
          ),
        ],
      ));
      expect(quote.itemSubtotalPaise, 8500);
      expect(quote.smallCartFeePaise, 1000);
      expect(quote.discountPaise, 2000);
      expect(
        quote.grandTotalPaise,
        quote.itemSubtotalPaise +
            quote.packagingPaise +
            quote.deliveryFeePaise +
            quote.platformFeePaise +
            quote.smallCartFeePaise +
            quote.taxPaise -
            quote.discountPaise,
      );
    });

    test('empty cart never carries a fee', () {
      final quote = engine.quoteOrder(
        const OrderQuoteInput(subOrders: []),
      );
      expect(quote.itemSubtotalPaise, 0);
      expect(quote.smallCartFeePaise, 0);
    });
  });

  group('delivery incentives', () {
    test('peak-hour window adds bonus', () {
      final cfg = PricingConfig.initial.copyWith(
        peakWindows: const [
          PeakWindow(
            id: 'lunch',
            label: 'Lunch peak',
            startMinuteOfDay: 12 * 60,
            endMinuteOfDay: 15 * 60,
            bonusPaise: 500,
          ),
        ],
      );
      final payout = PricingEngine(cfg).payoutFor(
        DeliveryPayoutInput(
          roadMetres: 2000,
          acceptedAt: DateTime.utc(2026, 1, 1, 13),
        ),
      );
      expect(payout.peakBonusPaise, 500);
      expect(payout.totalPaise, 3000);
    });

    test('stacked order adds bonus per extra order', () {
      final cfg = PricingConfig.initial.copyWith(
        stackingBonusPaise: 500,
      );
      final payout = PricingEngine(cfg).payoutFor(
        DeliveryPayoutInput(
          roadMetres: 5000,
          orderCount: 3,
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      expect(payout.stackingBonusPaise, 1000);
      expect(payout.totalPaise, 3900 + 1000);
    });

    test('waiting compensation after free minutes', () {
      final cfg = PricingConfig.initial.copyWith(
        freeWaitingMinutes: 5,
        waitingCompPerMinutePaise: 200,
      );
      final payout = PricingEngine(cfg).payoutFor(
        DeliveryPayoutInput(
          roadMetres: 2000,
          waitingMinutes: 15,
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      expect(payout.waitingCompPaise, 2000);
      expect(payout.totalPaise, 4500);
    });

    test('special distance incentive matches range', () {
      final cfg = PricingConfig.initial.copyWith(
        specialIncentives: const [
          SpecialIncentive(
            id: 'long',
            label: 'Long trip',
            bonusPaise: 1000,
            minDistanceMetres: 7000,
          ),
        ],
      );
      final payout = PricingEngine(cfg).payoutFor(
        DeliveryPayoutInput(
          roadMetres: 8000,
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      expect(payout.specialBonusPaise, 1000);
      expect(payout.totalPaise, 6000 + 1000);
    });

    test('penalty never drives payout below zero', () {
      final payout = engine.payoutFor(
        DeliveryPayoutInput(
          roadMetres: 2000,
          penaltyPaise: 999999,
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      expect(payout.totalPaise, 0);
    });
  });

  group('money formatting', () {
    test('indian grouping incl decimals', () {
      expect(Money.inr(123450), '₹1,234.50');
      expect(Money.inr(123400), '₹1,234');
      expect(Money.inr(500), '₹5');
      expect(Money.inr(1234567890), '₹1,23,45,678.90');
      expect(Money.inr(-500), '-₹5');
    });

    test('round half up', () {
      expect(Money.roundHalfUpDiv(5, 2), 3);
      expect(Money.roundHalfUpDiv(4, 2), 2);
      expect(Money.roundHalfUpDiv(-5, 2), -3);
      expect(Money.applyBps(100, 500), 5);
    });
  });

  group('config', () {
    test('initial config validates', () {
      expect(() => PricingConfig.initial.validate(), returnsNormally);
    });

    test('json round trips', () {
      final cfg = PricingConfig.initial.copyWith(
        peakWindows: const [
          PeakWindow(
            id: 'p',
            label: 'Peak',
            startMinuteOfDay: 60,
            endMinuteOfDay: 120,
            bonusPaise: 300,
          ),
        ],
        specialIncentives: const [
          SpecialIncentive(
            id: 's',
            label: 'Special',
            bonusPaise: 100,
            minOrderCount: 2,
          ),
        ],
      );
      final back = PricingConfig.fromJson(cfg.toJson());
      expect(back.commissionBps, cfg.commissionBps);
      expect(back.peakWindows.single.bonusPaise, 300);
      expect(back.specialIncentives.single.minOrderCount, 2);
    });

    test('rejects invalid rates', () {
      expect(
        () => PricingConfig.initial
            .copyWith(commissionBps: 10001)
            .validate(),
        throwsArgumentError,
      );
    });
  });
}

SubOrderInput _subOrder(Map<String, dynamic> m) => SubOrderInput(
      restaurantId: (m['restaurantId'] as String?) ?? '',
      foodSubtotalPaise: (m['foodSubtotalPaise'] as num).toInt(),
      packagingPaise: (m['packagingPaise'] as num?)?.toInt() ?? 0,
      deliveryFeePaise: (m['deliveryFeePaise'] as num?)?.toInt() ?? 0,
      restaurantDiscountPaise:
          (m['restaurantDiscountPaise'] as num?)?.toInt() ?? 0,
      oxroDiscountPaise:
          (m['oxroDiscountPaise'] as num?)?.toInt() ?? 0,
      tipPaise: (m['tipPaise'] as num?)?.toInt() ?? 0,
      commissionBpsOverride:
          (m['commissionBpsOverride'] as num?)?.toInt(),
    );
