import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'portal_api_client.dart';

final portalApiClientProvider = Provider<PortalApiClient>((ref) {
  return PortalApiClient();
});
