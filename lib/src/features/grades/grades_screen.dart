import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grades_model.dart';
import 'grades_providers.dart';
import '../../utils/liquid_scaffold.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesFutureProvider);

    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('Bảng Điểm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(gradesFutureProvider);
            },
          ),
        ],
      ),
      body: gradesAsync.when(
        data: (data) => _GradesView(response: data),
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
                  onPressed: () => ref.invalidate(gradesFutureProvider),
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

class _GradesView extends StatelessWidget {
  const _GradesView({required this.response});

  final GradesResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.semesterGroups.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu bảng điểm.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: response.semesterGroups.length,
      itemBuilder: (context, index) {
        final group = response.semesterGroups[index];
        return _SemesterCard(group: group);
      },
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({required this.group});

  final SemesterGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          group.semesterLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(group.yearName),
        children: [
          if (group.subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Chưa có môn học nào.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.subjects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final subject = group.subjects[index];
                return _SubjectTile(subject: subject);
              },
            ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject});

  final GradeSubject subject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // A small helper to show the final score nicely
    Widget scoreBadge(String score) {
      if (score.isEmpty) return const SizedBox();
      final numericScore = double.tryParse(score);
      final color = numericScore != null && numericScore < 5.0
          ? colorScheme.error
          : colorScheme.primary;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          score,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subjectName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subject.subjectCode} • ${subject.numberOfCredit} tín chỉ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (subject.coursePoint.isNotEmpty)
                scoreBadge(subject.coursePoint)
              else if (subject.statusPoint.isNotEmpty && subject.statusPoint != 'normal')
                Text(subject.statusPoint, style: const TextStyle(color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ScoreItem(label: 'QT', score: subject.processPoint),
              _ScoreItem(label: 'TH', score: subject.practicePoint),
              _ScoreItem(label: 'GK', score: subject.midtermScore),
              _ScoreItem(label: 'CK', score: subject.finalPoint),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  const _ScoreItem({required this.label, required this.score});

  final String label;
  final String score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          score.isEmpty ? '-' : score,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
