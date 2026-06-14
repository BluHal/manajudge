import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/companion/companion_screen.dart';
import 'features/companion/new_game_screen.dart';
import 'state/game_controller.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ManajudgeApp(),
    ),
  );
}

/// Root dell'app manajudge. In Fase 1 ospita la **Companion** (offline); le superfici
/// Judge e Card Search si agganciano nelle fasi successive, sullo stesso design system.
class ManajudgeApp extends StatelessWidget {
  const ManajudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'manajudge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const CompanionHome(),
    );
  }
}

/// Mostra la schermata di nuovo Game se non c'è una partita attiva, altrimenti la Companion.
class CompanionHome extends ConsumerWidget {
  const CompanionHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasGame = ref.watch(gameControllerProvider) != null;
    return hasGame ? const CompanionScreen() : const NewGameScreen();
  }
}
