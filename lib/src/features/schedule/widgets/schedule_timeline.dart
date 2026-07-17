import 'package:flutter/material.dart';

import '../../../design_system/components/portal_async_state.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../schedule_model.dart';
import 'schedule_class_tile.dart';
import 'schedule_day_strip.dart';

class ScheduleTimeline extends StatefulWidget {
  const ScheduleTimeline({super.key, required this.response});

  final ScheduleResponse response;

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  late final List<DateTime> _classDays;
  late DateTime _weekStart;
  late DateTime _selectedDay;

  List<DateTime> get _days =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  @override
  void initState() {
    super.initState();
    _classDays =
        widget.response.tiets
            .map((item) => _parseApiDate(item.ngay))
            .whereType<DateTime>()
            .map(DateUtils.dateOnly)
            .toSet()
            .toList()
          ..sort();
    final today = DateUtils.dateOnly(DateTime.now());
    final anchor = _classDays.isEmpty
        ? today
        : _classDays.reduce(
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
    if (widget.response.tiets.isEmpty || _classDays.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có lịch học',
        message: 'Lịch học của học kỳ này chưa có dữ liệu ngày hợp lệ.',
      );
    }

    final items =
        widget.response.tiets.where((item) {
          final date = _parseApiDate(item.ngay);
          return date != null && DateUtils.isSameDay(date, _selectedDay);
        }).toList()..sort(
          (first, second) => first.tietBatDau.compareTo(second.tietBatDau),
        );
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
          child: items.isEmpty
              ? const PortalAsyncState.empty(
                  title: 'Không có lịch hôm nay',
                  message: 'Bạn không có lớp học trong ngày đã chọn.',
                )
              : ListView.builder(
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
                ),
        ),
      ],
    );
  }

  void _moveWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
      _selectedDay =
          _classDays
              .where(
                (day) =>
                    !day.isBefore(_weekStart) &&
                    day.isBefore(_weekStart.add(const Duration(days: 7))),
              )
              .firstOrNull ??
          _weekStart;
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
