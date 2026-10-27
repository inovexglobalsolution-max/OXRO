import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/features/categories/presentation/screens/categories_screen.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';

const _dish = Product(
  id: 880011,
  name: 'Hyderabadi Chicken Biryani',
  brand: 'Paradise Biryani',
  restaurantId: 'r_paradise',
  restaurantName: 'Paradise Biryani',
  price: 289,
  mrp: 349,
  rating: 4.5,
  reviews: 12400,
  icon: Icons.rice_bowl_outlined,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
  description: 'Slow-cooked dum biryani with saffron and raita.',
  imageUrl: FoodMedia.biryani,
);

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

bool _hasFoodPhoto(WidgetTester tester) {
  return tester
      .widgetList<FoodImage>(find.byType(FoodImage))
      .any((image) => image.imageUrl?.startsWith('assets/food/') ?? false);
}

void main() {
  testWidgets('PLP and Search cards render local food photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductListingScreen(
          title: 'Biryani',
          leafs: const ['Chicken Biryani'],
          icon: Icons.rice_bowl_outlined,
        ),
      ),
    );
    await _frames(tester);

    expect(
      find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey &&
            key.value is String &&
            (key.value as String).startsWith('plp_card_');
      }),
      findsWidgets,
    );
    expect(_hasFoodPhoto(tester), isTrue);
    await _dispose(tester);

    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await _frames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('search_field')),
      'biryani',
    );
    await _frames(tester);

    expect(find.byKey(const ValueKey('search_grid')), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey &&
            key.value is String &&
            (key.value as String).startsWith('search_card_');
      }),
      findsWidgets,
    );
    expect(_hasFoodPhoto(tester), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Category and sub-category screens use food photos', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _frames(tester);

    expect(_hasFoodPhoto(tester), isTrue);
    await tester.tap(find.text('Biryani'));
    await _frames(tester);

    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(_hasFoodPhoto(tester), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food PDP is dish-specific and hides apparel sizing', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _dish)),
      );
      await _frames(tester);

      expect(find.byKey(const ValueKey('pdp_name')), findsOneWidget);
      expect(find.byKey(const ValueKey('size_chip_M')), findsNothing);
      expect(find.byKey(const ValueKey('size_guide_btn')), findsNothing);
      expect(find.text('Dish details'), findsOneWidget);
      expect(find.text('Kitchen: Paradise Biryani'), findsOneWidget);
      expect(find.text('Freshly prepared'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Product details'), findsNothing);
      expect(_hasFoodPhoto(tester), isTrue);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  test('Generated diet tags follow the dish name', () {
    final chicken = ProductRepo.allFor('Biryani', 'Chicken Biryani');
    expect(chicken, isNotEmpty);
    expect(chicken.every((d) => !d.veg && !d.egg), isTrue);

    final egg = ProductRepo.allFor('Biryani', 'Egg Biryani');
    expect(egg, isNotEmpty);
    expect(egg.every((d) => !d.veg && d.egg), isTrue);

    final veg = ProductRepo.allFor('Biryani', 'Veg Biryani');
    expect(veg, isNotEmpty);
    expect(veg.every((d) => d.veg && !d.egg), isTrue);

    final paneer = ProductRepo.allFor('North Indian', 'Paneer Butter Masala');
    expect(paneer, isNotEmpty);
    expect(paneer.every((d) => d.veg && !d.egg), isTrue);
  });

  test('Generated dishes resolve to real kitchens', () {
    final dishes = ProductRepo.allFor(
      'Biryani',
      'Chicken Biryani',
      icon: Icons.rice_bowl_outlined,
    );

    expect(dishes, isNotEmpty);
    for (final dish in dishes) {
      final restaurant = RestaurantRepo.byId(dish.restaurantId!);
      expect(restaurant, isNotNull, reason: dish.name);
      expect(restaurant!.name, dish.restaurantName);
      expect(dish.brand, restaurant.name);
    }
  });
}
