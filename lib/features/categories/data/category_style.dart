import 'package:flutter/material.dart';

import 'package:oxro/features/home/data/home_data.dart';

/// Shared gradient identity per food category (matches home palette).
/// Single source for Categories grid + Home cards + L2 header.
/// 30 pairs, index-coded to [homeCategories] order.
const _catGradients = [
  [Color(0xFFFF8A00), Color(0xFFD1481C)], // Biryani
  [Color(0xFFDC2626), Color(0xFF7F1D1D)], // North Indian
  [Color(0xFF0E9F6E), Color(0xFF03543F)], // South Indian
  [Color(0xFFEF4444), Color(0xFF991B1B)], // Chinese
  [Color(0xFFF59E0B), Color(0xFFB45309)], // Pizza
  [Color(0xFFD97706), Color(0xFF78350F)], // Burgers
  [Color(0xFF65A30D), Color(0xFF1A2E05)], // Rolls & Wraps
  [Color(0xFF14B8A6), Color(0xFF0F766E)], // Sandwiches
  [Color(0xFFA855F7), Color(0xFF6B21A8)], // Momos
  [Color(0xFFDC2626), Color(0xFF450A0A)], // Pasta & Italian
  [Color(0xFF16A34A), Color(0xFF14532D)], // Thai
  [Color(0xFFB45309), Color(0xFF451A03)], // Mughlai
  [Color(0xFF2563EB), Color(0xFF1E3A8A)], // Bengali
  [Color(0xFFCA8A04), Color(0xFF713F12)], // Punjabi
  [Color(0xFF0D9488), Color(0xFF134E4A)], // Gujarati
  [Color(0xFFEA580C), Color(0xFF7C2D12)], // Rajasthani
  [Color(0xFF8B5CF6), Color(0xFF4C1D95)], // Street Food
  [Color(0xFFE11D48), Color(0xFF881337)], // Chaat
  [Color(0xFFE91E63), Color(0xFF9C27B0)], // Desserts
  [Color(0xFF06B6D4), Color(0xFF155E75)], // Ice Cream
  [Color(0xFFF472B6), Color(0xFF9D174D)], // Bakery & Cakes
  [Color(0xFF0A8CFF), Color(0xFF004E92)], // Beverages
  [Color(0xFFF97316), Color(0xFF9A3412)], // Juices & Shakes
  [Color(0xFF78350F), Color(0xFF3F1D0B)], // Tea & Coffee
  [Color(0xFF22C55E), Color(0xFF166534)], // Healthy & Salads
  [Color(0xFFFFB020), Color(0xFFB26B00)], // Breakfast
  [Color(0xFF0891B2), Color(0xFF164E63)], // Seafood
  [Color(0xFF475569), Color(0xFF0F172A)], // BBQ & Grills
  [Color(0xFF15803D), Color(0xFF052E16)], // Kerala
  [Color(0xFF6366F1), Color(0xFF312E81)], // Tibetan
];

/// Index of [label] in [homeCategories], -1 when unknown.
int catIndexForLabel(String label) {
  for (var i = 0; i < homeCategories.length; i++) {
    if (homeCategories[i].label == label) return i;
  }
  return -1;
}

/// Gradient for a category index (wraps safely).
List<Color> catGradient(int index) =>
    _catGradients[index % _catGradients.length];

/// Gradient for a category label (falls back to brand gradient).
List<Color> catGradientForLabel(String label) {
  final i = catIndexForLabel(label);
  if (i < 0) return const [Color(0xFFFF6A00), Color(0xFF082B66)];
  return catGradient(i);
}
