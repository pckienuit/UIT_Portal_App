import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'models/moodle_models.dart';
import 'providers/moodle_providers.dart';

const _urlChannel = MethodChannel('com.pckienuit.uitportal/external_url');

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _usernameController = TextEditingController(text: '23520804');
  final _passwordController = TextEditingController(text: '18092005');
  bool _isInlineLoggingIn = false;
  String? _inlineError;
  bool _obscureMoodlePassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performMoodleLogin() async {
    setState(() {
      _isInlineLoggingIn = true;
      _inlineError = null;
    });

    try {
      final client = ref.read(moodleApiClientProvider);

      final success = await client.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        ref.invalidate(moodleAllDeadlinesFutureProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đồng bộ Moodle thành công!')),
        );
      } else {
        setState(() {
          _inlineError = client.lastErrorDetails ??
              'Đăng nhập Moodle không thành công. Server từ chối phiên xác thực.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'Lỗi kết nối: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isInlineLoggingIn = false);
      }
    }
  }

  static Future<void> _openExternalUrl(String url) async {
    try {
      await _urlChannel.invokeMethod('openWebBrowser', {'url': url});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final deadlinesAsync = ref.watch(moodleAllDeadlinesFutureProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Hạn nộp bài tập Moodle'),
        actions: [
          IconButton(
            tooltip: 'Mở trang web Moodle',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () {
              _openExternalUrl('https://courses.uit.edu.vn/calendar/view.php');
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(moodleAllDeadlinesFutureProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          labelPadding: EdgeInsets.zero,
          tabs: [
            Tab(
              child: deadlinesAsync.maybeWhen(
                data: (all) {
                  final count = all.where((d) => d.status == DeadlineStatus.upcoming).length;
                  return _TabWithBadge(label: 'Chưa tới hạn', count: count, color: Colors.teal);
                },
                orElse: () => const Text('Chưa tới hạn', style: TextStyle(fontSize: 12)),
              ),
            ),
            Tab(
              child: deadlinesAsync.maybeWhen(
                data: (all) {
                  final count = all.where((d) => d.status == DeadlineStatus.overdue).length;
                  return _TabWithBadge(label: 'Đã quá hạn', count: count, color: Colors.red);
                },
                orElse: () => const Text('Đã quá hạn', style: TextStyle(fontSize: 12)),
              ),
            ),
            Tab(
              child: deadlinesAsync.maybeWhen(
                data: (all) {
                  final count = all.where((d) => d.status == DeadlineStatus.completed).length;
                  return _TabWithBadge(label: 'Đã hoàn thành', count: count, color: Colors.green);
                },
                orElse: () => const Text('Đã hoàn thành', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
      body: deadlinesAsync.when(
        data: (allDeadlines) {
          final client = ref.read(moodleApiClientProvider);
          if (!client.isAuthenticated && allDeadlines.isEmpty) {
            return _buildLoginPrompt(theme, scheme);
          }

          final upcoming = allDeadlines
              .where((d) => d.status == DeadlineStatus.upcoming)
              .toList()
            ..sort((a, b) => a.deadlineTime.compareTo(b.deadlineTime));

          final overdue = allDeadlines
              .where((d) => d.status == DeadlineStatus.overdue)
              .toList()
            ..sort((a, b) => b.deadlineTime.compareTo(a.deadlineTime));

          final completed = allDeadlines
              .where((d) => d.status == DeadlineStatus.completed)
              .toList()
            ..sort((a, b) => b.deadlineTime.compareTo(a.deadlineTime));

          return Column(
            children: [
              // Thống kê tổng quan nhanh (Overview Metrics Strip)
              Container(
                margin: const EdgeInsets.fromLTRB(
                  PortalSpacing.md,
                  PortalSpacing.sm,
                  PortalSpacing.md,
                  PortalSpacing.xs,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: PortalSpacing.md,
                  vertical: PortalSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricItem(
                      label: 'Sắp tới hạn',
                      count: upcoming.length,
                      color: Colors.teal,
                      icon: Icons.schedule_rounded,
                    ),
                    Container(height: 24, width: 1, color: theme.dividerColor),
                    _MetricItem(
                      label: 'Quá hạn',
                      count: overdue.length,
                      color: Colors.red,
                      icon: Icons.error_outline_rounded,
                    ),
                    Container(height: 24, width: 1, color: theme.dividerColor),
                    _MetricItem(
                      label: 'Đã nộp',
                      count: completed.length,
                      color: Colors.green,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DeadlineListView(
                      deadlines: upcoming,
                      emptyTitle: 'Tuyệt vời!',
                      emptyMessage: 'Không có bài tập nào sắp tới hạn.',
                      emptyIcon: Icons.task_alt_rounded,
                      onOpenUrl: _openExternalUrl,
                    ),
                    _DeadlineListView(
                      deadlines: overdue,
                      emptyTitle: 'Không có bài tập quá hạn',
                      emptyMessage: 'Bạn không có bài tập nào bị trễ hạn.',
                      emptyIcon: Icons.sentiment_satisfied_alt_rounded,
                      onOpenUrl: _openExternalUrl,
                    ),
                    _DeadlineListView(
                      deadlines: completed,
                      emptyTitle: 'Chưa có bài tập hoàn thành',
                      emptyMessage: 'Các bài tập đã nộp sẽ hiển thị tại đây.',
                      emptyIcon: Icons.assignment_turned_in_outlined,
                      onOpenUrl: _openExternalUrl,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (err, _) => PortalAsyncState.error(
          title: 'Không thể tải Hạn nộp bài tập',
          message: 'Phiên Moodle có thể đã hết hạn hoặc máy chủ bận.',
          onRetry: () => ref.invalidate(moodleAllDeadlinesFutureProvider),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.lg),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PortalSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: PortalSpacing.sm),
                Text(
                  'Đăng nhập Moodle Deadlines',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: PortalSpacing.xs),
                Text(
                  'Kết nối courses.uit.edu.vn để tự động theo dõi hạn nộp bài tập và nhắc nhở deadline.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: PortalSpacing.md),
                if (_inlineError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _inlineError!,
                      style: TextStyle(
                          color: scheme.onErrorContainer, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: PortalSpacing.sm),
                ],
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'MSSV',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: PortalSpacing.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureMoodlePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu Moodle',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureMoodlePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureMoodlePassword = !_obscureMoodlePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: PortalSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isInlineLoggingIn ? null : _performMoodleLogin,
                    icon: _isInlineLoggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_isInlineLoggingIn
                        ? 'Đang đồng bộ...'
                        : 'Đồng bộ Moodle ngay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        Text(
          '$count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _DeadlineListView extends StatelessWidget {
  const _DeadlineListView({
    required this.deadlines,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onOpenUrl,
  });

  final List<MoodleDeadline> deadlines;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(String url) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (deadlines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PortalSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 64, color: scheme.primary.withValues(alpha: 0.6)),
              const SizedBox(height: PortalSpacing.md),
              Text(
                emptyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: PortalSpacing.xs),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PortalSpacing.md),
      itemCount: deadlines.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: PortalSpacing.sm),
      itemBuilder: (context, index) {
        final deadline = deadlines[index];
        return _DeadlineFullCard(
          deadline: deadline,
          onTap: () {
            if (deadline.actionUrl != null && deadline.actionUrl!.isNotEmpty) {
              onOpenUrl(deadline.actionUrl!);
            }
          },
        );
      },
    );
  }
}

class _DeadlineFullCard extends StatelessWidget {
  const _DeadlineFullCard({
    required this.deadline,
    required this.onTap,
  });

  final MoodleDeadline deadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('HH:mm - dd/MM/yyyy');
    final timeStr = dateFormat.format(deadline.deadlineTime);

    final (badgeColor, statusLabel, badgeIcon) = switch (deadline.status) {
      DeadlineStatus.upcoming => (
          Colors.teal,
          _calculateRemaining(deadline.deadlineTime),
          Icons.schedule_rounded,
        ),
      DeadlineStatus.overdue => (
          Colors.red,
          'Đã quá hạn',
          Icons.error_outline_rounded,
        ),
      DeadlineStatus.completed => (
          Colors.green,
          'Đã nộp bài',
          Icons.check_circle_outline_rounded,
        ),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: deadline.isCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PortalSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.open_in_new_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: PortalSpacing.sm),
              Text(
                deadline.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deadline.courseName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: PortalSpacing.xs),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'Còn ${diff.inDays} ngày';
    } else if (diff.inHours > 0) {
      return 'Còn ${diff.inHours} giờ';
    } else if (diff.inMinutes > 0) {
      return 'Còn ${diff.inMinutes} phút';
    }
    return 'Hết hạn hôm nay!';
  }
}
