import 'package:flutter/material.dart';

import 'package:oxro/features/home/data/home_data.dart';

/// Shared gradient identity per category (matches home banner palette).
/// Single source for Categories grid + Home Myntra cards + L2 header.
const _catGradients = [
  [Color(0xFF0A8CFF), Color(0xFF004E92)], // Electro
  [Color(0xFFFF8A00), Color(0xFFFF4D00)], // Fashion
  [Color(0xFF0E9F6E), Color(0xFF03543F)], // Home
  [Color(0xFFE91E63), Color(0xFF9C27B0)], // Beauty
  [Color(0xFF65A30D), Color(0xFF1A2E05)], // Sports
  [Color(0xFFD97706), Color(0xFF78350F)], // Books
  [Color(0xFF475569), Color(0xFF0F172A)], // Auto
  [Color(0xFF8B5CF6), Color(0xFF4C1D95)], // Toys
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
