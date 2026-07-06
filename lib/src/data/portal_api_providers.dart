import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import 'portal_api_client.dart';

final portalApiClientProvider = Provider<PortalApiClient>((ref) {
  final auth = ref.watch(authControllerProvider);

  return PortalApiClient(
    accessTokenProvider: () => auth.session?.accessToken,
    onSessionExpired: () {
      ref.read(authControllerProvider).signOut();
    },
  );
});
