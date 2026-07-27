import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_model_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'migrates legacy model fields once then removes them from connections',
    () async {
      await prefs.setString(
        'ai_provider_configs_v1',
        jsonEncode([
          {
            'id': 'github-a',
            'name': 'GitHub A',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://example.test/v1',
            'modelId': 'gpt-5.4',
            'presetId': 'github',
            'customModels': [
              {'id': ' private ', 'name': 'Private'},
            ],
            'hiddenModelIds': [' retired '],
          },
          {
            'id': 'github-b',
            'name': 'GitHub B',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://example.test/v1',
            'presetId': 'github',
            'customModels': [
              {'id': 'private', 'name': 'Other'},
              {'id': 'second', 'name': 'Second'},
            ],
            'hiddenModelIds': ['private'],
          },
        ]),
      );
      final repository = AiProviderModelRepository(prefs: prefs);

      final first = await repository.migrateLegacy(
        providerKeyFor: (presetId, connectionId) =>
            presetId == 'github' ? 'gh' : connectionId,
      );
      final second = await repository.migrateLegacy(
        providerKeyFor: (presetId, connectionId) =>
            presetId == 'github' ? 'gh' : connectionId,
      );

      expect(first['gh']!.customModels.map((model) => model.id), [
        'private',
        'second',
      ]);
      expect(first['gh']!.disabledModelIds, {'retired', 'private'});
      expect(second['gh']!.disabledModelIds, {'retired', 'private'});
      final raw = prefs.getString('ai_provider_configs_v1')!;
      expect(raw, isNot(contains('modelId')));
      expect(raw, isNot(contains('customModels')));
      expect(raw, isNot(contains('hiddenModelIds')));
    },
  );

  test(
    'drops ambiguous legacy custom settings instead of leaking across connections',
    () async {
      await prefs.setString(
        'ai_provider_configs_v1',
        jsonEncode([
          {
            'id': 'custom-one',
            'name': 'Custom one',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://one.example.test/v1',
            'presetId': 'custom',
          },
          {
            'id': 'custom-two',
            'name': 'Custom two',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://two.example.test/v1',
            'presetId': 'custom',
          },
        ]),
      );
      await prefs.setString(
        'ai_provider_model_settings_v1',
        jsonEncode({
          'version': 1,
          'providers': {
            'custom': {
              'customModels': [
                {'id': 'legacy-model', 'name': 'Legacy'},
              ],
              'disabledModelIds': ['disabled-model'],
            },
          },
        }),
      );
      final repository = AiProviderModelRepository(prefs: prefs);

      final settings = await repository.migrateLegacy(
        providerKeyFor: (presetId, connectionId) =>
            presetId == 'custom' ? connectionId : presetId,
      );

      expect(settings.containsKey('custom-one'), isFalse);
      expect(settings.containsKey('custom-two'), isFalse);
      expect(settings.containsKey('custom'), isFalse);
    },
  );

  test('drops orphaned legacy custom settings without connections', () async {
    await prefs.setString(
      'ai_provider_model_settings_v1',
      jsonEncode({
        'version': 1,
        'providers': {
          'custom': {
            'customModels': [
              {'id': 'legacy-model', 'name': 'Legacy'},
            ],
            'disabledModelIds': ['disabled-model'],
          },
        },
      }),
    );
    final repository = AiProviderModelRepository(prefs: prefs);

    final settings = await repository.migrateLegacy(
      providerKeyFor: (_, connectionId) => connectionId,
    );

    expect(settings.containsKey('custom'), isFalse);
    expect(repository.listSettings().containsKey('custom'), isFalse);
  });

  test('moves legacy custom settings to its sole custom connection', () async {
    await prefs.setString(
      'ai_provider_configs_v1',
      jsonEncode([
        {
          'id': 'custom-one',
          'name': 'Custom one',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://one.example.test/v1',
          'presetId': 'custom',
        },
      ]),
    );
    await prefs.setString(
      'ai_provider_model_settings_v1',
      jsonEncode({
        'version': 1,
        'providers': {
          'custom': {
            'customModels': [
              {'id': 'legacy-model', 'name': 'Legacy'},
            ],
            'disabledModelIds': ['disabled-model'],
          },
        },
      }),
    );
    final repository = AiProviderModelRepository(prefs: prefs);

    final settings = await repository.migrateLegacy(
      providerKeyFor: (presetId, connectionId) =>
          presetId == 'custom' ? connectionId : presetId,
    );

    expect(settings.containsKey('custom'), isFalse);
    expect(settings['custom-one']!.customModels.single.id, 'legacy-model');
    expect(settings['custom-one']!.disabledModelIds, {'disabled-model'});
  });

  test('keeps model settings isolated by provider key', () async {
    final repository = AiProviderModelRepository(prefs: prefs);
    await repository.save(
      const AiProviderModelSettings(
        providerKey: 'custom-a',
        customModels: [],
        disabledModelIds: {'model-a'},
      ),
    );
    await repository.save(
      const AiProviderModelSettings(
        providerKey: 'custom-b',
        disabledModelIds: {'model-b'},
      ),
    );

    final settings = repository.listSettings();
    expect(settings['custom-a']!.disabledModelIds, {'model-a'});
    expect(settings['custom-b']!.disabledModelIds, {'model-b'});
  });
}
