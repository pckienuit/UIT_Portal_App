import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;
  late _FakeSecureStorage secureStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_screen_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStorage = _FakeSecureStorage();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('renders AiChatScreen and shows no provider welcome state', (
    tester,
  ) async {
    final container = _container(prefs, tempDir, secureStorage);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cấu hình Trợ lý AI'), findsOneWidget);
    expect(find.text('Cấu hình ngay'), findsOneWidget);
  });

  testWidgets('renders AiChatScreen with active provider config', (
    tester,
  ) async {
    final container = _container(prefs, tempDir, secureStorage);
    addTearDown(container.dispose);

    final repo = container.read(aiProviderRepositoryProvider);
    final config = AiProviderConfig(
      id: 'p1',
      name: 'Custom OpenAI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'gpt-4o-mini',
      presetId: 'openai',
    );
    await repo.saveProvider(config, apiKey: 'key');
    await repo.setActiveProviderId('p1');

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Tôi có thể giúp gì cho bạn?'), findsOneWidget);
    expect(find.text('Custom OpenAI · gpt-4o-mini'), findsOneWidget);
    expect(find.text('Nhập tin nhắn...'), findsOneWidget);
  });
}

ProviderContainer _container(
  SharedPreferences prefs,
  Directory tempDir,
  FlutterSecureStorage secureStorage,
) => ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
    secureStorageProvider.overrideWithValue(secureStorage),
    authControllerProvider.overrideWith((ref) => _SignedInAuthController()),
  ],
);

class _SignedInAuthController extends AuthController {
  @override
  AuthStatus get status => AuthStatus.signedIn;
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final key = invocation.namedArguments[#key] as String?;
    if (name.contains('write')) {
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _storage.remove(key);
      } else {
        _storage[key!] = value;
      }
      return Future<void>.value();
    }
    if (name.contains('read')) return Future<String?>.value(_storage[key]);
    if (name.contains('delete')) {
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
