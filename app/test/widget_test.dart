// Smoke test della shell a tre superfici e del flusso Companion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajudge/main.dart';
import 'package:manajudge/state/providers.dart';

void main() {
  testWidgets('Companion: nuova partita avvia i totali di vita', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ManajudgeApp(),
      ),
    );

    // Tab Companion (default): schermata di nuovo Game.
    expect(find.text('Inizia partita'), findsOneWidget);
    await tester.tap(find.text('Inizia partita'));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsWidgets); // i totali di vita dei Seat
  });

  testWidgets('Navigazione tra Companion, Judge e Card Search', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ManajudgeApp(),
      ),
    );

    // -> Judge (stato vuoto, nessuna chiamata di rete).
    await tester.tap(find.byIcon(Icons.balance_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chiedi una regola'), findsOneWidget);

    // -> Card Search (hint iniziale).
    await tester.tap(find.byIcon(Icons.search_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cerca carte per effetto'), findsOneWidget);
  });
}
