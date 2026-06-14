import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_controller.dart';
import 'companion_screen.dart';
import 'new_game_screen.dart';

/// Tab Companion: mostra la schermata di nuovo Game se non c'è una partita attiva,
/// altrimenti il tracker.
class CompanionHome extends ConsumerWidget {
  const CompanionHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasGame = ref.watch(gameControllerProvider) != null;
    return hasGame ? const CompanionScreen() : const NewGameScreen();
  }
}
