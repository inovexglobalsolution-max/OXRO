import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled food image exists', () async {
    for (final path in FoodMedia.all) {
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: 'Missing or empty asset: $path',
      );
    }
  });

  test('home banners and dishes use bundled photos', () {
    for (final banner in homeBanners) {
      expect(FoodMedia.isAsset(banner.imageUrl), isTrue);
    }
    for (final deal in homeDeals) {
      expect(FoodMedia.isAsset(deal.imageUrl), isTrue);
    }
    for (final category in homeCategories) {
      expect(FoodMedia.isAsset(FoodMedia.forCategory(category.label)), isTrue);
    }
  });

  test('restaurants and generated catalogue resolve to bundled photos', () {
    for (final restaurant in RestaurantRepo.all) {
      expect(
        FoodMedia.isAsset(restaurant.imageUrl),
        isTrue,
        reason: restaurant.name,
      );
      for (final dish in restaurant.dishes) {
        expect(FoodMedia.isAsset(dish.imageUrl), isTrue);
      }
    }
    final products = ProductRepo.allFor('Biryani', 'Chicken Biryani');
    expect(products, isNotEmpty);
    for (final product in products) {
      expect(FoodMedia.isAsset(product.imageUrl), isTrue);
    }
  });

  test('generated dishes alternate photos within a category', () {
    final products = ProductRepo.allFor('Biryani', 'Chicken Biryani');
    final images = [for (final p in products) p.imageUrl];
    expect(images.toSet().length, greaterThan(1));
    final kitchen = RestaurantRepo.byId('r_paradise')!;
    expect(images, isNot(contains(kitchen.imageUrl)));
  });

  test('restaurant menus do not repeat a dish name', () {
    for (final restaurant in RestaurantRepo.all) {
      final names = [
        for (final section in restaurant.menu)
          for (final dish in section.dishes) dish.name.trim().toLowerCase(),
      ];
      expect(
        names.toSet().length,
        names.length,
        reason: 'Duplicate dish names in ${restaurant.name}',
      );
    }
  });

  testWidgets('FoodImage renders a bundled asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodImage(
            imageUrl: FoodMedia.pizza,
            colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
            width: 120,
            height: 100,
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect((resized.imageProvider as AssetImage).assetName, FoodMedia.pizza);
    expect(tester.takeException(), isNull);
  });
}
