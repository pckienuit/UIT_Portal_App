import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'grades_model.dart';
import 'grades_providers.dart';
import 'widgets/semester_summary.dart';

class GradesScreen extends ConsumerStatefulWidget {
  const GradesScreen({super.key});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradesAsync = ref.watch(gradesFutureProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Bảng điểm'),
        actions: [
          IconButton(
            tooltip: 'Làm mới bảng điểm',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(gradesFutureProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Theo học kỳ'),
            Tab(text: 'Theo CTĐT'),
            Tab(text: 'Tổng kết & GDTC/QP'),
          ],
        ),
      ),
      body: gradesAsync.when(
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Bảng điểm theo từng học kỳ
            _GradesBySemesterTab(response: data),

            // Tab 2: Tiến độ Chương trình đào tạo (CTĐT)
            _GradesByCtdtTab(response: data),

            // Tab 3: Tổng kết kỳ & Chứng chỉ GDQP / Tiếng Anh
            _GradesSummaryTab(response: data),
          ],
        ),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải bảng điểm',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(gradesFutureProvider),
        ),
      ),
    );
  }
}

class _GradesBySemesterTab extends StatelessWidget {
  const _GradesBySemesterTab({required this.response});

  final GradesResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.semesterGroups.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có dữ liệu bảng điểm',
        message: 'Kết quả học tập sẽ xuất hiện khi hệ thống UIT cập nhật.',
      );
    }

    final summary = response.summary;

    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        if (summary != null) ...[
          _SummaryHeaderCard(summary: summary),
          const SizedBox(height: PortalSpacing.md),
        ],
        ...response.semesterGroups.asMap().entries.map((entry) {
          final index = entry.key;
          final group = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: PortalSpacing.sm),
            child: SemesterSummary(
              group: group,
              initiallyExpanded: index == 0,
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryHeaderCard extends StatelessWidget {
  const _SummaryHeaderCard({required this.summary});

  final GradesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      color: scheme.primaryContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tổng quan kết quả học tập',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Điểm TB tích lũy', '${summary.gpaAccumulated ?? summary.gpaAll ?? '-'}', scheme.primary, theme),
                _buildDivider(theme),
                _buildStatItem('Tín chỉ tích lũy', '${summary.accumulatedCredits ?? summary.totalCreditsAll ?? '-'}', scheme.primary, theme),
                _buildDivider(theme),
                _buildStatItem('Tổng TC đã học', '${summary.totalCreditsAll ?? '-'}', scheme.onSurfaceVariant, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 36,
      width: 1,
      color: theme.dividerColor.withValues(alpha: 0.5),
    );
  }
}

class _GradesByCtdtTab extends StatelessWidget {
  const _GradesByCtdtTab({required this.response});

  final GradesResponse response;

  @override
  Widget build(BuildContext context) {
    final stats = response.ctdtStatistics;
    final theme = Theme.of(context);

    if (stats == null && response.programScores.isEmpty) {
      return const Center(
        child: Text('Chưa có thông tin tiến độ chương trình đào tạo.'),
      );
    }

    final passedCredit = stats?.passedCredit ?? 0;
    final totalCredit = stats?.totalProgramCredit ?? 128;
    final progress = totalCredit > 0 ? (passedCredit / totalCredit).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        // Card Tiến độ CTĐT
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiến độ tích lũy CTĐT',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$passedCredit / $totalCredit TC',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniBadge('Đã đạt', '${stats?.passed ?? '-'} môn', Colors.green, theme),
                    _buildMiniBadge('Chưa học', '${stats?.notLearned ?? '-'} môn', Colors.grey, theme),
                    _buildMiniBadge('Học lại', '${stats?.retake ?? 0} môn', Colors.red, theme),
                    _buildMiniBadge('Ngoài CTĐT', '${stats?.outsideProgram ?? 0} môn', Colors.orange, theme),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PortalSpacing.md),

