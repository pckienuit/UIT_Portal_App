import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'models/moodle_models.dart';
import 'providers/moodle_providers.dart';

const _urlChannel = MethodChannel('com.pckienuit.uitportal/external_url');

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final int courseId;
  final String courseName;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  Future<void> _handleActivityTap(MoodleActivity activity) async {
    final actUrl = activity.url;
    if (actUrl == null || actUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có liên kết cho hoạt động này')),
      );
      return;
    }

    // Nếu là resource (Slide / PDF) hoặc folder (Thư mục tài liệu) -> Tải trực tiếp trong app bằng session Moodle
    if (activity.type == 'resource' || activity.type == 'folder') {
      setState(() {
        _isDownloading[activity.id] = true;
        _downloadProgress[activity.id] = 0.0;
      });

      final messenger = ScaffoldMessenger.of(context);

      try {
        final repo = ref.read(moodleRepositoryProvider);
        final filePath = await repo.downloadActivityFile(
          activity,
          onProgress: (count, total) {
            if (total > 0 && mounted) {
              setState(() {
                _downloadProgress[activity.id] = count / total;
              });
            }
          },
        );

        if (!mounted) return;

        setState(() {
          _isDownloading[activity.id] = false;
        });

        // Xác định MIME Type
        String mimeType = 'application/pdf';
        if (filePath.endsWith('.zip')) {
          mimeType = 'application/zip';
        } else if (filePath.endsWith('.docx') || filePath.endsWith('.doc')) {
          mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (filePath.endsWith('.pptx') || filePath.endsWith('.ppt')) {
          mimeType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        }

        // Mở file trực tiếp trên app qua native intent viewer
        try {
          await _urlChannel.invokeMethod('openDownloadedFile', {
            'filePath': filePath,
            'mimeType': mimeType,
          });
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text('Đã tải thành công: $filePath')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isDownloading[activity.id] = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Tải thất bại: $e. Đang chuyển hướng sang trình duyệt...')),
        );
        _openExternalUrl(actUrl);
      }
    } else {
      // Các loại URL / WeCode / Forum / Quiz -> Mở trình duyệt web
      _openExternalUrl(actUrl);
    }
  }

  static Future<void> _openExternalUrl(String url) async {
    try {
      await _urlChannel.invokeMethod('openWebBrowser', {'url': url});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      moodleCourseDetailFutureProvider((courseId: widget.courseId, courseName: widget.courseName)),
    );

    return PortalScaffold(
      appBar: AppBar(
        title: Text(
          widget.courseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Mở trên web Moodle',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () {
              _openExternalUrl('https://courses.uit.edu.vn/course/view.php?id=${widget.courseId}');
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(
              moodleCourseDetailFutureProvider((courseId: widget.courseId, courseName: widget.courseName)),
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
              final downloading = _isDownloading[act.id] ?? false;
              final progress = _downloadProgress[act.id] ?? 0.0;

              return _ActivityTile(
                activity: act,
                isDownloading: downloading,
                progress: progress,
                onTap: () => _handleActivityTap(act),
              );
            },
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (err, _) => PortalAsyncState.error(
          title: 'Không thể tải nội dung môn học',
          message: 'Vui lòng kiểm tra lại kết nối mạng.',
          onRetry: () => ref.invalidate(
            moodleCourseDetailFutureProvider((courseId: widget.courseId, courseName: widget.courseName)),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.isDownloading,
    required this.progress,
    required this.onTap,
  });

  final MoodleActivity activity;
  final bool isDownloading;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, color, label) = switch (activity.type) {
      'folder' => (Icons.folder_zip_rounded, Colors.amber[700]!, 'Thư mục tài liệu (ZIP)'),
      'forum' => (Icons.forum_rounded, Colors.blue[600]!, 'Diễn đàn thông báo'),
      'assign' => (Icons.assignment_turned_in_rounded, Colors.purple[600]!, 'Bài tập nộp'),
      'url' => (Icons.link_rounded, Colors.teal[600]!, 'Liên kết ngoài'),
      'quiz' => (Icons.quiz_rounded, Colors.orange[700]!, 'Bài trắc nghiệm'),
      _ => (Icons.picture_as_pdf_rounded, Colors.red[600]!, 'Slide / File tài liệu'),
    };

    final isDownloadable = activity.type == 'resource' || activity.type == 'folder';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isDownloading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(PortalSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: PortalSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            if (isDownloadable) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Tải trực tiếp',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: PortalSpacing.xs),
                  if (isDownloading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.5,
                      ),
                    )
                  else
                    Icon(
                      isDownloadable ? Icons.download_for_offline_rounded : Icons.open_in_new_rounded,
                      color: isDownloadable ? scheme.primary : scheme.onSurfaceVariant,
                      size: 22,
                    ),
                ],
              ),
              if (isDownloading && progress > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
