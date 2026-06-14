import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game.dart';
import '../../state/game_controller.dart';
import '../../theme/tokens.dart';

/// Avvio di un nuovo Game: scelta del numero di Seat (2–4) e della vita iniziale
/// (40 Commander di default, 20 per 1v1, oppure custom).
class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  int _seatCount = 4;
  int _startingLife = Game.commanderLife;
  final _customController = TextEditingController();

  static const _presets = {Game.commanderLife: 'Commander · 40', Game.duelLife: '1v1 · 20'};

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _start() {
    ref.read(gameControllerProvider.notifier).newGame(
          seatCount: _seatCount,
          startingLife: _startingLife,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('⚖️ manajudge')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Nuova partita', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tracker da tavolo — offline e sempre gratis.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxl),

            Text('Giocatori', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (var n = Game.minSeats; n <= Game.maxSeats; n++)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _seatCount == n,
                    onSelected: (_) => setState(() => _seatCount = n),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Vita iniziale', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in _presets.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _startingLife == entry.key && !_isCustom,
                    onSelected: (_) => setState(() {
                      _startingLife = entry.key;
                      _customController.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Vita personalizzata',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) setState(() => _startingLife = parsed);
              },
            ),

            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _start,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text('Inizia partita'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCustom => _customController.text.trim().isNotEmpty;
}
