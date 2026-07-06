import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'teaching_survey_providers.dart';

class TeachingSurveyScreen extends ConsumerWidget {
  const TeachingSurveyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyAsync = ref.watch(teachingSurveyFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khảo sát giảng dạy'),
      ),
      body: surveyAsync.when(
        data: (response) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(context, 'Cần khảo sát', response.pendingCount, Colors.orange),
                    _buildStatCard(context, 'Đã hoàn thành', response.doneCount, Colors.green),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: response.items.isEmpty
                    ? const Center(child: Text('Không có môn học nào cần khảo sát'))
                    : ListView.builder(
                        itemCount: response.items.length,
                        itemBuilder: (context, index) {
                          final item = response.items[index];
                          final isDone = item.isDone ?? false;
                          return ListTile(
                            leading: Icon(
                              isDone ? Icons.check_circle : Icons.pending_actions,
                              color: isDone ? Colors.green : Colors.orange,
                            ),
                            title: Text(item.tenMonHoc ?? 'Không rõ môn học'),
                            subtitle: Text('Lớp: ${item.maLop ?? ""}\nGiảng viên: ${item.giangVien ?? ""}'),
                            trailing: isDone ? const Text('Đã xong') : const Text('Chưa làm'),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(teachingSurveyFutureProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(count.toString(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }
}
