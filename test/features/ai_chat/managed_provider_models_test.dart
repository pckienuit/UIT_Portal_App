import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/managed_provider_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  test(
    'live catalog overwrites built-in metadata and merges custom models',
    () {
      final result = resolveManagedProviderModelsForDefinition(
        _definition(
          models: const [
            RouterModelDefinition(id: ' built-in ', name: 'Built in'),
          ],
        ),
        const AiProviderModelSettings(
          providerKey: 'custom',
          customModels: [
            AiProviderModelDescriptor(id: 'custom', name: 'Custom'),
            AiProviderModelDescriptor(id: 'manual', name: 'Manual'),
          ],
          disabledModelIds: {'custom', 'hidden-refresh'},
        ),
        const [
          AiModelOption(
            id: 'built-in',
            name: 'Refreshed built in',
            capabilities: AiModelCapabilities(reasoning: true),
          ),
          AiModelOption(id: 'suggestion', name: 'Suggestion'),
          AiModelOption(id: 'manual', name: 'Live manual'),
          AiModelOption(id: 'hidden-refresh', name: 'Hidden refresh'),
        ],
      );

      expect(result.visible.map((model) => model.id), [
        'built-in',
        'manual',
        'suggestion',
      ]);
      expect(result.hidden.map((model) => model.id), [
        'custom',
        'hidden-refresh',
      ]);
      expect(result.visible.first.builtIn, isTrue);
      expect(result.visible.first.refreshed, isTrue);
      expect(result.visible.first.name, 'Refreshed built in');
      expect(result.visible.first.capabilities.reasoning, isTrue);
      final manual = result.visible.firstWhere((model) => model.id == 'manual');
      expect(manual.custom, isTrue);
      expect(manual.refreshed, isTrue);
      expect(manual.name, 'Live manual');
      expect(
        result.visible
            .firstWhere((model) => model.id == 'suggestion')
            .refreshed,
        isTrue,
      );
      expect(
        result.hidden.firstWhere((model) => model.id == 'custom').custom,
        isTrue,
      );
    },
  );

  test('Antigravity keeps custom and all live models in its catalog', () {
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

    expect(result.visible.map((model) => model.id), [
      'locked-one',
      'custom',
      'unknown-live',
    ]);
    expect(result.hidden.map((model) => model.id), [
      'locked-two',
      'unknown-hidden',
    ]);
    expect(
      result.visible.firstWhere((model) => model.id == 'locked-one').refreshed,
      isTrue,
    );
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
