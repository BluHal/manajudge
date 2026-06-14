import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../state/providers.dart';
import 'api_client.dart';
import 'device_identity.dart';

/// Identità User anonima, persistita su `shared_preferences`.
final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => PrefsDeviceIdentity(ref.watch(sharedPreferencesProvider)),
);

/// Client verso le superfici AI del Backend, con base URL configurabile e identità anonima.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    identity: ref.watch(deviceIdentityProvider),
  );
  ref.onDispose(client.close);
  return client;
});
