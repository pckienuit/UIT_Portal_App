import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_manager_sheet.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  testWidgets('Antigravity uses one model catalog and permits custom models', (
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
        {
          'id': 'antigravity-work',
          'name': 'Antigravity Work',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://example.test/v1',
          'presetId': 'antigravity',
        },
      ]),
      'ai_provider_model_settings_v1': jsonEncode({
        'version': 1,
        'providers': {
          'ag': const AiProviderModelSettings(
            providerKey: 'ag',
            customModels: [
              AiProviderModelDescriptor(id: 'manual-model', name: 'Manual'),
            ],
          ).toJson(),
        },
      }),
    });
    await RouterCatalog.load('''{"providers":[{
      "id":"antigravity","alias":"ag","name":"Antigravity","category":"oauth",
      "disposition":"ready","mobileSupported":true,"androidAuth":"device",
      "nativeStatus":"ready","transportKind":"githubCopilot",
      "chatUrl":"https://example.test/chat","models":[{"id":"locked","name":"Locked"}]
    }]}''');
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AiModelManagerSheet(providerKey: 'ag')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Models'), findsOneWidget);
    expect(find.text('manual-model'), findsOneWidget);
    expect(find.text('Thêm model'), findsOneWidget);
    expect(find.text('Built-in models'), findsNothing);
    expect(find.text('Live models'), findsNothing);
    expect(find.text('Custom models'), findsNothing);

    await tester.tap(find.text('Thêm model'));
    await tester.pump();

    expect(find.text('Thêm model tùy chỉnh'), findsOneWidget);
    expect(find.text('Test model'), findsOneWidget);
    expect(tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable, isTrue);

    await tester.enterText(find.byType(TextField).last, 'unlisted-model');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Thêm'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
