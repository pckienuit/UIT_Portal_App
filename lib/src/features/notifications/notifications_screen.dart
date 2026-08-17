import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import 'models/personal_notification_item.dart';
import 'notification_models.dart';
import 'notifications_providers.dart';
import 'providers/personal_notification_providers.dart';
import 'portal_article_launcher.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personalNotifications = ref.watch(personalNotificationProvider);
    final announcements = ref.watch(announcementsProvider);
    final unreadPersonalCount =
        personalNotifications.where((n) => !n.isRead).length;

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Cá nhân'),
                  if (unreadPersonalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadPersonalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Trường học'),
          ],
        ),
        actions: [
          if (_tabController.index == 0 && personalNotifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'read_all') {
                  ref.read(personalNotificationProvider.notifier).markAllAsRead();
                } else if (val == 'clear_all') {
                  ref.read(personalNotificationProvider.notifier).clearAll();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'read_all',
                  child: Text('Đánh dấu tất cả đã đọc'),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Xóa tất cả thông báo'),
                ),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Thông báo Cá nhân & Biến động
          _PersonalNotificationsTab(items: personalNotifications),

          // Tab 2: Thông báo Chung từ Trường
          RefreshIndicator(
            onRefresh: () => ref.refresh(announcementsProvider.future),
            child: announcements.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
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
        ],
      ),
    );
  }
}

class _PersonalNotificationsTab extends ConsumerWidget {
  const _PersonalNotificationsTab({required this.items});

  final List<PersonalNotificationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Chưa có thông báo cá nhân nào',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Lịch học, điểm số, học phí và vé xe sẽ xuất hiện tại đây khi có cập nhật.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _PersonalNotificationCard(item: item);
      },
    );
  }
}

class _PersonalNotificationCard extends ConsumerWidget {
  const _PersonalNotificationCard({required this.item});

  final PersonalNotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iconData = _getTypeIcon(item.type);
    final tone = _getTypeTone(item.type);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isRead
              ? theme.dividerColor
              : theme.colorScheme.primary.withValues(alpha: 0.5),
          width: item.isRead ? 1 : 1.5,
        ),
      ),
      color: item.isRead
          ? theme.cardColor
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(personalNotificationProvider.notifier).markAsRead(item.id);
          if (item.targetRoute != null && item.targetRoute!.isNotEmpty) {
            context.push(item.targetRoute!);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getIconBgColor(theme, item.type),
                child: Icon(iconData, size: 20, color: _getIconColor(theme, item.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(item.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                        PortalStatusChip(
                          label: _getTypeLabel(item.type),
                          tone: tone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(PersonalNotificationType type) {
    switch (type) {
      case PersonalNotificationType.schedule:
        return Icons.calendar_today_rounded;
      case PersonalNotificationType.parking:
        return Icons.two_wheeler_rounded;
      case PersonalNotificationType.grades:
        return Icons.grade_rounded;
      case PersonalNotificationType.tuition:
        return Icons.account_balance_wallet_rounded;
      case PersonalNotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  String _getTypeLabel(PersonalNotificationType type) {
    switch (type) {
      case PersonalNotificationType.schedule:
        return 'Lịch học';
      case PersonalNotificationType.parking:
        return 'Gửi xe';
      case PersonalNotificationType.grades:
        return 'Điểm số';
      case PersonalNotificationType.tuition:
        return 'Học phí';
      case PersonalNotificationType.general:
        return 'Hệ thống';
    }
  }

  PortalStatusTone _getTypeTone(PersonalNotificationType type) {
    switch (type) {
      case PersonalNotificationType.schedule:
        return PortalStatusTone.info;
      case PersonalNotificationType.parking:
        return PortalStatusTone.warning;
      case PersonalNotificationType.grades:
        return PortalStatusTone.success;
      case PersonalNotificationType.tuition:
        return PortalStatusTone.neutral;
      case PersonalNotificationType.general:
        return PortalStatusTone.info;
    }
  }

  Color _getIconBgColor(ThemeData theme, PersonalNotificationType type) {
    switch (type) {
      case PersonalNotificationType.schedule:
        return Colors.blue.withValues(alpha: 0.15);
      case PersonalNotificationType.parking:
        return Colors.orange.withValues(alpha: 0.15);
      case PersonalNotificationType.grades:
        return Colors.green.withValues(alpha: 0.15);
      case PersonalNotificationType.tuition:
        return Colors.purple.withValues(alpha: 0.15);
      case PersonalNotificationType.general:
        return theme.colorScheme.primaryContainer;
    }
  }

  Color _getIconColor(ThemeData theme, PersonalNotificationType type) {
    switch (type) {
      case PersonalNotificationType.schedule:
        return Colors.blue[700]!;
      case PersonalNotificationType.parking:
        return Colors.orange[800]!;
      case PersonalNotificationType.grades:
        return Colors.green[700]!;
      case PersonalNotificationType.tuition:
        return Colors.purple[700]!;
      case PersonalNotificationType.general:
        return theme.colorScheme.primary;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
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
