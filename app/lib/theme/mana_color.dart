import 'package:flutter/material.dart';

/// I cinque colori di Magic (WUBRG). Nel design system sono il sistema di **accenti**:
/// ogni Seat della Companion ne riceve uno come identità visiva. Non sono la palette di
/// base (quella è neutra/dark): i colori mana punteggiano, non dominano.
enum ManaColor {
  white('W', 'Bianco', Color(0xFFEAD9A0)),
  blue('U', 'Blu', Color(0xFF4AA3E0)),
  black('B', 'Nero', Color(0xFF9D7CD8)),
  red('R', 'Rosso', Color(0xFFE5575C)),
  green('G', 'Verde', Color(0xFF4FB477));

  const ManaColor(this.symbol, this.label, this.accent);

  /// Simbolo a una lettera (WUBRG).
  final String symbol;

  /// Etichetta leggibile.
  final String label;

  /// Colore d'accento, scelto per buon contrasto su base dark.
  final Color accent;

  /// Variante tenue dell'accento, per fondi/superfici dei Seat.
  Color get surface => accent.withValues(alpha: 0.14);

  /// Assegna i colori ai Seat in ordine WUBRG (fino a 5 Seat).
  static ManaColor forSeat(int index) => values[index % values.length];
}
