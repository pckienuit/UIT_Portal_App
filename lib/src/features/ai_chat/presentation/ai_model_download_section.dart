import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/local_model_controller.dart';
import '../data/local_model_catalog.dart';
import '../data/local_model_manager.dart';

class AiModelDownloadSection extends ConsumerWidget {
  const AiModelDownloadSection({super.key, required this.modelInfo});

  final LocalModelInfo modelInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localModelControllerProvider(modelInfo.id));
    final notifier = ref.read(localModelControllerProvider(modelInfo.id).notifier);
    
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalSpacing.md),
      child: PortalSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download_for_offline, size: 28, color: Colors.blue),
                const SizedBox(width: PortalSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelInfo.name,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Dung lượng: ${(modelInfo.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PortalSpacing.md),
            if (state.status == LocalModelStatus.notDownloaded) ...[
              Text(
                'Tải xuống model để chat offline hoàn toàn cục bộ, bảo mật tuyệt đối dữ liệu cá nhân của bạn.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: PortalSpacing.sm),
              FilledButton.icon(
                onPressed: notifier.startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Tải xuống'),
              ),
            ] else if (state.status == LocalModelStatus.downloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: state.progressPercent / 100.0,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: PortalSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đang tải: ${state.progressPercent.toStringAsFixed(1)}%',
                        style: textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: notifier.cancelDownload,
                        child: const Text('Hủy'),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (state.status == LocalModelStatus.verifying) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Icon(Icons.verified_user_outlined, size: 16),
                  ),
                  SizedBox(width: PortalSpacing.sm),
                  Expanded(
                    child: Text(
                      'Đang kiểm tra tính toàn vẹn của mô hình...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (state.status == LocalModelStatus.ready) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: PortalSpacing.sm),
                  Expanded(
                    child: Text(
                      'Đã tải và sẵn sàng hoạt động.',
                      style: textTheme.bodyMedium?.copyWith(color: Colors.green.shade900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Xóa mô hình',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Xóa mô hình local?'),
                          content: const Text('Hành động này sẽ giải phóng dung lượng bộ nhớ trên thiết bị của bạn.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () {
                                notifier.deleteModel();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ] else if (state.status == LocalModelStatus.error) ...[
              Text(
                'Lỗi tải mô hình: ${state.errorMessage}',
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: PortalSpacing.sm),
              OutlinedButton(
                onPressed: notifier.startDownload,
                child: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
