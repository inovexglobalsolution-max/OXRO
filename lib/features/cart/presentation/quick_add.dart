import 'package:flutter/material.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/presentation/widgets/customize_sheet.dart';

/// Adds [product] from any browse surface with the same rules:
/// customization sheet for dishes with options, a replace-bag prompt
/// when switching kitchens, and multi-quantity support.
Future<void> quickAddProduct(
  BuildContext context,
  Product product, {
  String? size,
  bool customize = true,
}) async {
  final store = CartStore.instance;
  var selected = product;
  var selectedSize = size;
  var qty = 1;

  if (customize && product.options.isNotEmpty) {
    final picked = await showDishCustomizeSheet(context, product);
    if (picked == null || !context.mounted) return;
    selected = picked.product;
    selectedSize = picked.variant;
    qty = picked.qty;
  }

  if (store.belongsToOtherRestaurant(selected)) {
    final replace = await _confirmReplace(context, store, selected);
    if (replace != true || !context.mounted) return;
    store.replaceWith(selected, size: selectedSize);
  } else {
    store.add(selected, size: selectedSize);
  }

  for (var i = 1; i < qty; i++) {
    store.add(selected, size: selectedSize);
  }
}

Future<bool?> _confirmReplace(
  BuildContext context,
  CartStore store,
  Product next,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Replace items?'),
      content: Text(
        'Your bag has items from ${store.restaurantName ?? 'another restaurant'}. '
        'Adding from ${next.restaurantName ?? 'this restaurant'} will clear your bag.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('replace_cart_no'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep bag'),
        ),
        TextButton(
          key: const ValueKey('replace_cart_yes'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
}
