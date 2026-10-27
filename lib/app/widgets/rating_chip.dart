import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double rating;

  Color get _color {
    if (rating >= 4.0) return OxroColors.ratingGreen;
    if (rating >= 3.0) return OxroColors.ratingAmber;
    return OxroColors.ratingRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class RatingChip extends StatelessWidget {
  const RatingChip({
    super.key,
    required this.rating,
    this.compact = false,
  });

  final double rating;
  final bool compact;

  Color get _color {
    if (rating >= 4.0) return OxroColors.ratingGreen;
    if (rating >= 3.0) return OxroColors.ratingAmber;
    return OxroColors.ratingRed;
  }

  @override
  Widget build(BuildContext context) {
    final h = compact ? 18.0 : 20.0;
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded,
              size: compact ? 11 : 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
