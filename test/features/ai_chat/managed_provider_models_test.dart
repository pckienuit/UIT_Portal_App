import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/managed_provider_models.dart';

void main() {
  test('normalizes, dedupes, and splits managed models', () {
    final result = resolveManagedProviderModels(
      _config(
        models: const [
          AiProviderModelDescriptor(id: ' built-in ', name: 'Built in'),
        ],
        customModels: const [
          AiProviderModelDescriptor(id: 'custom', name: 'Custom'),
        ],
        hiddenModelIds: const [' custom ', 'hidden-refresh'],
      ),
      const [
        AiModelOption(
          id: 'built-in',
          name: 'Refreshed built in',
          capabilities: AiModelCapabilities(reasoning: true),
        ),
        AiModelOption(id: 'suggestion', name: 'Suggestion'),
        AiModelOption(id: 'hidden-refresh', name: 'Hidden refresh'),
      ],
    );

    expect(result.visible.map((model) => model.id), ['built-in']);
    expect(result.hidden.map((model) => model.id), ['custom']);
    expect(result.refreshed.map((model) => model.id), ['suggestion']);
    expect(result.visible.first.builtIn, isTrue);
    expect(result.visible.first.refreshed, isFalse);
    expect(result.visible.first.managed, isTrue);
    expect(result.refreshed.single.managed, isFalse);
    expect(result.hidden.single.custom, isTrue);
  });

  test('Antigravity keeps exactly locked static ids', () {
    final result = resolveManagedProviderModels(
      _config(
        presetId: 'antigravity',
        models: const [
          AiProviderModelDescriptor(id: 'locked-one', name: 'Locked one'),
          AiProviderModelDescriptor(id: 'locked-two', name: 'Locked two'),
        ],
        customModels: const [
          AiProviderModelDescriptor(id: 'custom', name: 'Custom'),
        ],
        hiddenModelIds: const ['locked-two', 'unknown-hidden'],
      ),
      const [
        AiModelOption(id: 'locked-one', name: 'Live locked one'),
        AiModelOption(id: 'unknown-live', name: 'Unknown live'),
      ],
    );

    expect(result.visible.map((model) => model.id), ['locked-one']);
    expect(result.hidden.map((model) => model.id), ['locked-two']);
    expect(result.visible.single.refreshed, isTrue);
    expect(result.visible.single.name, 'Locked one');
  });
}

AiProviderConfig _config({
  String presetId = 'custom',
  List<AiProviderModelDescriptor> models = const [],
  List<AiProviderModelDescriptor> customModels = const [],
  List<String> hiddenModelIds = const [],
}) => AiProviderConfig(
  id: 'provider',
  name: 'Provider',
  kind: AiBackendKind.openAiCompatible,
  baseUrl: 'https://example.test/v1',
  modelId: 'built-in',
  presetId: presetId,
  models: models,
  customModels: customModels,
  hiddenModelIds: hiddenModelIds,
);
