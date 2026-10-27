import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _pumpSearch(WidgetTester tester) async {
  SearchRepo.clearRecents();
  await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
  await _settle(tester);
}

void main() {
  testWidgets('Empty state shows trending + field', (tester) async {
    await _pumpSearch(tester);

    expect(find.byKey(const ValueKey('search_field')), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('No recent searches yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Typing biryani shows results + count', (tester) async {
    await _pumpSearch(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search_field')),
      'biryani',
    );
    await _frames(tester);
    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);
    expect(find.textContaining('dishes'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Gibberish shows empty + popular + clear restores', (
    tester,
  ) async {
    await _pumpSearch(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search_field')),
      'zzzqqqnope',
    );
    await _frames(tester);
    expect(find.byKey(const ValueKey('search_empty')), findsOneWidget);
    expect(find.text('Popular right now'), findsOneWidget);
    expect(find.byKey(const ValueKey('search_empty_popular')), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await _settle(tester);
    expect(find.text('Trending'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Trending chip runs query, result taps to PDP', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.text('Biryani').first);
    await _frames(tester);
    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);

    final card = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              (w.key as ValueKey).value is String &&
              ((w.key as ValueKey).value as String).startsWith('search_card_'),
        )
        .first;
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    // Tap the image area (top of card) — center can land on the
    // full-width ADD bar, which adds to cart instead of opening PDP.
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    expect(find.byKey(const ValueKey('pdp_name')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Search 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('search_field')),
        'dosa',
      );
      await _frames(tester, 4);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Filter bar narrows results', (tester) async {
    await _pumpSearch(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search_field')),
      'biryani',
    );
    await _frames(tester);
    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter_rating')), findsOneWidget);

    // 4+ rating keeps only high-rated.
    await tester.tap(find.byKey(const ValueKey('filter_rating')));
    await _frames(tester);
    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);

    // 50%+ off on top narrows further (may empty out).
    await tester.tap(find.byKey(const ValueKey('filter_off')));
    await _frames(tester);
    expect(
      find.byKey(const ValueKey('search_grid')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('search_empty')).evaluate().isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Sort sheet changes order', (tester) async {
    await _pumpSearch(tester);

    await tester.enterText(find.byKey(const ValueKey('search_field')), 'dosa');
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('filter_sort')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('sort_opt_priceLow')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sort_opt_priceLow')));
    await _frames(tester);
    expect(find.textContaining('Sort: Price: Low to High'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Typing shows tappable dish suggestions', (tester) async {
    await _pumpSearch(tester);

    await tester.enterText(find.byKey(const ValueKey('search_field')), 'biry');
    await tester.pump();

    expect(find.byKey(const ValueKey('search_suggestions')), findsOneWidget);
    expect(find.byKey(const ValueKey('search_suggestion_0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search_suggestion_0')));
    await _frames(tester);

    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('search_field')),
    );
    expect(field.controller!.text.toLowerCase(), contains('biry'));
    expect(SearchRepo.recents.first, field.controller!.text);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Recent delete removes one row', (tester) async {
    SearchRepo.clearRecents();
    SearchRepo.pushRecent('biryani');
    SearchRepo.pushRecent('pizza');
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('recent_chip_0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recent_del_0')));
    await _settle(tester);
    expect(SearchRepo.recents, ['biryani']);
    // Chip tap eaten: still idle, no results grid.
    expect(find.byKey(const ValueKey('search_grid')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  // ---- Repo unit tests (pure logic) ----
  test('Empty query returns nothing', () {
    expect(SearchRepo.searchProducts('   '), isEmpty);
  });

  test('Brand query finds products', () {
    final hits = SearchRepo.searchProducts('biryani');
    expect(hits, isNotEmpty);
    expect(
      hits.any(
        (p) =>
            p.name.toLowerCase().contains('biryani') ||
            p.brand.toLowerCase().contains('biryani'),
      ),
      isTrue,
    );
  });

  test('Category query finds products', () {
    expect(SearchRepo.searchProducts('pizza'), isNotEmpty);
  });

  test('Dish suggestions rank names, dedupe and cap', () {
    final hits = SearchRepo.dishSuggestions('biry', limit: 6);
    expect(hits, isNotEmpty);
    expect(hits.length, lessThanOrEqualTo(6));
    final names = [for (final p in hits) p.name.toLowerCase()];
    expect(names.toSet().length, names.length);
    expect(hits.first.name.toLowerCase(), contains('biry'));
    expect(SearchRepo.dishSuggestions('zzzqqqnope'), isEmpty);
    expect(SearchRepo.dishSuggestions('').length, 8);
  });

  test('Rotating hint names are unique catalogue dishes', () {
    final names = SearchRepo.dishNames;
    expect(names.length, greaterThan(50));
    expect(names.toSet().length, names.length);
  });

  test('Recents push/dedupe/clear', () {
    SearchRepo.clearRecents();
    SearchRepo.pushRecent('biryani');
    SearchRepo.pushRecent('biryani');
    SearchRepo.pushRecent('dosa');
    expect(SearchRepo.recents, ['dosa', 'biryani']);
    SearchRepo.removeRecentAt(0);
    expect(SearchRepo.recents, ['biryani']);
    SearchRepo.clearRecents();
    expect(SearchRepo.recents, isEmpty);
  });

  test('Recents persist across reload', () async {
    SharedPreferences.setMockInitialValues({});
    SearchRepo.clearRecents();
    SearchRepo.pushRecent('biryani');
    SearchRepo.pushRecent('pizza');
    // Let fire-forget prefs writes land.
    await Future.delayed(const Duration(milliseconds: 100));
    // Simulate restart: wipe memory, reload from prefs.
    SearchRepo.recents.clear();
    await SearchRepo.loadRecents();
    expect(SearchRepo.recents, ['pizza', 'biryani']);
    SearchRepo.clearRecents();
  });

  test('applyFilters sorts + narrows', () {
    final hits = SearchRepo.searchProducts('dosa');
    expect(hits, isNotEmpty);
    final cheap = SearchRepo.applyFilters(hits, sort: SearchSort.priceLow);
    for (var i = 1; i < cheap.length; i++) {
      expect(cheap[i].price >= cheap[i - 1].price, isTrue);
    }
    final rated = SearchRepo.applyFilters(hits, minRating: 4);
    expect(rated.every((p) => p.rating >= 4), isTrue);
    expect(rated.length <= hits.length, isTrue);
  });
}
