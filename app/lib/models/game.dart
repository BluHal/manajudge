import 'log_entry.dart';
import 'seat.dart';

/// Una sessione di gioco tracciata dalla Companion: 2–4 Seat, un totale di vita iniziale e
/// un Game log in corso. Single-device in v1 (un telefono traccia tutti). Tutto locale.
class Game {
  const Game({
    required this.id,
    required this.createdAt,
    required this.startingLife,
    required this.seats,
    this.log = const [],
  });

  /// Vita iniziale di default (Commander). 1v1/constructed usa 20.
  static const int commanderLife = 40;
  static const int duelLife = 20;
  static const int minSeats = 2;
  static const int maxSeats = 4;

  final String id;
  final DateTime createdAt;
  final int startingLife;
  final List<Seat> seats;
  final List<LogEntry> log;

  Seat? seatById(String seatId) {
    for (final s in seats) {
      if (s.id == seatId) return s;
    }
    return null;
  }

  Game copyWith({List<Seat>? seats, List<LogEntry>? log}) => Game(
        id: id,
        createdAt: createdAt,
        startingLife: startingLife,
        seats: seats ?? this.seats,
        log: log ?? this.log,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'startingLife': startingLife,
        'seats': seats.map((s) => s.toJson()).toList(),
        'log': log.map((e) => e.toJson()).toList(),
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        startingLife: json['startingLife'] as int,
        seats: (json['seats'] as List<dynamic>)
            .map((s) => Seat.fromJson(s as Map<String, dynamic>))
            .toList(),
        log: (json['log'] as List<dynamic>? ?? [])
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
