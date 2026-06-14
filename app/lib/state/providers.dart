import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'persistence.dart';

/// Istanza di `SharedPreferences` già inizializzata. Sovrascritta in `main()` con quella
/// caricata all'avvio, così la lettura iniziale dello stato è sincrona.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider deve essere sovrascritto in main()'),
);

/// Servizio di persistenza del Game. Nei test si sovrascrive con [InMemoryGamePersistence].
final gamePersistenceProvider = Provider<GamePersistence>(
  (ref) => PrefsGamePersistence(ref.watch(sharedPreferencesProvider)),
);
