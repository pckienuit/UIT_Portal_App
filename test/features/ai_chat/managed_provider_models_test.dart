import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/managed_provider_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  test('normalizes, dedupes, and splits provider-scoped managed models', () {
    final result = resolveManagedProviderModelsForDefinition(
      _definition(
        models: const [
          RouterModelDefinition(id: ' built-in ', name: 'Built in'),
        ],
      ),
      const AiProviderModelSettings(
        providerKey: 'custom',
        customModels: [AiProviderModelDescriptor(id: 'custom', name: 'Custom')],
        disabledModelIds: {'custom', 'hidden-refresh'},
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
    expect(result.hidden.map((model) => model.id), [
      'custom',
      'hidden-refresh',
    ]);
    expect(result.refreshed.map((model) => model.id), ['suggestion']);
    expect(result.visible.first.builtIn, isTrue);
    expect(result.visible.first.refreshed, isTrue);
    expect(result.visible.first.capabilities.reasoning, isTrue);
    expect(
      result.hidden.firstWhere((model) => model.id == 'custom').custom,
      isTrue,
    );
  });

  test('Antigravity keeps exactly locked registry IDs', () {
    final result = resolveManagedProviderModelsForDefinition(
      _definition(
        id: 'antigravity',
        models: const [
          RouterModelDefinition(id: 'locked-one', name: 'Locked one'),
          RouterModelDefinition(id: 'locked-two', name: 'Locked two'),
        ],
      ),
      const AiProviderModelSettings(
        providerKey: 'ag',
        customModels: [AiProviderModelDescriptor(id: 'custom', name: 'Custom')],
        disabledModelIds: {'locked-two', 'unknown-hidden'},
      ),
      const [
        AiModelOption(id: 'locked-one', name: 'Live locked one'),
        AiModelOption(id: 'unknown-live', name: 'Unknown live'),
      ],
    );

    expect(result.visible.map((model) => model.id), ['locked-one']);
    expect(result.hidden.map((model) => model.id), ['locked-two']);
    expect(result.visible.single.refreshed, isTrue);
  });
}

RouterProviderDefinition _definition({
  String id = 'custom',
  List<RouterModelDefinition> models = const [],
}) => RouterProviderDefinition(
  id: id,
  name: id,
  category: RouterProviderCategory.custom,
  authModes: const [],
  models: models,
);
