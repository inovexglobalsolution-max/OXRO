import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Reusable Add-to-Cart bar: "ADD" → stepper (− qty +).
/// Full-width bar at the bottom of the product info section.
/// Both states share the same orange fill + height (~30px) so ADD ↔
/// stepper swaps without a visual jump. Rebuilds from [CartStore].
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final qty = CartStore.instance.qty(product.id);
        if (qty <= 0) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('add_pop_${product.id}_$qty'),
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: GestureDetector(
            key: ValueKey('add_${product.id}'),
            onTap: () => CartStore.instance.add(product),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: OxroColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22051D47), blurRadius: 6),
                ],
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
            ),
          );
        }
        return TweenAnimationBuilder<double>(
          key: ValueKey('stepper_pop_${product.id}_$qty'),
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Transform.scale(
            scale: v,
            child: Container(
          key: ValueKey('stepper_${product.id}'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: OxroColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22051D47), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                key: ValueKey('dec_${product.id}'),
                onTap: () =>
                    CartStore.instance.decrement(product.id),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  child: Text('−',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              Text('$qty',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              GestureDetector(
                key: ValueKey('inc_${product.id}'),
                onTap: () =>
                    CartStore.instance.increment(product.id),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  child: Text('+',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
            ),
          ),
        );
        },
      );
  }
}

/// Live bag-count badge (hides when empty).
/// Small royal-blue circle with white ring + count pop on change.
class BagBadge extends StatelessWidget {
  const BagBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final n = CartStore.instance.count;
        if (n <= 0) return const SizedBox.shrink();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Container(
            key: ValueKey('bag_badge_$n'),
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OxroColors.royalBlue,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.royalBlue
                      .withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(n > 9 ? '9+' : '$n',
                key: const ValueKey('bag_badge_count'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0)),
          ),
        );
      },
    );
  }
}
