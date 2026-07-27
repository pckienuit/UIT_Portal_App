import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_model_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'migrates same-provider connection model metadata into shared settings once',
    () async {
      final repository = AiProviderModelRepository(prefs: prefs);
      final connections = [
        _connection(
          id: 'github-1',
          presetId: 'github',
          customModels: const [
            AiProviderModelDescriptor(id: ' private ', name: 'Private'),
          ],
          hiddenModelIds: const [' retired '],
        ),
        _connection(
          id: 'github-2',
          presetId: 'github',
          customModels: const [
            AiProviderModelDescriptor(id: 'private', name: 'Other name'),
            AiProviderModelDescriptor(id: 'second', name: 'Second'),
          ],
          hiddenModelIds: const ['private'],
        ),
      ];

      final first = await repository.migrateLegacy(
        connections,
        providerKeyFor: (connection) =>
            connection.presetId == 'github' ? 'gh' : connection.id,
      );
      final second = await repository.migrateLegacy(
        connections,
        providerKeyFor: (connection) =>
            connection.presetId == 'github' ? 'gh' : connection.id,
      );

      expect(first['gh']!.customModels.map((model) => model.id), [
        'private',
        'second',
      ]);
      expect(first['gh']!.disabledModelIds, {'retired', 'private'});
      expect(second['gh']!.customModels.map((model) => model.id), [
        'private',
        'second',
      ]);
      expect(second['gh']!.disabledModelIds, {'retired', 'private'});
      final raw =
          jsonDecode(prefs.getString('ai_provider_model_settings_v1')!)
              as Map<String, dynamic>;
      expect(raw['version'], 1);
    },
  );

  test(
    'keeps custom endpoint model settings isolated by stable provider key',
    () async {
      final repository = AiProviderModelRepository(prefs: prefs);

      await repository.save(
        const AiProviderModelSettings(
          providerKey: 'custom-lab-a',
          customModels: [AiProviderModelDescriptor(id: 'model-a', name: 'A')],
        ),
      );
      await repository.save(
        const AiProviderModelSettings(
          providerKey: 'custom-lab-b',
          disabledModelIds: {'model-b'},
        ),
      );

      final settings = repository.listSettings();
      expect(settings['custom-lab-a']!.customModels.single.id, 'model-a');
      expect(settings['custom-lab-b']!.disabledModelIds, {'model-b'});
    },
  );
}

AiProviderConfig _connection({
  required String id,
  required String presetId,
  List<AiProviderModelDescriptor> customModels = const [],
  List<String> hiddenModelIds = const [],
}) => AiProviderConfig(
  id: id,
  name: id,
  kind: AiBackendKind.openAiCompatible,
  baseUrl: 'https://example.test/v1',
  modelId: 'legacy-model',
  presetId: presetId,
  customModels: customModels,
  hiddenModelIds: hiddenModelIds,
);
