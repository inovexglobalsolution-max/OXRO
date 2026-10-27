import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Share text for a product (unit-tested format).
String shareTextFor(Product p) =>
    'Check this on OXRO: ${p.brand} ${p.name} at '
    '${Product.inr(p.price)} (${p.off}% off) — https://oxro.in/p/${p.id}';

/// Opens the platform share sheet for [p] (WhatsApp, SMS, …).
Future<void> shareProduct(Product p) {
  return SharePlus.instance.share(ShareParams(text: shareTextFor(p)));
}

/// White-circle share button matching the wishlist heart style.
/// Key: `share_<productId>` on every surface.
class ProductShareButton extends StatelessWidget {
  const ProductShareButton(
      {super.key, required this.product, this.size = 15});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('share_${product.id}'),
      onTap: () => shareProduct(product),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.ios_share_outlined,
            size: size, color: OxroColors.muted),
      ),
    );
  }
}
