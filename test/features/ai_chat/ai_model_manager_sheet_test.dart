import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_manager_sheet.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  testWidgets('manages one shared provider catalog without chat selection UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({
      'ai_provider_configs_v1': jsonEncode([
        _connection('github-work', 'GitHub Work'),
        _connection('github-personal', 'GitHub Personal'),
      ]),
      'ai_provider_model_settings_v1': jsonEncode({
        'version': 1,
        'providers': {
          'gh': const AiProviderModelSettings(
            providerKey: 'gh',
            customModels: [],
            disabledModelIds: {'disabled-model'},
          ).toJson(),
        },
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    await RouterCatalog.load('''{"providers":[
      {"id":"github","alias":"gh","name":"GitHub Copilot","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","transportKind":"githubCopilot","chatUrl":"https://api.githubcopilot.com/chat/completions","models":[{"id":"built-in","name":"Built in"},{"id":"disabled-model","name":"Disabled model"}]}
    ]}''');
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AiModelManagerSheet(providerKey: 'gh')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Built-in models'), findsOneWidget);
    expect(find.text('Live models', skipOffstage: false), findsOneWidget);
    expect(find.text('Custom models', skipOffstage: false), findsOneWidget);
    expect(find.text('Disabled models', skipOffstage: false), findsOneWidget);
    expect(find.text('Model:'), findsNothing);
    expect(find.text('Đang dùng'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _connection(String id, String name) => {
  'id': id,
  'name': name,
  'kind': 'openAiCompatible',
  'baseUrl': 'https://api.githubcopilot.com',
  'modelId': 'legacy-model',
  'presetId': 'github',
  'authMode': 'oauth',
};
