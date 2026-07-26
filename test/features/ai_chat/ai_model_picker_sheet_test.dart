import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_picker_sheet.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'ai_model_picker_sheet_test',
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'renders AiModelPickerSheet and shows search field and custom model button',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerModelCatalogProvider('p1').overrideWith(
            (ref) async => const [
              AiModelOption(
                id: 'model-a',
                name: 'Model A',
                capabilities: AiModelCapabilities(vision: true),
              ),
              AiModelOption(id: 'model-b', name: 'Model B'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Mock models list in controller
      final providerController = container.read(
        aiProviderControllerProvider.notifier,
      );
      providerController.updateProviderModels('p1', [
        const AiModelOption(
          id: 'model-a',
          name: 'Model A',
          capabilities: AiModelCapabilities(vision: true),
        ),
        const AiModelOption(id: 'model-b', name: 'Model B'),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AiModelPickerSheet(
                providerId: 'p1',
                currentModelId: 'model-a',
                onModelSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chọn mô hình (Model)'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Tìm kiếm mô hình...'),
        findsOneWidget,
      );
      expect(find.text('Model A'), findsOneWidget);
      expect(find.text('model-a'), findsOneWidget);
      expect(find.text('Model B'), findsOneWidget);
      expect(find.text('Vision'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Thêm Model'), findsOneWidget);
    },
  );

  testWidgets('shows Antigravity label then model ID without owner text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('provider-antigravity').overrideWith(
          (ref) async => const [
            AiModelOption(
              id: 'claude-sonnet-4-6',
              name: 'Claude Sonnet 4.6 (Thinking)',
              owner: 'antigravity',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: 'provider-antigravity',
              currentModelId: 'claude-sonnet-4-6',
              onModelSelected: (modelId, _) async => selected = modelId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Claude Sonnet 4.6 (Thinking)'), findsOneWidget);
    expect(find.text('claude-sonnet-4-6'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.textContaining('Owner:'), findsNothing);
    await tester.tap(find.text('Claude Sonnet 4.6 (Thinking)'));
    expect(selected, 'claude-sonnet-4-6');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Antigravity live error hides cached catalog and rejects manual ID',
    (tester) async {
      String? selected;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerModelCatalogProvider(
            'provider-antigravity',
          ).overrideWith((ref) async => throw StateError('upstream forbidden')),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(aiProviderControllerProvider.notifier)
          .updateProviderModels('provider-antigravity', const [
            AiModelOption(id: 'catalog-only', name: 'Catalog only'),
          ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AiModelPickerSheet(
                providerId: 'provider-antigravity',
                currentModelId: 'catalog-only',
                onModelSelected: (id, _) async => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catalog only'), findsNothing);
      expect(
        find.text('Không thể tải danh sách mô hình khả dụng.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
    },
  );

  testWidgets(
    'Antigravity manual locked live model saves and selects exactly once',
    (tester) async {
      await RouterCatalog.load(
        jsonEncode({
          'providers': [
            {
              'id': 'antigravity',
              'name': 'Antigravity',
              'category': 'oauth',
              'disposition': 'ready',
              'mobileSupported': true,
              'models': [
                {'id': 'locked-model', 'name': 'Locked model'},
              ],
            },
          ],
        }),
      );
      await prefs.setString(
        'ai_provider_configs_v1',
        jsonEncode([
          {
            'id': 'provider-antigravity',
            'name': 'Antigravity',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://example.test/v1',
            'modelId': 'locked-model',
            'presetId': 'antigravity',
            'models': [
              {'id': 'locked-model', 'name': 'Locked model'},
            ],
          },
        ]),
      );
      String? selected;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerModelCatalogProvider('provider-antigravity').overrideWith(
            (ref) async => const [
              AiModelOption(id: 'locked-model', name: 'Locked model'),
              AiModelOption(id: 'unknown-live-model', name: 'Unknown live'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(
        routerModelCatalogProvider('provider-antigravity').future,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AiModelPickerSheet(
                providerId: 'provider-antigravity',
                currentModelId: 'locked-model',
                onModelSelected: (id, _) async => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Locked model'), findsOneWidget);
      expect(find.text('Unknown live'), findsNothing);
    },
  );

  testWidgets('loads live models from embedded router', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('provider-gemini-cli').overrideWith(
          (ref) async => const [
            AiModelOption(
              id: 'gemini-2.5-flash-lite',
              name: 'gemini-2.5-flash-lite',
              owner: 'gemini-cli',
            ),
            AiModelOption(
              id: 'gemini-2.5-flash',
              name: 'gemini-2.5-flash',
              owner: 'gemini-cli',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: 'provider-gemini-cli',
              currentModelId: 'gemini-2.5-flash',
              onModelSelected: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('gemini-2.5-flash-lite'), findsNWidgets(2));
    expect(find.text('gemini-2.5-flash'), findsNWidgets(2));
    expect(find.textContaining('Owner:'), findsNothing);
  });

  testWidgets('custom model added is displayed in both per-provider and global modes', (tester) async {
    await prefs.setString(
      'ai_provider_configs_v1',
      jsonEncode([
        {
          'id': 'provider-custom-1',
          'name': 'Custom Provider 1',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://custom.api/v1',
          'modelId': 'base-model',
          'presetId': 'custom',
          'models': [
            {'id': 'base-model', 'name': 'Base Model'},
          ],
          'customModels': [],
        },
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('provider-custom-1').overrideWith(
          (ref) async => const [
            AiModelOption(id: 'base-model', name: 'Base Model'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    // 1. Open in per-provider mode
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: 'provider-custom-1',
              currentModelId: 'base-model',
              onModelSelected: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base Model'), findsOneWidget);
    expect(find.text('new-added-model'), findsNothing);

    // 2. Add custom model via controller
    final controller = container.read(aiProviderControllerProvider.notifier);
    final success = await controller.addCustomModel('provider-custom-1', 'new-added-model');
    expect(success, isTrue);

    await tester.pumpAndSettle();

    // 3. Verify it shows in per-provider picker
    expect(find.text('new-added-model'), findsWidgets);

    // 4. Open in global mode
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: null, // Global mode
              currentModelId: 'base-model',
              onModelSelected: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('new-added-model'), findsWidgets);
    expect(find.textContaining('Provider: Custom Provider 1'), findsWidgets);
  });

  testWidgets('global picker does not expose add model action', (tester) async {
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
              providerId: null,
              currentModelId: '',
              onModelSelected: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Thêm Model'), findsNothing);
  });

  testWidgets('add model stays disabled until current model test succeeds', (
    tester,
  ) async {
    await prefs.setString(
      'ai_provider_configs_v1',
      jsonEncode([
        {
          'id': 'inactive-provider',
          'name': 'Inactive Provider',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://unused.test/v1',
          'modelId': 'base-model',
          'presetId': 'custom',
        },
      ]),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('inactive-provider').overrideWith(
          (ref) async => const <AiModelOption>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: 'inactive-provider',
              currentModelId: 'base-model',
              onModelSelected: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm Model'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Model ID'),
      'tested-model',
    );

    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Thêm model'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets('changing model ID resets successful test eligibility', (
    tester,
  ) async {
    await prefs.setString(
      'ai_provider_configs_v1',
      jsonEncode([
        {
          'id': 'inactive-provider',
          'name': 'Inactive Provider',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://unused.test/v1',
          'modelId': 'base-model',
          'presetId': 'custom',
        },
      ]),
    );
    final testedIds = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerModelCatalogProvider('inactive-provider').overrideWith(
          (ref) async => const <AiModelOption>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AiModelPickerSheet(
              providerId: 'inactive-provider',
              currentModelId: 'base-model',
              onModelSelected: (_, __) async {},
              modelTester: (config, modelId) async {
                testedIds.add(modelId);
                return const AiConnectionResult(success: true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm Model'));
    await tester.pumpAndSettle();
    final modelField = find.widgetWithText(TextFormField, 'Model ID');
    await tester.enterText(modelField, 'tested-model');
    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(testedIds, ['tested-model']);
    expect(find.textContaining('tested-model!'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Thêm model'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.enterText(modelField, 'changed-model');
    await tester.pump();
    expect(
      find.text('Model ID được gửi tới provider: changed-model'),
      findsOneWidget,
    );

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Thêm model'),
          )
          .onPressed,
      isNull,
    );
  });
}
