import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/widgets/dish_row.dart';
import 'package:oxro/app/widgets/restaurant_card.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(CartStore.resetForTests);

  test('Every restaurant has a gallery of up to 7 unique photos', () {
    for (final r in RestaurantRepo.all) {
      final photos = r.photos;
      expect(photos, isNotEmpty, reason: r.name);
      expect(photos.length, greaterThan(1), reason: r.name);
      expect(photos.length, lessThanOrEqualTo(7), reason: r.name);
      expect(photos.toSet().length, photos.length, reason: r.name);
      expect(photos.first, r.imageUrl, reason: r.name);
      expect(photos.every(FoodMedia.isAsset), isTrue, reason: r.name);
    }
  });

  testWidgets('Restaurant card swipes through its gallery', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final r = RestaurantRepo.byId('r_paradise')!;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: RestaurantCard(restaurant: r, onTap: () => opened = true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gallery = find.byKey(ValueKey('restaurant_gallery_${r.id}'));
    expect(gallery, findsOneWidget);
    expect(r.photos.length, 7);
    expect(
      find.byKey(ValueKey('restaurant_gallery_dot_${r.id}_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('restaurant_gallery_dot_${r.id}_6')),
      findsOneWidget,
    );

    await tester.drag(gallery, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(gallery).controller!.page!.round(), 1);

    await tester.tap(find.byKey(ValueKey('restaurant_card_${r.id}')));
    await tester.pump();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  test('Budget filter limits restaurants by cost for two', () {
    const filters = RestaurantFilters(maxCostForTwo: 250);
    final results = filterRestaurants(RestaurantRepo.all, filters);
    expect(results, isNotEmpty);
    expect(results.length, lessThan(RestaurantRepo.all.length));
    expect(results.every((r) => r.costForTwo <= 250), isTrue);
    expect(filters.isActive, isTrue);
    expect(filters.count, 1);
    expect(filters.copyWith(clearMaxCost: true).maxCostForTwo, isNull);
  });

  testWidgets('Customise sheet adds variant with add-on price', (tester) async {
    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    final add = find.byKey(ValueKey('food_add_${dish.id}'));
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customize_add')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('customize_1_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_1_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();

    expect(CartStore.instance.qty(dish.id), 1);
    final line = CartStore.instance.lines.single;
    expect(line.product.price, dish.price + 40);
    expect(line.size, contains('Extra Cheese'));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Customise sheet uses section cards, toggles and qty bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final r = RestaurantRepo.all.first;
    final dish = r.dishes.firstWhere(
      (d) => d.options.length > 1 && d.options[1].options.isNotEmpty,
    );
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    final add = find.byKey(ValueKey('food_add_${dish.id}'));
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customize_group_0')), findsOneWidget);
    expect(find.text('Select up to 1 option'), findsWidgets);
    expect(find.text('Select up to 2 options'), findsWidgets);
    expect(find.byKey(const ValueKey('customize_qty_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('customize_close')), findsOneWidget);

    final totals = find.byKey(const ValueKey('customize_total'));
    final before = tester.widget<Text>(totals).data;

    final group = dish.options[1];
    final picked = group.options.indexWhere((o) => o.priceDelta > 0);
    final optionKey = ValueKey('customize_1_$picked');
    await tester.ensureVisible(find.byKey(optionKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(optionKey));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.widget<Text>(totals).data, isNot(before));

    await tester.tap(find.byKey(const ValueKey('customize_plus')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('customize_qty'))).data,
      '2',
    );
    expect(find.text('Add 2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Adding from another kitchen asks to replace', (tester) async {
    const old = Product(
      id: 900001,
      name: 'Old Kitchen Dish',
      brand: 'Old Kitchen',
      restaurantId: 'R-OLD',
      restaurantName: 'Old Kitchen',
      price: 150,
      mrp: 200,
      rating: 4.0,
      reviews: 10,
      icon: Icons.rice_bowl,
      colors: [Colors.white, Colors.black],
    );
    CartStore.instance.add(old);

    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    final add = find.byKey(ValueKey('food_add_${dish.id}'));
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();

    expect(find.text('Replace items?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('replace_cart_yes')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(CartStore.instance.restaurantId, r.id);
    expect(CartStore.instance.restaurantName, r.name);
    expect(CartStore.instance.distinct, 1);
    expect(CartStore.instance.contains(old.id), isFalse);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Menu bar pins and section chip jumps to category', (
    tester,
  ) async {
    final r = RestaurantRepo.all.firstWhere((r) => r.menu.length > 1);
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    final second = find.byKey(const ValueKey('restaurant_section_header_1'));
    expect(second, findsOneWidget);
    final before = tester.getTopLeft(second).dy;

    await tester.tap(find.byKey(const ValueKey('restaurant_section_chip_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));

    expect(tester.getTopLeft(second).dy, lessThan(before));
    final bar = find.byKey(const ValueKey('restaurant_menu_bar'));
    expect(bar, findsOneWidget);
    expect(tester.getTopLeft(bar).dy, lessThan(100));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Veg filter hides non-veg dishes', (tester) async {
    final r = RestaurantRepo.all.firstWhere(
      (r) =>
          !r.pureVeg &&
          r.dishes.any((d) => d.veg) &&
          r.dishes.any((d) => !d.veg),
    );
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('restaurant_filter_veg')));
    await _settle(tester);

    final rows = tester.widgetList<DishRow>(find.byType(DishRow)).toList();
    expect(rows, isNotEmpty);
    expect(rows.every((row) => row.dish.veg), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Non-veg filter shows the non-veg dishes', (tester) async {
    final r = RestaurantRepo.byId('r_paradise')!;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('restaurant_filter_nonveg')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_empty_menu')), findsNothing);
    final rows = tester.widgetList<DishRow>(find.byType(DishRow)).toList();
    expect(rows, isNotEmpty);
    expect(rows.every((row) => !row.dish.veg), isTrue);
    expect(find.text('0 dishes'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Menu search opens a dish', (tester) async {
    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('restaurant_menu_search')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('menu_search_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('menu_search_field')),
      dish.name,
    );
    await tester.pump();
    final result = find.byKey(ValueKey('menu_search_result_${dish.id}'));
    expect(result, findsOneWidget);

    await tester.tap(result);
    await tester.pump();
    await _settle(tester);
    expect(find.byKey(const ValueKey('pdp_name')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag shows the restaurant + minimum order rule', (tester) async {
    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    CartStore.instance.add(dish);
    await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_restaurant')), findsOneWidget);
    expect(find.text(r.name), findsWidgets);
    if (dish.price < r.minOrder) {
      expect(find.byKey(const ValueKey('bag_min_order')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag saves note + cutlery for food order', (tester) async {
    final dish = RestaurantRepo.all.first.dishes.first;
    CartStore.instance.add(dish);
    await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);

    final scroll = find.byKey(const ValueKey('bag_lines'));
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('bag_note')),
      scroll,
      const Offset(0, -220),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_food_prefs')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bag_note')));
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('bag_note_field')),
      'Less spicy, please',
    );
    await tester.tap(find.byKey(const ValueKey('bag_note_save')));
    await _settle(tester);

    expect(CartStore.instance.instructions, 'Less spicy, please');
    expect(find.byKey(const ValueKey('bag_note_value')), findsOneWidget);
    expect(find.text('Less spicy, please'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
