import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/components/portal_section_header.dart';
import '../../../design_system/components/portal_skeleton.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../../../design_system/foundations/portal_radii.dart';

import '../../schedule/schedule_providers.dart';

class TodayScheduleCard extends ConsumerWidget {
  const TodayScheduleCard({super.key});

  int _getDayOfWeekNumber() {
    final weekday = DateTime.now().weekday;
    return weekday == 7 ? 8 : weekday + 1;
  }

  String _getDayName(int thu) {
    return thu == 8 ? 'Chủ nhật' : 'Thứ $thu';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleFutureProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalSurface(
      padding: const EdgeInsets.all(PortalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PortalSectionHeader(
            title: 'Lịch học hôm nay',
            subtitle: _getDayName(_getDayOfWeekNumber()),
            trailing: Icon(Icons.today, color: colorScheme.primary),
          ),
          const SizedBox(height: PortalSpacing.md),
          scheduleAsync.when(
            data: (schedule) {
              final todayNum = _getDayOfWeekNumber();
              final todayClasses =
                  schedule.tiets.where((item) => item.thu == todayNum).toList()
                    ..sort((a, b) => a.tietBatDau.compareTo(b.tietBatDau));

              if (todayClasses.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: PortalSpacing.md,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration_outlined,
                        size: 36,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(height: PortalSpacing.xs),
                      Text(
                        'Hôm nay bạn không có lịch học',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todayClasses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: PortalSpacing.sm),
                itemBuilder: (context, index) {
                  final item = todayClasses[index];
                  return Container(
                    padding: const EdgeInsets.all(PortalSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(PortalRadii.card - 4),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              PortalRadii.card - 8,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Tiết',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${item.tietBatDau}-${item.tietKetThuc}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: PortalSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.tenMonHoc,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: PortalSpacing.xxs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.room_outlined,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.phong.isNotEmpty
                                        ? 'Phòng ${item.phong}'
                                        : 'Chưa xếp phòng',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (item.giangVien.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.giangVien,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PortalSkeleton(width: 140, height: 20),
                SizedBox(height: PortalSpacing.sm),
                PortalSkeleton(height: 60),
              ],
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: PortalSpacing.sm),
              child: Text(
                'Không thể tải lịch học hôm nay.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
