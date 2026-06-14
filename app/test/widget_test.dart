// Smoke test del flusso Companion: nuova partita -> schermata di gioco.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajudge/main.dart';
import 'package:manajudge/state/providers.dart';

void main() {
  testWidgets('Nuova partita avvia la Companion con i totali di vita', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ManajudgeApp(),
      ),
    );

    // Schermata di nuovo Game.
    expect(find.text('Nuova partita'), findsOneWidget);
    expect(find.text('Inizia partita'), findsOneWidget);

    // Avvia (default: 4 Seat, 40 vita) e vai alla Companion.
    await tester.tap(find.text('Inizia partita'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Companion'), findsOneWidget);
    expect(find.text('40'), findsWidgets);
  });
}
