import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'student_support_providers.dart';
import 'student_support_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class StudentSupportScreen extends ConsumerWidget {
  const StudentSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(student_supportProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Hỗ trợ SV'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin hỗ trợ',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(student_supportProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    StudentSupportResponse data,
    ThemeData theme,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Yêu cầu hỗ trợ'),
              Tab(text: 'Phòng ban'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTicketsTab(data.tickets, theme),
                _buildTeamsTab(data.teams, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsTab(List<dynamic> tickets, ThemeData theme) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headset_mic, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có yêu cầu hỗ trợ nào.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
      );
    }
    return const PortalAsyncState.unavailable(
      title: 'Chưa thể hiển thị yêu cầu hỗ trợ',
      message: 'Dữ liệu yêu cầu chưa có cấu trúc hiển thị ổn định.',
    );
  }

  Widget _buildTeamsTab(List<SupportTeam> teams, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.group,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        team.name ?? 'Phòng ban',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (team.teamNote != null && team.teamNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    team.teamNote!,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
