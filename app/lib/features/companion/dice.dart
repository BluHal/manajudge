import 'dart:math' as math;

/// Le facce del dado planare (Planechase): 1 Planeswalk, 1 Chaos, 4 vuote.
enum PlanarFace { planeswalk, chaos, blank }

/// Randomizzatori della Companion: dadi, moneta, dado planare, "chi inizia". [Random]
/// iniettabile per rendere i test deterministici.
class Dice {
  Dice([math.Random? rng]) : _rng = rng ?? math.Random();
  final math.Random _rng;

  int d20() => _rng.nextInt(20) + 1;
  int d6() => _rng.nextInt(6) + 1;

  /// true = testa, false = croce.
  bool coinHeads() => _rng.nextBool();

  PlanarFace planar() {
    switch (_rng.nextInt(6)) {
      case 0:
        return PlanarFace.planeswalk;
      case 1:
        return PlanarFace.chaos;
      default:
        return PlanarFace.blank;
    }
  }

  /// Indice casuale in [0, count): per scegliere chi inizia tra i Seat.
  int pickIndex(int count) => _rng.nextInt(count);
}
