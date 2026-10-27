import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

class AddStepper extends StatelessWidget {
  const AddStepper({
    super.key,
    required this.product,
    this.onAdd,
    this.width = 96,
  });

  final Product product;
  final VoidCallback? onAdd;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final qty = CartStore.instance.qty(product.id);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: qty <= 0
              ? _AddButton(
                  key: ValueKey('food_add_${product.id}'),
                  width: width,
                  onTap: onAdd ??
                      () => CartStore.instance.add(product),
                )
              : _Stepper(
                  key: ValueKey('food_stepper_${product.id}'),
                  width: width,
                  qty: qty,
                  onMinus: () =>
                      CartStore.instance.decrement(product.id),
                  onPlus: () =>
                      CartStore.instance.increment(product.id),
                ),
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    super.key,
    required this.width,
    required this.onTap,
  });

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: OxroColors.coral, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22051D47),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ADD',
              style: TextStyle(
                color: OxroColors.coral,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            Transform.translate(
              offset: const Offset(-1, -2),
              child: const Text(
                '+',
                style: TextStyle(
                  color: OxroColors.coral,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.width,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final double width;
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: OxroColors.coral, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22051D47),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onMinus,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '−',
                style: TextStyle(
                  color: OxroColors.coral,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: OxroColors.coral,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '+',
                style: TextStyle(
                  color: OxroColors.coral,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
