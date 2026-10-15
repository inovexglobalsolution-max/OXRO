import 'package:flutter/material.dart';

/// OXRO brand tokens — synced with website (https://oxro.in/).
/// Orange #FF6A00 primary · Navy #082B66 secondary · Dark #051D47 ·
/// Sky #27A9E1 accents · White #FFFFFF cards · Page #F4F7FB ·
/// Ink #102A43 text · Muted #62758A · Border #E5EBF2.
class OxroColors {
  // CTA gradient ends (website: #FF6A00 -> #FF8738).
  static const orangeTop = Color(0xFFFF6A00);
  static const orangeBottom = Color(0xFFFF8738);
  static const orangeDark = Color(0xFFE85D00);

  // Website primaries.
  static const primary = Color(0xFFFF6A00);
  static const royalBlue = Color(0xFF082B66);
  static const navyDark = Color(0xFF051D47);
  static const authBlue = Color(0xFF0B5CAB);
  static const skyBlue = Color(0xFF27A9E1);
  static const skyAlt = Color(0xFF38BDF8);
  static const lightGrey = Color(0xFFF4F7FB);
  static const pageBg = Color(0xFFF4F7FB);
  static const charcoal = Color(0xFF102A43);
  static const muted = Color(0xFF62758A);
  static const border = Color(0xFFE5EBF2);

  // Legacy aliases (same spec values — no call-site churn).
  static const blue = royalBlue;
  static const dark = charcoal;
  static const bgWarm = Color(0xFFFFF7F1);

  // Supportive.
  static const red = Color(0xFFFF3D36);
  static const green = Color(0xFF16A34A);

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [orangeTop, orangeBottom],
  );

  static ColorScheme get scheme =>
      ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        secondary: royalBlue,
        tertiary: skyBlue,
        surface: Colors.white,
      );
}
