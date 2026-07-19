import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_portal_context_builder.dart';

class AiContextConsentSheet extends ConsumerWidget {
  const AiContextConsentSheet({super.key, required this.onConsentChanged});

  final void Function(bool consented) onConsentChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Dựng snapshot thử để người dùng preview trước khi chấp thuận
    final snapshot = const AiPortalContextBuilder().buildSnapshot(ref);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chia sẻ dữ liệu Portal',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: PortalSpacing.sm),
            Text(
              'Để Trợ lý AI có thể trả lời các câu hỏi về lịch học, học phí và điểm số, bạn cần cấp quyền cho trợ lý truy cập vào dữ liệu UIT Portal hiện có của bạn.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: PortalSpacing.md),
            Card(
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(PortalSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.green),
                    SizedBox(width: PortalSpacing.sm),
                    Expanded(
                      child: Text(
                        'Thông tin nhạy cảm của bạn (như mật khẩu, token, tài khoản ngân hàng, thông tin gia đình) luôn bị ẩn và không bao giờ được gửi đi.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PortalSpacing.md),
            Text(
              'Xem trước dữ liệu sẽ được chia sẻ:',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: PortalSpacing.xs),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(PortalSpacing.sm),
                child: Text(
                  _buildPreviewText(snapshot),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: PortalSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onConsentChanged(false);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: PortalSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      onConsentChanged(true);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Đồng ý & Chia sẻ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildPreviewText(dynamic snapshot) {
    final sb = StringBuffer();
    if (snapshot.profileSummary != null) {
      sb.writeln('[HỒ SƠ]');
      sb.writeln(snapshot.profileSummary);
    }
    if (snapshot.scheduleSummary != null) {
      sb.writeln('\n[LỊCH HỌC]');
      sb.writeln(snapshot.scheduleSummary);
    }
    if (snapshot.gradesSummary != null) {
      sb.writeln('\n[BẢNG ĐIỂM]');
      sb.writeln(snapshot.gradesSummary);
    }
    if (snapshot.tuitionSummary != null) {
      sb.writeln('\n[HỌC PHÍ]');
      sb.writeln(snapshot.tuitionSummary);
    }
    if (sb.isEmpty) {
      sb.writeln('Không có dữ liệu Portal khả dụng. Vui lòng đăng nhập.');
    }
    return sb.toString();
  }
}
