import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_scaffold.dart';
import 'notification_models.dart';
import 'notifications_providers.dart';
import 'portal_article_launcher.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(announcementsProvider);
    return PortalScaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(announcementsProvider.future),
        child: announcements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Không tải được thông báo',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(announcementsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? const _EmptyAnnouncements()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AnnouncementCard(announcement: items[index]),
                ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final PortalAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = announcement.publishDate?.toLocal();
    final dateLabel = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final detailUri = announcement.detailUri;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: detailUri != null,
        label: detailUri == null
            ? null
            : 'Xem thông báo: ${announcement.title}',
        child: InkWell(
          key: ValueKey('announcement-${announcement.id}'),
          onTap: detailUri == null
              ? null
              : () async {
                  try {
                    await openPortalArticle(detailUri);
                  } on PlatformException {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Không thể mở bài viết. Vui lòng thử lại.',
                        ),
                      ),
                    );
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateLabel != null || announcement.categories.isNotEmpty)
                  Text(
                    [
                      ...announcement.categories.take(1),
                      ?dateLabel,
                    ].join(' · '),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  announcement.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (announcement.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    announcement.excerpt,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (detailUri != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Xem chi tiết',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        Icon(Icons.notifications_none_outlined, size: 48),
        SizedBox(height: 12),
        Text('Chưa có thông báo', textAlign: TextAlign.center),
      ],
    );
  }
}
