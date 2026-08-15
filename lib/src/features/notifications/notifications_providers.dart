import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_client.dart';
import '../../data/portal_api_providers.dart';
import 'notification_models.dart';

class NotificationsRepository {
  const NotificationsRepository(this._client);

  final PortalApiClient _client;

  Future<List<PortalAnnouncement>> fetchAnnouncements() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/public/announcements',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PortalAnnouncement.fromJson)
        .toList(growable: false);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(portalApiClientProvider)),
);

final announcementsProvider = FutureProvider<List<PortalAnnouncement>>(
  (ref) => ref.watch(notificationsRepositoryProvider).fetchAnnouncements(),
);
