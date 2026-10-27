import 'package:flutter/material.dart';

import 'package:oxro/app/data/food_media.dart';

/// Photo tile with a calm branded fallback.
///
/// Sources can be bundled (`assets/...`) or remote. Local assets are preferred
/// because they keep the catalogue image-rich without waiting on the network.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.imageUrl,
    required this.colors,
    this.icon = Icons.restaurant_outlined,
    this.width,
    this.height,
    this.radius = 16,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String? imageUrl;
  final List<Color> colors;
  final IconData icon;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length >= 2
              ? colors
              : const [Color(0xFFF4F7FB), Color(0xFFE5EBF2)],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: (height ?? 96) * 0.32,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }

  int? _cacheWidth(BuildContext context) {
    final target = width;
    if (target == null || !target.isFinite) return null;
    return (target * MediaQuery.devicePixelRatioOf(context)).round();
  }

  Widget _placeholder(BuildContext context) => _fallback();

  @override
  Widget build(BuildContext context) {
    final source = imageUrl;
    final cacheWidth = _cacheWidth(context);
    final Widget photo;
    if (source == null || source.isEmpty) {
      photo = const SizedBox.shrink();
    } else if (FoodMedia.isAsset(source)) {
      photo = Image.asset(
        source,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) {
          if (sync || frame != null) return child;
          return _placeholder(context);
        },
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      photo = Image.network(
        source,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) {
          if (sync) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(fit: StackFit.expand, children: [_fallback(), photo]),
      ),
    );
  }
}
