import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajudge/models/log_entry.dart';
import 'package:manajudge/models/seat.dart';
import 'package:manajudge/state/game_controller.dart';
import 'package:manajudge/state/persistence.dart';
import 'package:manajudge/state/providers.dart';
import 'package:manajudge/theme/mana_color.dart';

ProviderContainer makeContainer([GamePersistence? persistence]) {
  final container = ProviderContainer(
    overrides: [
      gamePersistenceProvider.overrideWithValue(persistence ?? InMemoryGamePersistence()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('GameController', () {
    test('newGame crea N Seat con vita iniziale, accenti mana e log di inizio', () {
      final c = makeContainer();
      c.read(gameControllerProvider.notifier).newGame(seatCount: 4, startingLife: 40);

      final game = c.read(gameControllerProvider)!;
      expect(game.seats.length, 4);
      expect(game.seats.every((s) => s.life == 40), isTrue);
      expect(game.seats[0].manaColor, ManaColor.white);
      expect(game.seats[1].manaColor, ManaColor.blue);
      expect(game.log.first.kind, LogKind.gameStart);
    });

    test('clampa il numero di Seat a 2–4', () {
      final c = makeContainer();
      c.read(gameControllerProvider.notifier).newGame(seatCount: 9, startingLife: 20);
      expect(c.read(gameControllerProvider)!.seats.length, 4);
    });

    test('adjustLife applica tap (±1), long-press (±5) e swipe (±10) e logga', () {
      final c = makeContainer();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.newGame(seatCount: 2, startingLife: 40);
      final id = c.read(gameControllerProvider)!.seats[0].id;

      ctrl.adjustLife(id, -1);
      ctrl.adjustLife(id, -5);
      ctrl.adjustLife(id, 10);

      final game = c.read(gameControllerProvider)!;
      expect(game.seatById(id)!.life, 44); // 40 -1 -5 +10
      final last = game.log.last;
      expect(last.kind, LogKind.life);
      expect(last.delta, 10);
      expect(last.resultingValue, 44);
    });

    test('il veleno non scende sotto 0 ed è letale a 10', () {
      final c = makeContainer();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.newGame(seatCount: 2, startingLife: 40);
      final id = c.read(gameControllerProvider)!.seats[0].id;

      ctrl.adjustPoison(id, -1); // resta 0
      expect(c.read(gameControllerProvider)!.seatById(id)!.poison, 0);

      ctrl.adjustPoison(id, 10);
      final seat = c.read(gameControllerProvider)!.seatById(id)!;
      expect(seat.poison, 10);
      expect(seat.poisonLethal, isTrue);
    });

    test('commander damage è una matrice source→target, letale a 21, indipendente dalla vita', () {
      final c = makeContainer();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.newGame(seatCount: 3, startingLife: 40);
      final seats = c.read(gameControllerProvider)!.seats;
      final target = seats[0].id;
      final source = seats[1].id;

      for (var i = 0; i < 21; i++) {
        ctrl.adjustCommanderDamage(targetSeatId: target, sourceSeatId: source, delta: 1);
      }
      final t = c.read(gameControllerProvider)!.seatById(target)!;
      expect(t.commanderDamage[source], 21);
      expect(t.commanderLethal, isTrue);
      expect(t.life, 40); // tracker indipendente dalla vita
      expect(t.maxCommanderDamage, 21);
    });

    test('counter generici: add / adjust / remove', () {
      final c = makeContainer();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.newGame(seatCount: 2, startingLife: 40);
      final id = c.read(gameControllerProvider)!.seats[0].id;

      ctrl.addCounter(id, 'Energia');
      final cid = c.read(gameControllerProvider)!.seatById(id)!.counters.single.id;
      ctrl.adjustCounter(id, cid, 3);
      expect(c.read(gameControllerProvider)!.seatById(id)!.counters.single.value, 3);

      ctrl.removeCounter(id, cid);
      expect(c.read(gameControllerProvider)!.seatById(id)!.counters, isEmpty);
    });

    test('clearGame azzera lo stato', () {
      final c = makeContainer();
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.newGame(seatCount: 2, startingLife: 20);
      ctrl.clearGame();
      expect(c.read(gameControllerProvider), isNull);
    });

    test('lo stato persiste e si ricarica al riavvio (nuovo container)', () {
      final persistence = InMemoryGamePersistence();
      final c1 = makeContainer(persistence);
      c1.read(gameControllerProvider.notifier).newGame(seatCount: 2, startingLife: 20);

      final c2 = ProviderContainer(
        overrides: [gamePersistenceProvider.overrideWithValue(persistence)],
      );
      addTearDown(c2.dispose);
      final restored = c2.read(gameControllerProvider);
      expect(restored, isNotNull);
      expect(restored!.seats.length, 2);
      expect(restored.startingLife, 20);
    });
  });

  test('Seat: soglie letali', () {
    const base = Seat(id: 'x', name: 'P', manaColor: ManaColor.red, life: 40);
    expect(base.copyWith(poison: 10).poisonLethal, isTrue);
    expect(base.copyWith(commanderDamage: {'s': 21}).commanderLethal, isTrue);
    expect(base.copyWith(life: 0).isDead, isTrue);
  });
}
