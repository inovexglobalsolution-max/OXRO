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

  // Home reference palette (teal header, maroon promo, gold ornament).
  static const teal = Color(0xFF1FA0B3);
  static const tealDeep = Color(0xFF0D879C);
  static const tealInk = Color(0xFF075F70);
  static const maroon = Color(0xFF7A1238);
  static const maroonDeep = Color(0xFF59051C);
  static const gold = Color(0xFFD9A84E);
  static const goldSoft = Color(0xFFF1D79A);
  static const cream = Color(0xFFFFF8EE);
  static const homeBg = Color(0xFFF7F7F7);
  static const coral = Color(0xFFFF5A5F);

  // OXRO PREMIUM — burgundy + cream membership palette.
  static const premiumDeep = Color(0xFF2A0714);
  static const premiumBurgundy = Color(0xFF4A0E24);
  static const premiumWine = Color(0xFF6B1535);
  static const premiumCream = Color(0xFFFFF7EC);
  static const premiumCreamDeep = Color(0xFFF1E3D2);
  static const premiumInk = Color(0xFF3B0A1D);
  static const premiumMuted = Color(0xFF7A5A64);
  static const premiumRose = Color(0xFFC65C7A);
  static const premiumChampagne = Color(0xFFE6C79C);

  // Supportive.
  static const red = Color(0xFFFF3D36);
  static const green = Color(0xFF16A34A);

  // Food semantics.
  static const ratingGreen = Color(0xFF16A34A);
  static const ratingAmber = Color(0xFFDB7C38);
  static const ratingRed = Color(0xFFE84A4A);
  static const vegGreen = Color(0xFF16A34A);
  static const nonVegRed = Color(0xFFE84A4A);
  static const eggAmber = Color(0xFFCB6602);
  static const surface = pageBg;
  static const divider = border;
  static const textPrimary = charcoal;
  static const textSecondary = muted;
  static const offerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF6A00), Color(0xFFFF8A3D)],
  );

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
