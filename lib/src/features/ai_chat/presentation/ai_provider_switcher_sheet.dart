import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import 'ai_model_picker_sheet.dart';

class AiProviderSwitcherSheet extends ConsumerWidget {
  const AiProviderSwitcherSheet({super.key});

  void _openModelPicker(
    BuildContext context,
    WidgetRef ref,
    String providerId,
    String currentModelId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AiModelPickerSheet(
        providerId: providerId,
        currentModelId: currentModelId,
        onModelSelected: (modelId, pId) async {
          if (ref.read(aiChatControllerProvider).isGenerating) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Vui lòng dừng trả lời hiện tại trước khi đổi model.',
                ),
              ),
            );
            return;
          }
          final targetProviderId = pId ?? providerId;
          await ref
              .read(aiChatControllerProvider.notifier)
              .selectGlobalModel(targetProviderId, modelId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final providerState = ref.watch(aiProviderControllerProvider);
    final chatState = ref.watch(aiChatControllerProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chọn Trợ lý AI',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            SizedBox(height: PortalSpacing.sm),

            if (providerState.providers.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: PortalSpacing.lg),
                child: Text(
                  'Chưa cấu hình dịch vụ AI nào. Vui lòng bấm vào nút Cấu hình ở góc trên màn hình chat.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: providerState.providers.length,
                  itemBuilder: (context, index) {
                    final config = providerState.providers[index];
                    final isActive = chatState.activeProvider?.id == config.id;

                    return ListTile(
                      title: Text(
                        config.name,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Model: ${config.modelId}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      leading: Icon(
                        isActive ? Icons.assistant : Icons.assistant_outlined,
                        color: isActive ? colorScheme.primary : null,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            Icon(Icons.check, color: colorScheme.primary)
                          else
                            const SizedBox.shrink(),
                          IconButton(
                            icon: const Icon(
                              Icons.settings_input_composite_outlined,
                            ),
                            tooltip: 'Chọn Model',
                            onPressed: () {
                              Navigator.of(context).pop();
                              _openModelPicker(
                                context,
                                ref,
                                config.id,
                                config.modelId,
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (chatState.isGenerating) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng dừng trả lời hiện tại trước khi chuyển đổi provider.',
                              ),
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(aiChatControllerProvider.notifier)
                            .switchProvider(config);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