        // Danh sách các học kỳ trong khung CTĐT
        ...response.programScores.map((group) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ExpansionTile(
              title: Text(
                '${group.semesterLabel} (${group.totalCredit} tín chỉ)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                ...group.lines.map((subject) {
                  final isPassed = subject.status == 'passed';
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${subject.subjectCode} - ${subject.subjectName}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isPassed ? null : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text('${subject.credit} TC (LT: ${subject.creditTheory}, TH: ${subject.creditPract})'),
                    trailing: isPassed
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Đạt (${subject.coursePoint ?? ''})',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          )
                        : Text(
                            'Chưa học',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                  );
                }),
              ],
            ),
          );
        }),

        // Môn ngoài CTĐT nếu có
        if (response.outsideProgramSubjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Môn học ngoài CTĐT (${response.outsideProgramSubjects.length} môn)',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Column(
              children: response.outsideProgramSubjects.map((sub) {
                return ListTile(
                  dense: true,
                  title: Text('${sub.subjectCode} - ${sub.subjectName}'),
                  trailing: Text('${sub.credit} TC', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniBadge(String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _GradesSummaryTab extends StatelessWidget {
  const _GradesSummaryTab({required this.response});

  final GradesResponse response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defense = response.defenseEducation;
    final foreignLang = response.foreignLanguage;

    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        // Chứng chỉ Giáo dục Quốc phòng & An ninh
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Giáo dục Quốc phòng & An ninh',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (defense != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trạng thái:', style: theme.textTheme.bodyMedium),
                      PortalStatusChip(
                        label: defense.passed ? 'Đã đạt' : 'Chưa đạt',
                        tone: defense.passed ? PortalStatusTone.success : PortalStatusTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Điểm & Xếp loại:', style: theme.textTheme.bodyMedium),
                      Text(
                        '${defense.score ?? '-'} (${defense.rankLabel ?? defense.rank ?? ''})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (defense.certificate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Số chứng chỉ:', style: theme.textTheme.bodyMedium),
                        Text(defense.certificate!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ] else
                  const Text('Chưa có thông tin chứng chỉ GDQP.'),
              ],
            ),
          ),
        ),

        const SizedBox(height: PortalSpacing.md),

        // Chuẩn ngoại ngữ
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Chuẩn Tiếng Anh / Ngoại ngữ',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (foreignLang != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trạng thái:', style: theme.textTheme.bodyMedium),
                      PortalStatusChip(
                        label: foreignLang.passed ? 'Đã xác nhận' : 'Chưa nộp/chưa đạt',
                        tone: foreignLang.passed ? PortalStatusTone.success : PortalStatusTone.warning,
                      ),
                    ],
                  ),
                ] else
                  const Text('Chưa có thông tin chứng chỉ ngoại ngữ đã xác nhận.'),
              ],
            ),
          ),
        ),

        const SizedBox(height: PortalSpacing.md),

        // Lịch sử Đánh giá / Tổng kết từng kỳ
        if (response.termSummaries.isNotEmpty) ...[
          Text(
            'Lịch sử tổng kết từng học kỳ',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...response.termSummaries.map((term) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Học kỳ ${term.semester} - Năm học ${term.yearName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (term.classifyLabel != null)
                          PortalStatusChip(
                            label: term.classifyLabel!,
                            tone: term.classifyLabel == 'Giỏi' || term.classifyLabel == 'Xuất sắc'
                                ? PortalStatusTone.success
                                : PortalStatusTone.info,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Điểm TB học kỳ: ${term.termGpa ?? '-'}', style: const TextStyle(fontSize: 13)),
                        Text('Điểm TB tích lũy: ${term.cumulativeGpa ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tín chỉ HK: ${term.termCredit ?? '-'} TC', style: const TextStyle(fontSize: 13)),
                        Text('Tích lũy: ${term.accumulatedCredit ?? '-'} TC', style: const TextStyle(fontSize: 13)),
                        Text('ĐRL: ${term.trainingScore ?? '-'}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
