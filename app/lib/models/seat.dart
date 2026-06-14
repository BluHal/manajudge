import 'dart:math' as math;
import '../theme/mana_color.dart';
import 'counter.dart';

/// Una posizione di gioco nel Game: la vita di quel giocatore, la sua colonna di commander
/// damage (quanto ha ricevuto da ciascun Seat sorgente), il veleno e i counter generici.
/// Ogni Seat ha un accento mana ([ManaColor]) distinto.
class Seat {
  const Seat({
    required this.id,
    required this.name,
    required this.manaColor,
    required this.life,
    this.commanderDamage = const {},
    this.poison = 0,
    this.counters = const [],
  });

  /// Soglie letali da regolamento.
  static const int poisonLethalThreshold = 10;
  static const int commanderLethalThreshold = 21;

  final String id;
  final String name;
  final ManaColor manaColor;
  final int life;

  /// Commander damage ricevuto, per Seat sorgente: { sourceSeatId: danno }.
  final Map<String, int> commanderDamage;
  final int poison;
  final List<GameCounter> counters;

  bool get poisonLethal => poison >= poisonLethalThreshold;

  /// Il massimo commander damage da una singola sorgente.
  int get maxCommanderDamage =>
      commanderDamage.values.fold(0, (mx, v) => math.max(mx, v));

  bool get commanderLethal => maxCommanderDamage >= commanderLethalThreshold;

  /// Eliminato: vita a 0, oppure veleno/commander damage letali.
  bool get isDead => life <= 0 || poisonLethal || commanderLethal;

  Seat copyWith({
    String? name,
    ManaColor? manaColor,
    int? life,
    Map<String, int>? commanderDamage,
    int? poison,
    List<GameCounter>? counters,
  }) =>
      Seat(
        id: id,
        name: name ?? this.name,
        manaColor: manaColor ?? this.manaColor,
        life: life ?? this.life,
        commanderDamage: commanderDamage ?? this.commanderDamage,
        poison: poison ?? this.poison,
        counters: counters ?? this.counters,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manaColor': manaColor.name,
        'life': life,
        'commanderDamage': commanderDamage,
        'poison': poison,
        'counters': counters.map((c) => c.toJson()).toList(),
      };

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
        id: json['id'] as String,
        name: json['name'] as String,
        manaColor: ManaColor.values.byName(json['manaColor'] as String),
        life: json['life'] as int,
        commanderDamage: (json['commanderDamage'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as int)),
        poison: (json['poison'] as int?) ?? 0,
        counters: (json['counters'] as List<dynamic>? ?? [])
            .map((c) => GameCounter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
