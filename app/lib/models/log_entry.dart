/// Tipo di evento registrato nel Game log.
enum LogKind { gameStart, life, poison, commanderDamage, counter, counterAdd, counterRemove }

/// Una voce del **Game log**: la storia append-only dei cambi di vita/counter, per
/// risolvere "quant'era il mio totale un turno fa?". Locale al Game.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.kind,
    required this.seatLabel,
    this.delta = 0,
    this.resultingValue,
    this.detail,
  });

  final String id;
  final DateTime timestamp;
  final LogKind kind;

  /// Etichetta del Seat interessato, denormalizzata (robusta a rinomine successive).
  final String seatLabel;

  /// Variazione con segno (es. -2). 0 per eventi non numerici.
  final int delta;

  /// Valore risultante dopo l'evento (es. vita 38), quando ha senso.
  final int? resultingValue;

  /// Dettaglio extra: es. l'etichetta del counter, o il Seat sorgente del commander damage.
  final String? detail;

  /// Riga leggibile per il log.
  String describe() {
    final sign = delta > 0 ? '+$delta' : '$delta';
    switch (kind) {
      case LogKind.gameStart:
        return 'Inizio partita';
      case LogKind.life:
        return '$seatLabel: vita $sign → $resultingValue';
      case LogKind.poison:
        return '$seatLabel: veleno $sign → $resultingValue';
      case LogKind.commanderDamage:
        return '$seatLabel: commander damage da $detail $sign → $resultingValue';
      case LogKind.counter:
        return '$seatLabel: $detail $sign → $resultingValue';
      case LogKind.counterAdd:
        return '$seatLabel: nuovo counter "$detail"';
      case LogKind.counterRemove:
        return '$seatLabel: rimosso counter "$detail"';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'kind': kind.name,
        'seatLabel': seatLabel,
        'delta': delta,
        'resultingValue': resultingValue,
        'detail': detail,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        kind: LogKind.values.byName(json['kind'] as String),
        seatLabel: json['seatLabel'] as String,
        delta: (json['delta'] as int?) ?? 0,
        resultingValue: json['resultingValue'] as int?,
        detail: json['detail'] as String?,
      );
}
