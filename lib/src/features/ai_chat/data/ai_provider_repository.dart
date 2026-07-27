import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/providers/widget_preferences_provider.dart';
import '../domain/ai_chat_models.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class AiProviderRepository {
  AiProviderRepository({required this.prefs, required this.secureStorage});

  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;

  static const String _kConfigsKey = 'ai_provider_configs_v1';
  static const String _kSecretPrefix = 'ai_provider_key_';
  static const String _kSourcePrefix = 'ai_provider_source_';

  List<AiProviderConfig> listProviders() {
    final raw = prefs.getString(_kConfigsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AiProviderConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }


  Future<void> saveProvider(
    AiProviderConfig config, {
    String? apiKey,
    String? oauthAccessToken,
    String? oauthRefreshToken,
    String? oauthSourceToken,
  }) async {
    final current = listProviders();
    final index = current.indexWhere((e) => e.id == config.id);
    if (index >= 0) {
      current[index] = config;
    } else {
      current.add(config);
    }

    await prefs.setString(
      _kConfigsKey,
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );

    final accessToken = oauthAccessToken ?? apiKey;
    if (accessToken != null) {
      await secureStorage.write(
        key: '$_kSecretPrefix${config.id}',
        value: accessToken,
      );
    }
    final sourceToken = oauthSourceToken ?? oauthRefreshToken;
    if (sourceToken != null) {
      await secureStorage.write(
        key: '$_kSourcePrefix${config.id}',
        value: sourceToken,
      );
    }
  }

  Future<void> deleteProvider(String id) async {
    final current = listProviders();
    current.removeWhere((e) => e.id == id);
    await prefs.setString(
      _kConfigsKey,
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
    await secureStorage.delete(key: '$_kSecretPrefix$id');
    await secureStorage.delete(key: '$_kSourcePrefix$id');


  }

  Future<String?> getApiKey(String id) async {
    return await secureStorage.read(key: '$_kSecretPrefix$id');
  }

  Future<String?> getOAuthSourceToken(String id) async {
    return secureStorage.read(key: '$_kSourcePrefix$id');
  }

  Future<void> clearAll() async {
    final providers = listProviders();
    for (final p in providers) {
      await secureStorage.delete(key: '$_kSecretPrefix${p.id}');
      await secureStorage.delete(key: '$_kSourcePrefix${p.id}');
    }
    await prefs.remove(_kConfigsKey);
  }
}

final aiProviderRepositoryProvider = Provider<AiProviderRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AiProviderRepository(prefs: prefs, secureStorage: secureStorage);
});
