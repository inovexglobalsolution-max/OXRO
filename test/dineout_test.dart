import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/dineout/data/dineout_repo.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_detail_screen.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  test('Dineout repo filters by cuisine + query', () {
    expect(DineoutRepo.all.length, 6);
    expect(DineoutRepo.filter(cuisine: 'Italian').length, 2);
    expect(DineoutRepo.filter(query: 'anna').single.id, 'd_verandah');
    expect(DineoutRepo.filter(query: 'asian').single.id, 'd_miso_street');
    expect(DineoutRepo.filter(query: 'nothing here'), isEmpty);
    expect(DineoutRepo.byId('d_saffron_house')!.pureVeg, isTrue);
    expect(DineoutRepo.byId('missing'), isNull);
  });

  testWidgets('Dineout lists restaurants and opens detail', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DineoutScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('dineout_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('dineout_hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_dineout_banner')), findsNothing);
    expect(find.text('Top tables near you'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dineout_card_d_verandah')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dineout_card_d_verandah')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('dineout_detail_screen')), findsOneWidget);
    expect(find.text('The Verandah'), findsOneWidget);
    expect(find.byKey(const ValueKey('dineout_book')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Dineout cuisine filter + search narrow the list', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DineoutScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_filter_Italian')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('dineout_card_d_verandah')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dineout_card_d_copper_clay')),
      findsNothing,
    );
    expect(find.text('2 places'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('dineout_search')),
      'basil',
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('dineout_card_d_basil_bloom')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('dineout_card_d_verandah')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('dineout_search')),
      'zzzz',
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('dineout_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Dineout booking captures guests + slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_guests_4')));
    await _settle(tester);
    final slot = find.byKey(const ValueKey('dineout_slot_800'));
    await tester.dragUntilVisible(
      slot,
      find.byKey(const ValueKey('dineout_detail_scroll')),
      const Offset(0, -180),
    );
    await _settle(tester);
    await tester.tap(slot);
    await _settle(tester);
    expect(find.text('4 guests • 8:00 PM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);
    expect(
      find.textContaining('Table request sent for 4 at 8:00 PM'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Dineout 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: DineoutScreen()));
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: 'listing at 320');

    await tester.pumpWidget(
      const MaterialApp(
        home: DineoutDetailScreen(restaurantId: 'd_saffron_house'),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: 'detail at 320');
    await _dispose(tester);
  });
}
