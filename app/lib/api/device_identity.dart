import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identità User anonima, device-scoped (ADR 0002): un token generato al primo avvio e
/// riusato sempre, così il Backend conta le AI Request contro lo stesso User. Astratta per
/// testabilità; in v1 è persistita in `shared_preferences` (lo swap a secure storage è una
/// migrazione successiva, lato public-readiness).
abstract interface class DeviceIdentity {
  /// Token stabile del device; generato e persistito al primo accesso.
  String token();
}

class PrefsDeviceIdentity implements DeviceIdentity {
  PrefsDeviceIdentity(this._prefs);

  static const _key = 'manajudge_device_token';
  final SharedPreferences _prefs;

  @override
  String token() {
    final existing = _prefs.getString(_key);
    if (existing != null) return existing;
    final fresh = const Uuid().v4();
    _prefs.setString(_key, fresh);
    return fresh;
  }
}

/// Identità fissa per i test.
class FakeDeviceIdentity implements DeviceIdentity {
  FakeDeviceIdentity([this._token = 'test-device']);
  final String _token;
  @override
  String token() => _token;
}
