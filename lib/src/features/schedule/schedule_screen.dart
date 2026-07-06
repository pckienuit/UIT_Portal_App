import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schedule_model.dart';
import 'schedule_providers.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thời Khóa Biểu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(scheduleFutureProvider),
          ),
        ],
      ),
      body: scheduleAsync.when(
        data: (data) => _ScheduleView(response: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Đã có lỗi xảy ra: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(scheduleFutureProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({required this.response});

  final ScheduleResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.tiets.isEmpty) {
      return const Center(child: Text('Không có lịch học nào.'));
    }

    // Nhóm theo "Thứ" (thu)
    final groupedSchedule = <int, List<ScheduleItem>>{};
    for (final item in response.tiets) {
      if (item.thu < 2) continue; // Bỏ qua nếu thu không hợp lệ
      groupedSchedule.putIfAbsent(item.thu, () => []).add(item);
    }

    // Sắp xếp các thứ tăng dần (Thứ 2 -> Chủ nhật)
    final sortedDays = groupedSchedule.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final items = groupedSchedule[day]!;
        return _DayGroup(day: day, items: items);
      },
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.items});

  final int day;
  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final dayName = day == 8 ? 'Chủ nhật' : 'Thứ $day';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          dayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: items.map((item) => _ScheduleItemTile(item: item)).toList(),
      ),
    );
  }
}

class _ScheduleItemTile extends StatelessWidget {
  const _ScheduleItemTile({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thời gian
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Tiết',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${item.tietBatDau} - ${item.tietKetThuc}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Thông tin môn học
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tenMonHoc,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.meeting_room, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      item.phong.isNotEmpty ? item.phong : 'Chưa có phòng',
                      style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Mã lớp: ${item.maLop}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.giangVien.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GV: ${item.giangVien}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (item.loaiLich.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.loaiLich,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
