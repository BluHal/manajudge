import 'package:flutter/material.dart';
import 'tokens.dart';

/// Scala tipografica manajudge. Sans moderno per tutto, con due stili speciali:
///  - [lifeNumber]: il numero-vita oversize della Companion, leggibile a tavola;
///  - [judgeBody]: il corpo "documento" del Judge, più editoriale/autorevole (serif).
abstract final class AppTypography {
  /// Numero-vita gigante. Cifre tabulari così non "balla" quando cambia.
  static const TextStyle lifeNumber = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.onSurface,
  );

  /// Variante più compatta del numero-vita (4 Seat, spazi stretti).
  static const TextStyle lifeNumberCompact = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.onSurface,
  );

  /// Corpo del Judge: serif, interlinea ariosa — feel da regolamento, non da chatbot.
  static const TextStyle judgeBody = TextStyle(
    fontFamily: 'serif',
    fontSize: 16,
    height: 1.5,
    color: AppColors.onSurface,
  );

  /// TextTheme di base (sans) montato nel [ThemeData].
  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.onSurface),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.onSurface),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted),
  );
}
