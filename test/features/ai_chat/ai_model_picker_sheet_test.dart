import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_manager_sheet.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_picker_sheet.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'global picker uses managed cache without reading router catalog',
    (tester) async {
      await _seedProviders(prefs, [
        _provider(
          id: 'provider-one',
          modelId: 'built-in',
          models: const [
            {'id': 'built-in', 'name': 'Built in'},
            {'id': 'hidden-built-in', 'name': 'Hidden built in'},
          ],
          customModels: const [
            {'id': 'custom-model', 'name': 'Custom model'},
          ],
          hiddenModelIds: const ['hidden-built-in'],
        ),
      ]);
      var catalogReads = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerModelCatalogProvider('provider-one').overrideWith((ref) async {
            catalogReads++;
            throw StateError('picker must not read router catalog');
          }),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(aiProviderControllerProvider.notifier)
          .updateProviderModels('provider-one', const [
            AiModelOption(
              id: 'built-in',
              name: 'Refreshed built in',
              capabilities: AiModelCapabilities(vision: true),
            ),
            AiModelOption(id: 'raw-refresh', name: 'Raw refresh'),
          ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AiModelPickerSheet(
                currentModelId: 'built-in',
                onModelSelected: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Built in'), findsOneWidget);
      expect(find.text('Custom model'), findsOneWidget);
      expect(find.text('Vision'), findsOneWidget);
      expect(find.text('Hidden built in'), findsNothing);
      expect(find.text('Raw refresh'), findsNothing);
      expect(catalogReads, 0);
    },
  );

  testWidgets('Antigravity picker shows only visible locked static models', (
    tester,
  ) async {
    await _seedProviders(prefs, [
      _provider(
        id: 'provider-antigravity',
        modelId: 'locked-one',
        presetId: 'antigravity',
        models: const [
          {'id': 'locked-one', 'name': 'Locked one'},
          {'id': 'locked-two', 'name': 'Locked two'},
        ],
        customModels: const [
          {'id': 'forbidden-custom', 'name': 'Forbidden custom'},
        ],
        hiddenModelIds: const ['locked-two'],
      ),
    ]);
    var catalogReads = 0;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('provider-antigravity').overrideWith((
          ref,
        ) async {
          catalogReads++;
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(aiProviderControllerProvider.notifier)
        .updateProviderModels('provider-antigravity', const [
          AiModelOption(id: 'locked-one', name: 'Live locked one'),
          AiModelOption(id: 'unknown-live', name: 'Unknown live'),
        ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              currentModelId: 'locked-one',
              onModelSelected: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Locked one'), findsOneWidget);
    expect(find.text('Locked two'), findsNothing);
    expect(find.text('Unknown live'), findsNothing);
    expect(find.text('Forbidden custom'), findsNothing);
    expect(catalogReads, 0);
  });

  testWidgets('custom model selection does not rewrite provider default', (
    tester,
  ) async {
    await _seedProviders(prefs, [
      _provider(
        id: 'provider-one',
        modelId: 'built-in',
        models: const [
          {'id': 'built-in', 'name': 'Built in'},
        ],
        customModels: const [
          {'id': 'custom-model', 'name': 'Custom model'},
        ],
      ),
    ]);
    String? selectedModel;
    String? selectedProvider;
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              currentModelId: 'built-in',
              onModelSelected: (modelId, providerId) async {
                selectedModel = modelId;
                selectedProvider = providerId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Custom model'));
    await tester.pump();

    expect(selectedModel, 'custom-model');
    expect(selectedProvider, 'provider-one');
    expect(
      container.read(aiProviderControllerProvider).providers.single.modelId,
      'built-in',
    );
  });

  testWidgets('manager shows cached refresh as suggestion with exact label', (
    tester,
  ) async {
    await _seedProviders(prefs, [
      _provider(
        id: 'provider-one',
        modelId: 'built-in',
        models: const [
          {'id': 'built-in', 'name': 'Built in'},
        ],
      ),
    ]);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(aiProviderControllerProvider.notifier).updateProviderModels(
      'provider-one',
      const [AiModelOption(id: 'suggested-model', name: 'Suggested model')],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AiModelManagerSheet(providerId: 'provider-one')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Làm mới từ provider'), findsOneWidget);
    expect(find.text('Built in'), findsOneWidget);
    expect(find.text('Suggested model', skipOffstage: false), findsOneWidget);
    expect(find.text('Đã làm mới', skipOffstage: false), findsOneWidget);
    expect(
      container.read(aiProviderControllerProvider).providers.single.modelId,
      'built-in',
    );
  });
}

Future<void> _seedProviders(
  SharedPreferences prefs,
  List<Map<String, Object?>> providers,
) => prefs.setString('ai_provider_configs_v1', jsonEncode(providers));

Map<String, Object?> _provider({
  required String id,
  required String modelId,
  String presetId = 'custom',
  List<Map<String, String>> models = const [],
  List<Map<String, String>> customModels = const [],
  List<String> hiddenModelIds = const [],
}) => {
  'id': id,
  'name': id,
  'kind': 'openAiCompatible',
  'baseUrl': 'https://example.test/v1',
  'modelId': modelId,
  'presetId': presetId,
  'models': models,
  'customModels': customModels,
  'hiddenModelIds': hiddenModelIds,
};
