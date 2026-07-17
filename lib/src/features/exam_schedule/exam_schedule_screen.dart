import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_section_header.dart';
import '../../design_system/components/portal_surface.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'exam_schedule_model.dart';
import 'exam_schedule_providers.dart';

class ExamScheduleScreen extends ConsumerWidget {
  const ExamScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examScheduleFutureProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Lịch thi'),
        actions: [
          IconButton(
            tooltip: 'Làm mới lịch thi',
            onPressed: () => ref.invalidate(examScheduleFutureProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        data: (response) => _ExamScheduleView(response: response),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải lịch thi',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(examScheduleFutureProvider),
        ),
      ),
    );
  }
}

class _ExamScheduleView extends StatelessWidget {
  const _ExamScheduleView({required this.response});

  final ExamScheduleResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.items.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có lịch thi',
        message: 'Lịch thi sẽ xuất hiện khi hệ thống UIT cập nhật.',
      );
    }
    final sorted = List<ExamItem>.of(response.items)
      ..sort((a, b) => (b.ngayThi ?? '').compareTo(a.ngayThi ?? ''));
    final groups = <String, List<ExamItem>>{};
    for (final item in sorted) {
      groups.putIfAbsent(_groupLabel(item), () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        for (final entry in groups.entries) ...[
          PortalSectionHeader(title: entry.key),
          const SizedBox(height: PortalSpacing.sm),
          for (final item in entry.value) ...[
            _ExamItemView(item: item),
            const SizedBox(height: PortalSpacing.sm),
          ],
          const SizedBox(height: PortalSpacing.sm),
        ],
      ],
    );
  }

  String _groupLabel(ExamItem item) {
    final term = switch (item.kyThi) {
      'midterm' => 'Thi giữa kỳ',
      'final_term' => 'Thi cuối kỳ',
      _ => 'Kỳ thi khác',
    };
    if (item.namHoc != null && item.hocKy != null) {
      return '$term, học kỳ ${item.hocKy}, năm học ${item.namHoc}';
    }
    final year = item.ngayThi != null && item.ngayThi!.length >= 4
        ? item.ngayThi!.substring(0, 4)
        : 'chưa rõ';
    return '$term, năm $year';
  }
}

class _ExamItemView extends StatelessWidget {
  const _ExamItemView({required this.item});

  final ExamItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticsLabel,
      child: PortalSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _subjectName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: PortalSpacing.xxs),
            Text(
              [
                item.maMonHoc,
                item.maLop,
              ].where((value) => value.trim().isNotEmpty).join(' • '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PortalSpacing.md),
            Wrap(
              spacing: PortalSpacing.lg,
              runSpacing: PortalSpacing.sm,
              children: [
                _Detail(
                  icon: Icons.event_outlined,
                  label: 'Ngày thi',
                  value: _value(item.ngayThi),
                ),
                _Detail(
                  icon: Icons.schedule_outlined,
                  label: 'Giờ thi',
                  value: _time,
                ),
                _Detail(
                  icon: Icons.tag_outlined,
                  label: 'Ca thi',
                  value: item.caThi?.toString() ?? 'Chưa cập nhật',
                ),
                _Detail(
                  icon: Icons.meeting_room_outlined,
                  label: 'Phòng',
                  value: _value(item.phong),
                ),
                _Detail(
                  icon: Icons.description_outlined,
                  label: 'Hình thức',
                  value: _value(item.hinhThuc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _time {
    final start = item.gioBatDau?.trim();
    final end = item.gioKetThuc?.trim();
    if (start?.isNotEmpty == true && end?.isNotEmpty == true) {
      return '$start đến $end';
    }
    return start?.isNotEmpty == true
        ? start!
        : end?.isNotEmpty == true
        ? end!
        : 'Chưa cập nhật';
  }

  String _value(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }

  String get _subjectName => item.tenMonHoc.trim().isEmpty
      ? 'Môn học chưa có tên'
      : item.tenMonHoc.trim();

  String get _semanticsLabel =>
      '$_subjectName, ngày thi ${_value(item.ngayThi)}, giờ thi $_time, phòng ${_value(item.phong)}';
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: PortalSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
