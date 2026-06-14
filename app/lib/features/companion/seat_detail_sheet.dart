import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/seat.dart';
import '../../state/game_controller.dart';
import '../../theme/tokens.dart';

/// Bottom sheet con i tracker di un Seat: la colonna commander damage (quanto ha ricevuto da
/// ciascun altro Seat, 21 = letale), il veleno (10 = letale) e i counter generici.
class SeatDetailSheet extends ConsumerWidget {
  const SeatDetailSheet({super.key, required this.seatId});

  final String seatId;

  static void show(BuildContext context, WidgetRef ref, String seatId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SeatDetailSheet(seatId: seatId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final seat = game?.seatById(seatId);
    if (game == null || seat == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final others = game.seats.where((s) => s.id != seatId).toList();
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircleAvatar(radius: 10, backgroundColor: seat.manaColor.accent, child: Text(
                seat.manaColor.symbol,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
              )),
              const SizedBox(width: AppSpacing.sm),
              Text(seat.name, style: theme.textTheme.titleLarge),
            ]),
            const SizedBox(height: AppSpacing.lg),

            _sectionTitle(theme, 'Commander damage'),
            if (others.isEmpty)
              Text('Nessun altro Seat.', style: theme.textTheme.bodySmall)
            else
              for (final src in others)
                _stepperRow(
                  leading: _seatBadge(src),
                  value: seat.commanderDamage[src.id] ?? 0,
                  lethal: (seat.commanderDamage[src.id] ?? 0) >= Seat.commanderLethalThreshold,
                  onMinus: () => controller.adjustCommanderDamage(targetSeatId: seatId, sourceSeatId: src.id, delta: -1),
                  onPlus: () => controller.adjustCommanderDamage(targetSeatId: seatId, sourceSeatId: src.id, delta: 1),
                ),

            const SizedBox(height: AppSpacing.lg),
            _sectionTitle(theme, 'Veleno'),
            _stepperRow(
              leading: const Text('☠  Poison'),
              value: seat.poison,
              lethal: seat.poisonLethal,
              onMinus: () => controller.adjustPoison(seatId, -1),
              onPlus: () => controller.adjustPoison(seatId, 1),
            ),

            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(theme, 'Counter'),
                TextButton.icon(
                  onPressed: () => _addCounter(context, controller),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
            if (seat.counters.isEmpty)
              Text('Nessun counter.', style: theme.textTheme.bodySmall)
            else
              for (final c in seat.counters)
                _stepperRow(
                  leading: Text(c.label),
                  value: c.value,
                  lethal: false,
                  onMinus: () => controller.adjustCounter(seatId, c.id, -1),
                  onPlus: () => controller.adjustCounter(seatId, c.id, 1),
                  onRemove: () => controller.removeCounter(seatId, c.id),
                ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: theme.textTheme.titleMedium),
      );

  Widget _seatBadge(Seat s) => Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 8, backgroundColor: s.manaColor.accent, child: Text(
          s.manaColor.symbol,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black87),
        )),
        const SizedBox(width: AppSpacing.sm),
        Text('da ${s.name}'),
      ]);

  Widget _stepperRow({
    required Widget leading,
    required int value,
    required bool lethal,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: DefaultTextStyle.merge(
            style: TextStyle(color: lethal ? AppColors.lethal : AppColors.onSurface, fontWeight: FontWeight.w600),
            child: leading,
          )),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(
            width: 34,
            child: Text('$value', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: lethal ? AppColors.lethal : AppColors.onSurface)),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
          if (onRemove != null)
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close), tooltip: 'Rimuovi'),
        ],
      ),
    );
  }

  Future<void> _addCounter(BuildContext context, GameController controller) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuovo counter'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Es. Energia, Esperienza, Tesori'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Crea')),
        ],
      ),
    );
    if (label != null && label.isNotEmpty) controller.addCounter(seatId, label);
  }
}
