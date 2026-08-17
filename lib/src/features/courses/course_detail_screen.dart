import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'models/moodle_models.dart';
import 'providers/moodle_providers.dart';

const _urlChannel = MethodChannel('com.pckienuit.uitportal/external_url');

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final int courseId;
  final String courseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      moodleCourseDetailFutureProvider((courseId: courseId, courseName: courseName)),
    );

    return PortalScaffold(
      appBar: AppBar(
        title: Text(
          courseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Mở trên web Moodle',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () {
              _openExternalUrl('https://courses.uit.edu.vn/course/view.php?id=$courseId');
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(
              moodleCourseDetailFutureProvider((courseId: courseId, courseName: courseName)),
            ),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail.activities.isEmpty) {
            return const PortalAsyncState.empty(
              title: 'Chưa có hoạt động nào',
              message: 'Khóa học này chưa đăng tải tài liệu hoặc bài giảng.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(PortalSpacing.md),
            itemCount: detail.activities.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: PortalSpacing.xs),
            itemBuilder: (context, index) {
              final act = detail.activities[index];
              return _ActivityTile(activity: act);
            },
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (err, _) => PortalAsyncState.error(
          title: 'Không thể tải nội dung môn học',
          message: 'Vui lòng kiểm tra lại kết nối mạng.',
          onRetry: () => ref.invalidate(
            moodleCourseDetailFutureProvider((courseId: courseId, courseName: courseName)),
          ),
        ),
      ),
    );
  }

  static void _openExternalUrl(String url) {
    _urlChannel.invokeMethod('openPortalArticle', {'url': url});
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final MoodleActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, color, label) = switch (activity.type) {
      'folder' => (Icons.folder_rounded, Colors.amber[700]!, 'Thư mục tài liệu'),
      'forum' => (Icons.forum_rounded, Colors.blue[600]!, 'Diễn đàn thông báo'),
      'assign' => (Icons.assignment_turned_in_rounded, Colors.purple[600]!, 'Bài tập nộp'),
      'url' => (Icons.link_rounded, Colors.teal[600]!, 'Liên kết ngoài'),
      'quiz' => (Icons.quiz_rounded, Colors.orange[700]!, 'Bài trắc nghiệm'),
      _ => (Icons.description_rounded, Colors.red[600]!, 'Tài liệu / Slide'),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          activity.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () {
          if (activity.url != null && activity.url!.isNotEmpty) {
            CourseDetailScreen._openExternalUrl(activity.url!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không có liên kết cho hoạt động này')),
            );
          }
        },
      ),
    );
  }
}
