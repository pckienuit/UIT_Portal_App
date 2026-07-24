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
                onModelSelected: (_) async {},
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
      expect(
        find.widgetWithText(TextField, 'Nhập Model ID thủ công'),
        findsOneWidget,
      );
      expect(find.text('Áp dụng'), findsOneWidget);
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
              onModelSelected: (modelId) async => selected = modelId,
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
                onModelSelected: (id) async => selected = id,
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
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập Model ID thủ công'),
        'manual-antigravity-id',
      );
      await tester.tap(find.text('Áp dụng'));
      expect(selected, isNull);
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
                onModelSelected: (id) async => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Locked model'), findsOneWidget);
      expect(find.text('Unknown live'), findsNothing);
      expect(
        container
            .read(aiProviderControllerProvider)
            .providers
            .single
            .models
            .map((model) => model.id),
        ['locked-model'],
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập Model ID thủ công'),
        'unknown-live-model',
      );
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(
        container
            .read(aiProviderControllerProvider)
            .providers
            .single
            .customModels,
        isEmpty,
      );
      expect(selected, isNull);
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
              onModelSelected: (_) async {},
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
}
