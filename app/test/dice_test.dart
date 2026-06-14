import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajudge/features/companion/dice.dart';

void main() {
  test('d20 e d6 restano nei range', () {
    final dice = Dice(Random(42));
    for (var i = 0; i < 200; i++) {
      expect(dice.d20(), inInclusiveRange(1, 20));
      expect(dice.d6(), inInclusiveRange(1, 6));
    }
  });

  test('il dado planare è vuoto nei 4/6 dei casi', () {
    final dice = Dice(Random(1));
    final counts = <PlanarFace, int>{};
    for (var i = 0; i < 6000; i++) {
      counts.update(dice.planar(), (v) => v + 1, ifAbsent: () => 1);
    }
    expect(counts[PlanarFace.blank]!, greaterThan(counts[PlanarFace.planeswalk]!));
    expect(counts[PlanarFace.blank]!, greaterThan(counts[PlanarFace.chaos]!));
  });

  test('pickIndex resta entro il numero di Seat', () {
    final dice = Dice(Random(7));
    for (var i = 0; i < 100; i++) {
      expect(dice.pickIndex(4), inInclusiveRange(0, 3));
    }
  });
}
