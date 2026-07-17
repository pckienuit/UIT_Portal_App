import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import '../../design_system/components/portal_surface.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'training_point_model.dart';
import 'training_point_providers.dart';

class TrainingPointScreen extends ConsumerWidget {
  const TrainingPointScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainingPointFutureProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Điểm rèn luyện'),
        actions: [
          IconButton(
            tooltip: 'Làm mới điểm rèn luyện',
            onPressed: () => ref.invalidate(trainingPointFutureProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        data: (data) => _TrainingPointView(data: data),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải điểm rèn luyện',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(trainingPointFutureProvider),
        ),
      ),
    );
  }
}

class _TrainingPointView extends StatelessWidget {
  const _TrainingPointView({required this.data});

  final TrainingPointResponse data;

  @override
  Widget build(BuildContext context) {
    if (data.trainingPointHistory.isEmpty &&
        data.averageTrainingPoint == null &&
        _missing(data.averageRank)) {
      return const PortalAsyncState.empty(
        title: 'Chưa có điểm rèn luyện',
        message: 'Kết quả sẽ xuất hiện khi hệ thống UIT cập nhật.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 480 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3;
            final width = wide
                ? (constraints.maxWidth - PortalSpacing.sm) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: PortalSpacing.sm,
              runSpacing: PortalSpacing.sm,
              children: [
                _Metric(
                  width: width,
                  label: 'Điểm trung bình',
                  value:
                      data.averageTrainingPoint?.toStringAsFixed(1) ??
                      'Chưa cập nhật',
                  icon: Icons.trending_up,
                ),
                _Metric(
                  width: width,
                  label: 'Xếp loại trung bình',
                  value: _value(data.averageRank),
                  icon: Icons.emoji_events_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: PortalSpacing.lg),
        if (data.trainingPointHistory.isEmpty)
          const PortalAsyncState.empty(
            title: 'Chưa có lịch sử rèn luyện',
            message: 'Chưa có kết quả theo học kỳ.',
          )
        else
          for (final history in data.trainingPointHistory) ...[
            _HistoryItem(history: history),
            const SizedBox(height: PortalSpacing.sm),
          ],
      ],
    );
  }

  static bool _missing(String? value) => value == null || value.trim().isEmpty;
  static String _value(String? value) =>
      _missing(value) ? 'Chưa cập nhật' : value!.trim();
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: PortalSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: PortalSpacing.xs),
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: PortalSpacing.xxs),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.history});

  final TrainingPointHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = history.point;
    final progress = point == null ? null : (point.clamp(0, 100) / 100);
    return PortalSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PortalSpacing.sm,
            runSpacing: PortalSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _semesterLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              PortalStatusChip(
                label: _value(history.rank, 'Chưa xét'),
                tone: _tone(history.rank, point),
              ),
            ],
          ),
          const SizedBox(height: PortalSpacing.sm),
          Text('Năm học: ${_value(history.yearName)}'),
          const SizedBox(height: PortalSpacing.xs),
          Text('Lớp: ${_value(history.specializedClassName)}'),
          const SizedBox(height: PortalSpacing.md),
          Text(
            point == null ? 'Chưa cập nhật' : '$point điểm',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: PortalSpacing.xs),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }

  String _value(String? value, [String fallback = 'Chưa cập nhật']) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  String get _semesterLabel {
    final label = history.semesterLabel?.trim();
    if (label?.isNotEmpty == true) return label!;
    return _value(history.semester, 'Học kỳ');
  }

  PortalStatusTone _tone(String? rank, int? point) {
    final normalized = rank?.trim().toLowerCase() ?? '';
    if (normalized.contains('xuất sắc') || (point != null && point >= 90)) {
      return PortalStatusTone.success;
    }
    if (normalized.contains('giỏi') || normalized.contains('khá')) {
      return PortalStatusTone.info;
    }
    if (normalized.contains('trung bình')) return PortalStatusTone.warning;
    if (normalized.isEmpty && point == null) return PortalStatusTone.neutral;
    return PortalStatusTone.error;
  }
}
