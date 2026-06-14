import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_controller.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'dice.dart';

/// Bottom sheet con i randomizzatori: d20, d6, lancio moneta, dado planare e "chi inizia".
class DiceSheet extends ConsumerStatefulWidget {
  const DiceSheet({super.key});

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(context: context, builder: (_) => const DiceSheet());
  }

  @override
  ConsumerState<DiceSheet> createState() => _DiceSheetState();
}

class _DiceSheetState extends ConsumerState<DiceSheet> {
  final _dice = Dice();
  String _result = '—';
  String _resultLabel = 'Lancia un dado';

  void _set(String label, String value) => setState(() {
        _resultLabel = label;
        _result = value;
      });

  String _planarLabel(PlanarFace f) => switch (f) {
        PlanarFace.planeswalk => 'Planeswalk',
        PlanarFace.chaos => 'Chaos',
        PlanarFace.blank => 'Vuoto',
      };

  void _whoGoesFirst() {
    final game = ref.read(gameControllerProvider);
    if (game == null || game.seats.isEmpty) return;
    final seat = game.seats[_dice.pickIndex(game.seats.length)];
    _set('Inizia', seat.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_resultLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(_result, style: AppTypography.lifeNumberCompact),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _set('d20', '${_dice.d20()}'), child: const Text('d20')),
                OutlinedButton(onPressed: () => _set('d6', '${_dice.d6()}'), child: const Text('d6')),
                OutlinedButton(
                  onPressed: () => _set('Moneta', _dice.coinHeads() ? 'Testa' : 'Croce'),
                  child: const Text('Moneta'),
                ),
                OutlinedButton(
                  onPressed: () => _set('Dado planare', _planarLabel(_dice.planar())),
                  child: const Text('Planare'),
                ),
                FilledButton(onPressed: _whoGoesFirst, child: const Text('Chi inizia')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
