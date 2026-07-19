import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_provider_settings_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_provider_settings_screen_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('renders AiProviderSettingsScreen form', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AiProviderSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API Provider OpenAI-Compatible'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Tên Provider'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Base URL'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'API Key'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Model ID'), findsOneWidget);
    expect(find.text('Lưu cấu hình'), findsOneWidget);
  });
}
