import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/widgets/filter_chip_row.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 220));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _showFilters(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('home_scroll')),
    const Offset(0, -320),
  );
  await _settle(tester);
}

Future<void> _tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey(key));
  await tester.ensureVisible(chip);
  await _settle(tester);
  await tester.tap(chip);
  await _settle(tester);
}

bool _isSelected(WidgetTester tester, String key) {
  return tester.widget<OxroFilterChip>(find.byKey(ValueKey(key))).selected;
}

void main() {
  testWidgets('Home shows reference filter chips and toggles them', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showFilters(tester);

    expect(find.byKey(const ValueKey('home_filter_schedule')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_filter_great_offers')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home_filter_rating4')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_filter_pure_veg')), findsOneWidget);

    await _tapChip(tester, 'home_filter_great_offers');
    expect(_isSelected(tester, 'home_filter_great_offers'), isTrue);
    await _tapChip(tester, 'home_filter_great_offers');
    expect(_isSelected(tester, 'home_filter_great_offers'), isFalse);

    await _tapChip(tester, 'home_filter_rating4');
    expect(_isSelected(tester, 'home_filter_rating4'), isTrue);
    await _tapChip(tester, 'home_filter_rating4');
    expect(_isSelected(tester, 'home_filter_rating4'), isFalse);

    await _tapChip(tester, 'home_filter_pure_veg');
    expect(_isSelected(tester, 'home_filter_pure_veg'), isTrue);
    await _tapChip(tester, 'home_filter_pure_veg');
    expect(_isSelected(tester, 'home_filter_pure_veg'), isFalse);

    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Schedule sheet saves and clears the selected slot', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showFilters(tester);

    await _tapChip(tester, 'home_filter_schedule');
    expect(find.byKey(const ValueKey('schedule_sheet')), findsOneWidget);
    expect(find.text('Select your delivery time'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule_date_1')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_slot_0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_confirm')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('schedule_sheet')), findsNothing);
    final scheduleChip = find.byKey(const ValueKey('home_filter_schedule'));
    expect(
      find.descendant(
        of: scheduleChip,
        matching: find.textContaining('Tomorrow · '),
      ),
      findsOneWidget,
    );
    expect(_isSelected(tester, 'home_filter_schedule'), isTrue);

    await tester.tap(scheduleChip);
    await _settle(tester);
    expect(find.byKey(const ValueKey('schedule_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule_close')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('schedule_sheet')), findsNothing);

    final clear = find.descendant(
      of: scheduleChip,
      matching: find.byIcon(Icons.close),
    );
    expect(clear, findsOneWidget);
    await tester.tap(clear);
    await _settle(tester);

    expect(_isSelected(tester, 'home_filter_schedule'), isFalse);
    expect(
      find.descendant(of: scheduleChip, matching: find.text('Schedule')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
