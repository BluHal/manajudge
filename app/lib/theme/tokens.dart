import 'package:flutter/material.dart';

/// Token di base del design system manajudge: ramp dark neutra, colori semantici, spazi e
/// raggi. Dark by default, alto contrasto, poco chrome — pensato per un tavolo in penombra
/// e per il gioco notturno. I colori mana ([ManaColor]) sono accenti a parte.
abstract final class AppColors {
  // Ramp dark neutra (dal più profondo alla superficie più chiara).
  static const Color bg = Color(0xFF0D0E12);
  static const Color surface = Color(0xFF15171C);
  static const Color surfaceVariant = Color(0xFF1E2128);
  static const Color surfaceHigh = Color(0xFF272B33);
  static const Color outline = Color(0xFF333842);

  // Testo.
  static const Color onSurface = Color(0xFFE7E9EE);
  static const Color onSurfaceMuted = Color(0xFF9BA1AC);

  // Semantici.
  static const Color lethal = Color(0xFFE5484D); // pericolo / letale (21 cmd dmg, 10 poison)
  static const Color warning = Color(0xFFF5A623);
  static const Color success = Color(0xFF45B16A);

  // Brand: la "g" di judge — viola autorevole, usato con parsimonia.
  static const Color brand = Color(0xFF8B72E0);
}

/// Spaziature di base (multipli di 4).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Raggi di arrotondamento.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double pill = 999;
}
