import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/counter.dart';
import '../models/game.dart';
import '../models/log_entry.dart';
import '../models/seat.dart';
import '../theme/mana_color.dart';
import 'persistence.dart';
import 'providers.dart';

const _uuid = Uuid();

/// Stato e mutazioni della Companion: un Game attivo (o `null` se nessuno). Ogni mutazione
/// aggiorna lo stato, lo persiste e appende una voce al Game log. Tutto locale, offline.
class GameController extends Notifier<Game?> {
  GamePersistence get _persistence => ref.read(gamePersistenceProvider);

  @override
  Game? build() => _persistence.load();

  // --- ciclo di vita del Game ---

  /// Crea un nuovo Game con [seatCount] Seat (2–4) e una vita iniziale.
  void newGame({required int seatCount, required int startingLife, List<String>? names}) {
    final count = seatCount.clamp(Game.minSeats, Game.maxSeats);
    final seats = [
      for (var i = 0; i < count; i++)
        Seat(
          id: _uuid.v4(),
          name: (names != null && i < names.length && names[i].trim().isNotEmpty)
              ? names[i].trim()
              : 'Seat ${i + 1}',
          manaColor: ManaColor.forSeat(i),
          life: startingLife,
        ),
    ];
    _set(Game(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      startingLife: startingLife,
      seats: seats,
      log: [_entry(kind: LogKind.gameStart, seatLabel: '')],
    ));
  }

  /// Azzera lo stato: nessun Game attivo (l'UI torna alla schermata di nuovo Game).
  void clearGame() {
    state = null;
    _persistence.save(null);
  }

  // --- mutazioni per-Seat ---

  void adjustLife(String seatId, int delta) => _mutateSeat(
        seatId,
        (s) => s.copyWith(life: s.life + delta),
        (old, now) => _entry(
          kind: LogKind.life,
          seatLabel: now.name,
          delta: now.life - old.life,
          resultingValue: now.life,
        ),
      );

  void adjustPoison(String seatId, int delta) => _mutateSeat(
        seatId,
        (s) => s.copyWith(poison: math.max(0, s.poison + delta)),
        (old, now) => _entry(
          kind: LogKind.poison,
          seatLabel: now.name,
          delta: now.poison - old.poison,
          resultingValue: now.poison,
        ),
      );

  /// Imposta il commander damage da [sourceSeatId] verso [targetSeatId]. È un tracker
  /// indipendente dalla vita (la vita si regola a parte). 21 da una sorgente = letale.
  void adjustCommanderDamage({
    required String targetSeatId,
    required String sourceSeatId,
    required int delta,
  }) {
    final sourceName = state?.seatById(sourceSeatId)?.name ?? '?';
    _mutateSeat(
      targetSeatId,
      (s) {
        final current = s.commanderDamage[sourceSeatId] ?? 0;
        return s.copyWith(
          commanderDamage: {...s.commanderDamage, sourceSeatId: math.max(0, current + delta)},
        );
      },
      (old, now) => _entry(
        kind: LogKind.commanderDamage,
        seatLabel: now.name,
        delta: (now.commanderDamage[sourceSeatId] ?? 0) - (old.commanderDamage[sourceSeatId] ?? 0),
        resultingValue: now.commanderDamage[sourceSeatId] ?? 0,
        detail: sourceName,
      ),
    );
  }

  // --- counter generici ---

  void addCounter(String seatId, String label) => _mutateSeat(
        seatId,
        (s) => s.copyWith(
          counters: [...s.counters, GameCounter(id: _uuid.v4(), label: label.trim())],
        ),
        (old, now) => _entry(kind: LogKind.counterAdd, seatLabel: now.name, detail: label.trim()),
      );

  void adjustCounter(String seatId, String counterId, int delta) => _mutateSeat(
        seatId,
        (s) => s.copyWith(
          counters: [
            for (final c in s.counters)
              if (c.id == counterId) c.copyWith(value: c.value + delta) else c,
          ],
        ),
        (old, now) {
          final c = now.counters.firstWhere((c) => c.id == counterId);
          return _entry(
            kind: LogKind.counter,
            seatLabel: now.name,
            delta: delta,
            resultingValue: c.value,
            detail: c.label,
          );
        },
      );

  void removeCounter(String seatId, String counterId) {
    final game = state;
    if (game == null) return;
    final seat = game.seatById(seatId);
    GameCounter? removed;
    for (final c in seat?.counters ?? const <GameCounter>[]) {
      if (c.id == counterId) removed = c;
    }
    _mutateSeat(
      seatId,
      (s) => s.copyWith(counters: [...s.counters.where((c) => c.id != counterId)]),
      (old, now) => _entry(
        kind: LogKind.counterRemove,
        seatLabel: now.name,
        detail: removed?.label ?? '',
      ),
    );
  }

  void renameSeat(String seatId, String name) => _mutateSeatSilent(
        seatId,
        (s) => s.copyWith(name: name.trim().isEmpty ? s.name : name.trim()),
      );

  // --- helper interni ---

  void _mutateSeat(
    String seatId,
    Seat Function(Seat) update,
    LogEntry Function(Seat old, Seat updated) logFor,
  ) {
    final game = state;
    if (game == null) return;
    final old = game.seatById(seatId);
    if (old == null) return;
    final updated = update(old);
    final seats = [for (final s in game.seats) if (s.id == seatId) updated else s];
    _set(game.copyWith(seats: seats, log: [...game.log, logFor(old, updated)]));
  }

  void _mutateSeatSilent(String seatId, Seat Function(Seat) update) {
    final game = state;
    if (game == null) return;
    final seats = [for (final s in game.seats) if (s.id == seatId) update(s) else s];
    _set(game.copyWith(seats: seats));
  }

  LogEntry _entry({
    required LogKind kind,
    required String seatLabel,
    int delta = 0,
    int? resultingValue,
    String? detail,
  }) =>
      LogEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        kind: kind,
        seatLabel: seatLabel,
        delta: delta,
        resultingValue: resultingValue,
        detail: detail,
      );

  void _set(Game game) {
    state = game;
    _persistence.save(game);
  }
}

/// Provider del Game attivo (o null).
final gameControllerProvider =
    NotifierProvider<GameController, Game?>(GameController.new);
