import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_picker_sheet.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  testWidgets('picker selects canonical model from provider-scoped settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ai_provider_configs_v1': jsonEncode([
        {
          'id': 'github-work',
          'name': 'GitHub Work',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://api.githubcopilot.com',
          'presetId': 'github',
        },
      ]),
      'ai_provider_model_settings_v1': jsonEncode({
        'version': 1,
        'providers': {
          'gh': const AiProviderModelSettings(
            providerKey: 'gh',
            customModels: [],
            disabledModelIds: {},
          ).toJson(),
        },
      }),
    });
    await RouterCatalog.load('''{"providers":[{
      "id":"github","alias":"gh","name":"GitHub","category":"oauth",
      "disposition":"ready","mobileSupported":true,"androidAuth":"device",
      "nativeStatus":"ready","transportKind":"githubCopilot",
      "chatUrl":"https://example.test/chat","models":[{"id":"gpt-5.4","name":"GPT 5.4"}]
    }]}''');
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    String? selectedConnection;
    String? selectedModel;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              currentModelId: '',
              onModelSelected: (connectionId, model) async {
                selectedConnection = connectionId;
                selectedModel = model.canonicalId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('GPT 5.4'));
    await tester.pump();

    expect(selectedConnection, 'github-work');
    expect(selectedModel, 'gh/gpt-5.4');
  });
}
