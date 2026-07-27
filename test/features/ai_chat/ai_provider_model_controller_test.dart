import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_model_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_model_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('model settings mutation does not touch connection preferences', () async {
    SharedPreferences.setMockInitialValues({
      'ai_provider_configs_v1':
          '[{"id":"github-1","name":"GitHub","kind":"openAiCompatible","baseUrl":"https://example.test/v1","modelId":"legacy","presetId":"github"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = AiProviderModelRepository(prefs: prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiProviderModelRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      aiProviderModelControllerProvider.notifier,
    );
    await controller.migrateLegacy([
      const AiProviderConfig(
        id: 'github-1',
        name: 'GitHub',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'legacy',
        presetId: 'github',
      ),
    ]);

    expect(
      await controller.addCustomModel(
        'github-1',
        const AiProviderModelDescriptor(id: 'private-model', name: 'Private'),
      ),
      isTrue,
    );
    expect(await controller.disableModel('github-1', 'legacy'), isTrue);

    expect(
      prefs.getString('ai_provider_configs_v1'),
      '[{"id":"github-1","name":"GitHub","kind":"openAiCompatible","baseUrl":"https://example.test/v1","modelId":"legacy","presetId":"github"}]',
    );
    final settings = repository.listSettings()['github-1']!;
    expect(settings.customModels.single.id, 'private-model');
    expect(settings.disabledModelIds, {'legacy'});
  });
}
