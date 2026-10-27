/// Backwards-compatible entry point for the flat food taxonomy.
///
/// The old Myntra-style Category → Tabs → Groups → Leafs tree was
/// replaced by a flat Category → Sub-category model. Everything that
/// used to import the tree now reads [foodSubcategories] /
/// [subcategoriesFor] / [foodCategories] from here.
library;

export 'package:oxro/features/categories/data/food_taxonomy.dart';
