import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/seat.dart';
import '../../state/game_controller.dart';
import '../../theme/tokens.dart';
import 'dice_sheet.dart';
import 'game_log_sheet.dart';
import 'seat_detail_sheet.dart';
import 'seat_tile.dart';

/// La schermata principale della Companion: una griglia glanceable di Seat che riempie lo
/// schermo, con accesso a dadi, Game log e reset/nuova partita.
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    if (game == null) return const SizedBox.shrink();
    final seats = game.seats;
    final compact = seats.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: Text('Companion · ${seats.length}p'),
        actions: [
          IconButton(
            tooltip: 'Dadi e randomizzatori',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => DiceSheet.show(context, ref),
          ),
          IconButton(
            tooltip: 'Game log',
            icon: const Icon(Icons.history),
            onPressed: () => GameLogSheet.show(context, game.log),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'new') _confirmNewGame(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('Nuova partita…')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: _grid(context, ref, seats, compact),
        ),
      ),
    );
  }

  /// Dispone i Seat in righe da max 2, ognuna espansa, così riempiono lo schermo.
  Widget _grid(BuildContext context, WidgetRef ref, List<Seat> seats, bool compact) {
    final rows = <Widget>[];
    for (var i = 0; i < seats.length; i += 2) {
      final rowSeats = seats.skip(i).take(2).toList();
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (final seat in rowSeats)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: SeatTile(
                      seat: seat,
                      compact: compact,
                      onOpenDetail: () => SeatDetailSheet.show(context, ref, seat.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Future<void> _confirmNewGame(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuova partita?'),
        content: const Text('Lo stato attuale (vita, counter, log) verrà azzerato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nuova partita')),
        ],
      ),
    );
    if (ok == true) ref.read(gameControllerProvider.notifier).clearGame();
  }
}
