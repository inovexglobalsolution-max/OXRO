import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/categories/data/food_taxonomy.dart';

void main() {
  test('30 categories, 291 sub-categories, all unique', () {
    expect(foodCategories.length, 30);
    expect(foodSubcategories.length, 30);

    final labels = <String>{};
    var subCount = 0;
    for (final c in foodCategories) {
      expect(labels.add(c.label), isTrue,
          reason: 'duplicate category ${c.label}');
      final subs = subcategoriesFor(c.label);
      expect(subs, isNotEmpty,
          reason: '${c.label} has no sub-categories');
      final subSet = <String>{};
      for (final s in subs) {
        expect(subSet.add(s), isTrue,
            reason: 'duplicate sub "$s" in ${c.label}');
      }
      subCount += subs.length;
    }

    expect(subCount, 291);
    for (final key in foodSubcategories.keys) {
      expect(labels.contains(key), isTrue,
          reason: 'orphan sub-category group "$key"');
    }
  });

  test('lookup + unknown fallbacks', () {
    expect(foodCategoryFor('Biryani')?.short, 'Biryani');
    expect(foodCategoryFor('Nope'), isNull);
    expect(subcategoriesFor('Pizza'), contains('Margherita'));
    expect(subcategoriesFor('Nope'), isEmpty);
  });
}
