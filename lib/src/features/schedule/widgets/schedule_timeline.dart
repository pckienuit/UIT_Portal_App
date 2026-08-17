import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/portal_async_state.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../schedule_model.dart';
import '../schedule_providers.dart';
import 'schedule_class_tile.dart';
import 'schedule_day_strip.dart';

class ScheduleTimeline extends ConsumerStatefulWidget {
  const ScheduleTimeline({super.key, required this.response});

  final ScheduleResponse response;

  @override
  ConsumerState<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends ConsumerState<ScheduleTimeline> {
  late DateTime _weekStart;
  late DateTime _selectedDay;

  List<DateTime> get _days =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  String get _weekStartDateStr {
    final year = _weekStart.year.toString().padLeft(4, '0');
    final month = _weekStart.month.toString().padLeft(2, '0');
    final day = _weekStart.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    final classDays = widget.response.tiets
        .map((item) => _parseApiDate(item.ngay))
        .whereType<DateTime>()
        .map(DateUtils.dateOnly)
        .toSet()
        .toList()
      ..sort();

    final today = DateUtils.dateOnly(DateTime.now());
    final anchor = classDays.isEmpty
        ? today
        : classDays.reduce(
            (closest, day) =>
                day.difference(today).abs() < closest.difference(today).abs()
                ? day
                : closest,
          );
    _weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    _selectedDay = anchor;
  }

  @override
  Widget build(BuildContext context) {
    // Nếu response ban đầu có chứa các lớp học của tuần hiện tại đang chọn, dùng luôn dữ liệu từ response
    final hasClassesInSelectedWeek = widget.response.tiets.any((item) {
      final date = _parseApiDate(item.ngay);
      if (date == null) return false;
      return !date.isBefore(_weekStart) && date.isBefore(_weekStart.add(const Duration(days: 7)));
    });

    final scheduleAsync = hasClassesInSelectedWeek
        ? AsyncValue.data(widget.response)
        : ref.watch(scheduleByWeekProvider(_weekStartDateStr));

    final weekday = _selectedDay.weekday == DateTime.sunday
        ? 'Chủ nhật'
        : 'Thứ ${_selectedDay.weekday + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: PortalSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PortalSpacing.xs),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: () => _moveWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: ScheduleDayStrip(
                  days: _days,
                  selectedDay: _selectedDay,
                  onSelected: (day) => setState(() => _selectedDay = day),
                ),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: () => _moveWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: PortalSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PortalSpacing.md),
          child: Text(
            '$weekday, ${_selectedDay.day}/${_selectedDay.month}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: PortalSpacing.md),
        Expanded(
          child: scheduleAsync.when(
            data: (response) {
              final items = response.tiets.where((item) {
                final date = _parseApiDate(item.ngay);
                if (date != null) {
                  return DateUtils.isSameDay(date, _selectedDay);
                }
                final dow = _selectedDay.weekday == DateTime.sunday ? 8 : _selectedDay.weekday + 1;
                return item.thu == dow;
              }).toList()..sort(
                (first, second) => first.tietBatDau.compareTo(second.tietBatDau),
              );

              if (items.isEmpty) {
                return const PortalAsyncState.empty(
                  title: 'Không có lịch hôm nay',
                  message: 'Bạn không có lớp học trong ngày đã chọn.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: PortalSpacing.md,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => IntrinsicHeight(
                  child: ScheduleClassTile(
                    item: items[index],
                    isLast: index == items.length - 1,
                  ),
                ),
              );
            },
            loading: () => const PortalAsyncState.loading(),
            error: (error, stack) => PortalAsyncState.error(
              title: 'Không tải được lịch học',
              message: 'Vui lòng kiểm tra kết nối và thử lại.',
              onRetry: () => ref.invalidate(scheduleByWeekProvider(_weekStartDateStr)),
            ),
          ),
        ),
      ],
    );
  }

  void _moveWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
      _selectedDay = _weekStart.add(Duration(days: _selectedDay.weekday - 1));
    });
  }
}

DateTime? _parseApiDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}
