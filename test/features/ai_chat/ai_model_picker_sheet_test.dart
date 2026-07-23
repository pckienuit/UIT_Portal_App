import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_model_picker_sheet.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

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
                onModelSelected: (_) {},
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
              onModelSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('gemini-2.5-flash-lite'), findsNWidgets(2));
    expect(find.text('gemini-2.5-flash'), findsNWidgets(2));
    expect(find.text('Owner: gemini-cli'), findsNWidgets(2));
  });
}
