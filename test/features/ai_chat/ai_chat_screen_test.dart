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

  testWidgets('composer does not double-apply keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container(prefs, tempDir, secureStorage);
    addTearDown(container.dispose);
    final repo = container.read(aiProviderRepositoryProvider);
    const config = AiProviderConfig(
      id: 'p1',
      name: 'Gemini CLI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'gemini-2.5-flash',
    );
    await repo.saveProvider(config);
    await repo.setActiveProviderId(config.id);
    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: child!,
          ),
          home: const AiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nhập tin nhắn...'), findsOneWidget);
  });

  testWidgets('preserves Vietnamese IME text', (tester) async {
    final container = _container(prefs, tempDir, secureStorage);
    addTearDown(container.dispose);
    final repo = container.read(aiProviderRepositoryProvider);
    const config = AiProviderConfig(
      id: 'p1',
      name: 'Gemini CLI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://127.0.0.1:1/v1',
      modelId: 'gemini-2.5-flash',
    );
    await repo.saveProvider(config);
    await repo.setActiveProviderId(config.id);
    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    const vietnamese = 'Tiếng Việt có dấu: lịch học ngày mai thế nào?';
    await tester.enterText(find.byType(TextField), vietnamese);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, vietnamese);
    expect(tester.takeException(), isNull);
  });

  test('commits Vietnamese IME composition before submitting', () {
    const text = 'Tiếng Việt';
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: 0, end: text.length),
      ),
    );

    expect(commitComposerText(controller), text);
    expect(controller.value.composing, TextRange.empty);
    controller.dispose();
  });

  testWidgets('thinking and chatting indicators animate', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [AiThinkingIndicator(), AiStreamingCursor()]),
        ),
      ),
    );
    expect(find.text('Đang suy nghĩ'), findsOneWidget);
    expect(find.byType(AiStreamingCursor), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('newline IME action keeps Vietnamese composition in composer', (
    tester,
  ) async {
    final container = _container(prefs, tempDir, secureStorage);
    addTearDown(container.dispose);
    final repo = container.read(aiProviderRepositoryProvider);
    const config = AiProviderConfig(
      id: 'p1',
      name: 'Gemini CLI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://127.0.0.1:1/v1',
      modelId: 'gemini-2.5-flash',
    );
    await repo.saveProvider(config);
    await repo.setActiveProviderId(config.id);
    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    const vietnamese = 'Tiếng Việt có dấu';
    await tester.enterText(find.byType(TextField), vietnamese);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, vietnamese);
    expect(find.text('Đang suy nghĩ'), findsNothing);
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
