import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';

/// Persistenza locale del Game attivo. La Companion è offline: lo stato sopravvive al
/// riavvio dell'app e si azzera solo su scelta (nuovo Game). Astratta per testabilità.
abstract interface class GamePersistence {
  Game? load();
  void save(Game? game);
}

/// Implementazione su `shared_preferences`: serializza il Game attivo come JSON.
class PrefsGamePersistence implements GamePersistence {
  PrefsGamePersistence(this._prefs);

  static const _key = 'manajudge_active_game';
  final SharedPreferences _prefs;

  @override
  Game? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Game.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Stato corrotto/incompatibile: meglio ripartire puliti che crashare a tavola.
      return null;
    }
  }

  @override
  void save(Game? game) {
    if (game == null) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, jsonEncode(game.toJson()));
    }
  }
}

/// Persistenza in memoria, per i test.
class InMemoryGamePersistence implements GamePersistence {
  InMemoryGamePersistence([this._game]);
  Game? _game;

  @override
  Game? load() => _game;

  @override
  void save(Game? game) => _game = game;
}
