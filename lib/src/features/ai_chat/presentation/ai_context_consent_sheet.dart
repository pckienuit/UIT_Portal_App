import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_portal_context_builder.dart';
import '../domain/ai_chat_backend.dart';

class AiContextConsentSheet extends ConsumerStatefulWidget {
  const AiContextConsentSheet({
    super.key,
    required this.initialSections,
    required this.onSelectionChanged,
  });

  final Set<AiPortalContextSection> initialSections;
  final void Function(
    Set<AiPortalContextSection> sections,
    AiPortalContextSnapshot snapshot,
  )
  onSelectionChanged;

  @override
  ConsumerState<AiContextConsentSheet> createState() =>
      _AiContextConsentSheetState();
}

class _AiContextConsentSheetState extends ConsumerState<AiContextConsentSheet> {
  late Set<AiPortalContextSection> _sections = {...widget.initialSections};
  AiPortalContextSnapshot? _snapshot;
  bool _loading = false;

  bool get _allSelected =>
      _sections.length == AiPortalContextSection.values.length;

  @override
  void initState() {
    super.initState();
    if (_sections.isNotEmpty) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelected());
    }
  }

  Future<void> _loadSelected() async {
    setState(() => _loading = true);
    final snapshot = await const AiPortalContextBuilder().preload(
      ref,
      _sections,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _setAll(bool selected) async {
    setState(() {
      _sections = selected ? AiPortalContextSection.values.toSet() : {};
      if (!selected) _snapshot = null;
    });
    if (selected) await _loadSelected();
  }

  Future<void> _setSection(
    AiPortalContextSection section,
    bool selected,
  ) async {
    setState(() {
      if (selected) {
        _sections.add(section);
      } else {
        _sections.remove(section);
      }
    });
    await _loadSelected();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snapshot =
        (_snapshot ??
                const AiPortalContextBuilder().buildSnapshot(
                  ref,
                  sections: _sections,
                ))
            .select(_sections);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: PortalSpacing.lg,
          right: PortalSpacing.lg,
          top: PortalSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + PortalSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chia sẻ ngữ cảnh với AI',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'Chọn chính xác dữ liệu gửi kèm tin nhắn này. Có thể đổi bất cứ lúc nào.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: PortalSpacing.sm),
              Card(
                color: colorScheme.surfaceContainerLow,
                child: CheckboxListTile(
                  value: _allSelected,
                  onChanged: _loading
                      ? null
                      : (value) => _setAll(value == true),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Chia sẻ tất cả dữ liệu Portal'),
                  subtitle: const Text(
                    'Chọn toàn bộ 22 dịch vụ Portal. Mỗi dịch vụ chỉ gửi tóm tắt an toàn đã tải.',
                  ),
                ),
              ),
              const SizedBox(height: PortalSpacing.xs),
              Expanded(
                child: ListView(
                  children: [
                    for (final section in AiPortalContextSection.values)
                      CheckboxListTile(
                        value: _sections.contains(section),
                        onChanged: _loading
                            ? null
                            : (value) => _setSection(section, value == true),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(section.contextLabel),
                        subtitle: Text(section.contextNote),
                      ),
                    const SizedBox(height: PortalSpacing.sm),
                    Text(
                      _loading
                          ? 'Đang tải dữ liệu đã chọn...'
                          : 'Xem trước dữ liệu được gửi',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: PortalSpacing.xs),
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(PortalSpacing.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: SelectableText(
                        _buildPreviewText(snapshot),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: PortalSpacing.md),
                    const _PrivacyNotice(),
                  ],
                ),
              ),
              const SizedBox(height: PortalSpacing.md),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () {
                        widget.onSelectionChanged({..._sections}, snapshot);
                        Navigator.of(context).pop();
                      },
                child: Text(
                  _sections.isEmpty ? 'Không chia sẻ ngữ cảnh' : 'Lưu lựa chọn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText(AiPortalContextSnapshot snapshot) {
    final instruction = snapshot.buildSystemInstruction();
    const marker =
        'Dưới đây là dữ liệu học tập cá nhân của sinh viên hiện tại (đã được sinh viên đồng ý chia sẻ):\n';
    return instruction.replaceFirst(marker, '');
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.shield_outlined, color: Colors.green),
      SizedBox(width: PortalSpacing.sm),
      Expanded(
        child: Text(
          'Không chia sẻ mật khẩu, token, session, API key, lịch sử chat hoặc dữ liệu chưa chọn.',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
