import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakeSecureStorage fakeSecureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeSecureStorage = _FakeSecureStorage();
  });

  test('AiProviderController manages CRUD and active selection correctly', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(aiProviderControllerProvider.notifier);
    expect(container.read(aiProviderControllerProvider).providers, isEmpty);
    expect(container.read(aiProviderControllerProvider).activeProviderId, isNull);

    // Add provider
    final c1 = AiProviderConfig(
      id: 'p1',
      name: 'Provider 1',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost/v1',
      modelId: 'm1',
      presetId: 'openai',
    );
    await controller.saveProvider(c1);

    var state = container.read(aiProviderControllerProvider);
    expect(state.providers.length, 1);
    expect(state.providers.first.id, 'p1');
    expect(state.activeProviderId, 'p1');

    // Add second provider
    final c2 = AiProviderConfig(
      id: 'p2',
      name: 'Provider 2',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost/v2',
      modelId: 'm2',
      presetId: '9router',
    );
    await controller.saveProvider(c2);

    state = container.read(aiProviderControllerProvider);
    expect(state.providers.length, 2);
    expect(state.activeProviderId, 'p1');

    // Switch active
    await controller.selectActiveProvider('p2');
    expect(container.read(aiProviderControllerProvider).activeProviderId, 'p2');

    // Delete active provider p2
    await controller.deleteProvider('p2');
    state = container.read(aiProviderControllerProvider);
    expect(state.providers.length, 1);
    expect(state.activeProviderId, 'p1');

    // Delete final provider
    await controller.deleteProvider('p1');
    state = container.read(aiProviderControllerProvider);
    expect(state.providers, isEmpty);
    expect(state.activeProviderId, isNull);
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
