import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_catalog.dart';
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

  testWidgets('renders AiProviderSettingsScreen list and catalog sections', (tester) async {
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

    expect(find.text('Mô hình chạy trên máy (Local offline)'), findsOneWidget);
    expect(find.text('Nhà cung cấp dịch vụ AI (API Providers)'), findsOneWidget);
    expect(find.text('GATEWAY TRUNG GIAN'), findsOneWidget);
    expect(find.text('CÓ FREE QUOTA THỬ NGHIỆM'), findsOneWidget);
    expect(find.text('API CHÍNH THỨC'), findsOneWidget);
    expect(find.text('TÙY CHỈNH ENDPOINT'), findsOneWidget);

    expect(find.text('9Router'), findsOneWidget);
  });
}
