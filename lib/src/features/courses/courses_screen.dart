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
  final _usernameController = TextEditingController(text: '23520804');
  final _passwordController = TextEditingController(text: '18092005');
  bool _isInlineLoggingIn = false;
  String? _inlineError;

  @override
  void dispose() {
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
      
      // Step 1: Login to Moodle server
      final success = await client.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Invalidate providers to trigger fresh fetch
        ref.invalidate(moodleCoursesFutureProvider);
        ref.invalidate(moodleDeadlinesFutureProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đồng bộ Moodle thành công!')),
        );
      } else {
        setState(() {
          _inlineError = 'Đăng nhập Moodle không thành công. Server từ chối phiên xác thực.';
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
                        Icon(Icons.school_rounded, size: 56, color: scheme.primary),
                        const SizedBox(height: PortalSpacing.sm),
                        Text(
                          'Đăng nhập Moodle Courses',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: PortalSpacing.xs),
                        Text(
                          'Kết nối courses.uit.edu.vn để tải slide bài giảng, xem hạn nộp bài tập và tài liệu học tập.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                              style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
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
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu Moodle',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: PortalSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isInlineLoggingIn ? null : _performMoodleLogin,
                            icon: _isInlineLoggingIn
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync_rounded),
                            label: Text(_isInlineLoggingIn ? 'Đang đồng bộ...' : 'Đồng bộ Moodle ngay'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
