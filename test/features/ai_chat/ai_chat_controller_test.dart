import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late _FakeSecureStorage fakeSecureStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_controller_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeSecureStorage = _FakeSecureStorage();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('initializes with active provider and loaded history', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
      ],
    );
    addTearDown(container.dispose);

    // Lưu một provider config giả lập vào prefs trước
    final repo = container.read(aiProviderRepositoryProvider);
    final config = AiProviderConfig(
      id: 'p1',
      name: 'Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'm1',
    );
    await repo.saveProvider(config, apiKey: 'mock-api-key');
    await repo.setActiveProviderId('p1');

    // Đọc provider để trigger build() và _init()
    final initial = container.read(aiChatControllerProvider);
    expect(initial.activeProvider, isNull); // Ban đầu là null do chạy async

    // Đợi async store & history load xong
    await Future.delayed(const Duration(milliseconds: 50));

    final state = container.read(aiChatControllerProvider);
    expect(state.activeProvider?.id, 'p1');
    expect(state.conversations, isEmpty);
    expect(state.activeConversation, isNull);
  });
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('write')) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _storage.remove(key);
      } else {
        _storage[key] = value;
      }
      return Future<void>.value();
    } else if (name.contains('read')) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(_storage[key]);
    } else if (name.contains('delete')) {
      final key = invocation.namedArguments[#key] as String;
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
