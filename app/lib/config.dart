/// Configurazione dell'app. Il base URL del Backend è iniettabile a build time:
///   flutter run --dart-define=MANAJUDGE_API_URL=https://api.tuodominio.tld
/// Default: backend locale in dev (`npm run dev`). Su device fisico serve l'IP della LAN o
/// l'URL del deploy (Oracle), non `localhost`.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'MANAJUDGE_API_URL',
    defaultValue: 'http://localhost:5173',
  );
}
