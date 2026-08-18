import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
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

class _SemesterExamGroup {
  _SemesterExamGroup({
    required this.key,
    required this.semesterLabel,
    required this.yearName,
    required this.items,
    required this.orderScore,
  });

  final String key;
  final String semesterLabel;
  final String yearName;
  final List<ExamItem> items;
  final int orderScore;
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

    final groupsMap = <String, _SemesterExamGroup>{};

    for (final item in response.items) {
      final info = _resolveSemesterInfo(item);
      final group = groupsMap.putIfAbsent(
        info.key,
        () => _SemesterExamGroup(
          key: info.key,
          semesterLabel: info.semesterLabel,
          yearName: info.yearName,
          items: [],
          orderScore: info.orderScore,
        ),
      );
      group.items.add(item);
    }

    // Sắp xếp các học kỳ từ gần nhất đến xa nhất (orderScore giảm dần)
    final sortedGroups = groupsMap.values.toList()
      ..sort((a, b) {
        final cmp = b.orderScore.compareTo(a.orderScore);
        if (cmp != 0) return cmp;
        return b.key.compareTo(a.key);
      });

    // Trong mỗi học kỳ, sắp xếp các môn thi từ mới nhất đến cũ nhất theo ngày thi
    for (final group in sortedGroups) {
      group.items.sort((a, b) {
        final dateA = a.ngayThi ?? '';
        final dateB = b.ngayThi ?? '';
        final dateCmp = dateB.compareTo(dateA);
        if (dateCmp != 0) return dateCmp;
        return (a.gioBatDau ?? '').compareTo(b.gioBatDau ?? '');
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.all(PortalSpacing.md),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final group = sortedGroups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: PortalSpacing.sm),
          child: _ExamSemesterCard(
            group: group,
            initiallyExpanded: index == 0,
          ),
        );
      },
    );
  }

  static ({String key, String semesterLabel, String yearName, int orderScore}) _resolveSemesterInfo(ExamItem item) {
    int? nam;
    if (item.namHoc != null) {
      if (item.namHoc is int) {
        nam = item.namHoc as int;
      } else {
        nam = int.tryParse(item.namHoc.toString().split(RegExp(r'[-_/]')).first);
      }
    }

    int? hk;
    if (item.hocKy != null) {
      if (item.hocKy is int) {
        hk = item.hocKy as int;
      } else {
        hk = int.tryParse(item.hocKy.toString());
      }
    }

    if (nam == null && item.ngayThi != null && item.ngayThi!.length >= 4) {
      nam = int.tryParse(item.ngayThi!.substring(0, 4));
    }

    final year = nam ?? 0;
    final term = hk ?? 0;

    final key = '$year-$term';
    final semesterLabel = term > 0 ? 'Học kỳ $term' : 'Lịch thi';
    final yearName = year > 0 ? 'Năm học $year - ${year + 1}' : '';
    final orderScore = (year * 10) + term;

    return (
      key: key,
      semesterLabel: semesterLabel,
      yearName: yearName,
      orderScore: orderScore,
    );
  }
}

class _ExamSemesterCard extends StatelessWidget {
  const _ExamSemesterCard({
    required this.group,
    required this.initiallyExpanded,
  });

  final _SemesterExamGroup group;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(group.key),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: PortalSpacing.md,
          vertical: PortalSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          PortalSpacing.md,
          0,
          PortalSpacing.md,
          PortalSpacing.md,
        ),
        title: Text(
          group.semesterLabel.isEmpty ? 'Học kỳ' : group.semesterLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: group.yearName.isEmpty
            ? null
            : Text(
                group.yearName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        children: [
          for (var index = 0; index < group.items.length; index++) ...[
            _ExamItemView(item: group.items[index]),
            if (index < group.items.length - 1)
              const SizedBox(height: PortalSpacing.sm),
          ],
        ],
      ),
    );
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _subjectName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_examTypeLabel.isNotEmpty) ...[
                  const SizedBox(width: PortalSpacing.xs),
                  PortalStatusChip(
                    label: _examTypeLabel,
                    tone: _examTypeTone,
                  ),
                ],
              ],
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

  String get _examTypeLabel {
    final normalized = item.kyThi?.trim().toLowerCase() ?? '';
    if (normalized == 'midterm' || normalized.contains('giữa')) return 'Giữa kỳ';
    if (normalized == 'final_term' || normalized == 'final' || normalized.contains('cuối')) return 'Cuối kỳ';
    if (normalized.isNotEmpty) return item.kyThi!.trim();
    return '';
  }

  PortalStatusTone get _examTypeTone {
    final normalized = item.kyThi?.trim().toLowerCase() ?? '';
    if (normalized == 'midterm' || normalized.contains('giữa')) {
      return PortalStatusTone.info;
    }
    if (normalized == 'final_term' || normalized == 'final' || normalized.contains('cuối')) {
      return PortalStatusTone.success;
    }
    return PortalStatusTone.neutral;
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
