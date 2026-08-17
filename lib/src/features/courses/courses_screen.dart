import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'models/moodle_models.dart';
import 'providers/moodle_providers.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  String _searchQuery = '';

  void _showMoodleLoginDialog() {
    final usernameController = TextEditingController(text: '23520804');
    final passwordController = TextEditingController();
    var isLoggingIn = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.school_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Đăng nhập Moodle'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập tài khoản courses.uit.edu.vn để đồng bộ môn học và slide bài giảng:'),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'MSSV',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Moodle',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoggingIn ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: isLoggingIn
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      setDialogState(() => isLoggingIn = true);
                      final client = ref.read(moodleApiClientProvider);
                      final success = await client.login(
                        usernameController.text,
                        passwordController.text,
                      );
                      if (!mounted) return;
                      nav.pop();
                      if (success) {
                        ref.invalidate(moodleCoursesFutureProvider);
                        ref.invalidate(moodleDeadlinesFutureProvider);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đăng nhập Moodle thành công!')),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đăng nhập Moodle thất bại. Vui lòng kiểm tra lại mật khẩu.')),
                        );
                      }
                    },
              child: isLoggingIn
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(moodleCoursesFutureProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Moodle Courses & Tài liệu'),
        actions: [
          IconButton(
            tooltip: 'Đăng nhập lại Moodle',
            icon: const Icon(Icons.key_rounded),
            onPressed: _showMoodleLoginDialog,
          ),
          IconButton(
            tooltip: 'Làm mới danh sách môn học',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(moodleCoursesFutureProvider),
          ),
        ],
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(PortalSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: scheme.onSurfaceVariant),
                    const SizedBox(height: PortalSpacing.md),
                    Text(
                      'Chưa có môn học Moodle',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: PortalSpacing.xs),
                    Text(
                      'Phiên đăng nhập Moodle có thể chưa được kích hoạt.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: PortalSpacing.lg),
                    FilledButton.icon(
                      onPressed: _showMoodleLoginDialog,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Đăng nhập Moodle'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filtered = courses.where((c) {
            final query = _searchQuery.toLowerCase().trim();
            if (query.isEmpty) return true;
            return c.fullname.toLowerCase().contains(query) ||
                c.shortname.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PortalSpacing.md,
                  PortalSpacing.md,
                  PortalSpacing.md,
                  PortalSpacing.xs,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm môn học, mã lớp...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: PortalSpacing.md,
                      vertical: PortalSpacing.sm,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy môn học nào khớp với "$_searchQuery"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(PortalSpacing.md),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: PortalSpacing.sm),
                        itemBuilder: (context, index) {
                          final course = filtered[index];
                          return _CourseCard(course: course);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (err, _) => PortalAsyncState.error(
          title: 'Không thể tải Moodle Courses',
          message: 'Phiên Moodle có thể đã hết hạn hoặc máy chủ bận.',
          onRetry: () => ref.invalidate(moodleCoursesFutureProvider),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final MoodleCourse course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/moodle/course/${course.id}?name=${Uri.encodeComponent(course.fullname)}');
        },
        child: Padding(
          padding: const EdgeInsets.all(PortalSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: PortalSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.fullname,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.shortname,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (course.progress != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (course.progress! / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${course.progress}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: PortalSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
