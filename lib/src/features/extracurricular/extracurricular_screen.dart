import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extracurricular_providers.dart';
import 'extracurricular_model.dart';
import '../../utils/liquid_scaffold.dart';

class ExtracurricularScreen extends ConsumerWidget {
  const ExtracurricularScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(extracurricularProvider);

    return LiquidScaffold(
      appBar: AppBar(title: const Text('Lịch sinh hoạt'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, Theme.of(context)),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Lỗi khi tải dữ liệu:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(extracurricularProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ExtracurricularResponse data,
    ThemeData theme,
  ) {
    if (data.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Hiện không có lịch sinh hoạt nào'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.items.length,
      itemBuilder: (context, index) {
        final item = data.items[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tenHoatDong ?? 'Hoạt động ngoại khóa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(item.ngayBatDau ?? 'Chưa rõ ngày'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Text(item.diaDiem ?? 'Chưa rõ địa điểm'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
