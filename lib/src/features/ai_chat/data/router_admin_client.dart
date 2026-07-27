import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../application/router_runtime_service.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';
import 'ai_provider_repository.dart';
import '../domain/router_models.dart';

class RouterAdminClient {
  RouterAdminClient({required this.ref, required this.secureStorage}) {
    _dio = Dio();
    // Tự động gán bearer token khi gọi loopback
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final runtimeState = ref.read(routerRuntimeServiceProvider);
          if (runtimeState.state != RouterState.ready ||
              runtimeState.baseUrl == null) {
            // Core chưa sẵn sàng: abort thay vì bắn request tới baseUrl rỗng.
            return handler.reject(
              DioException(
                requestOptions: options,
                error: const _CoreUnavailableError(),
                type: DioExceptionType.connectionError,
              ),
            );
          }
          options.baseUrl = runtimeState.baseUrl!;
          options.headers['Authorization'] = 'Bearer ${runtimeState.bearer}';
          return handler.next(options);
        },
      ),
    );
  }

  RouterAdminClient.forTest(
    Dio dio, {
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio,
       secureStorage = secureStorage ?? const FlutterSecureStorage();

  late final Ref ref;
  late final FlutterSecureStorage secureStorage;
  late final Dio _dio;

  static const String _kSecretPrefix = 'ai_provider_key_';

  static bool supportsProvider(AiProviderConfig config) =>
      config.kind == AiBackendKind.openAiCompatible &&
      config.baseUrl.isNotEmpty;

  // Lấy danh sách providers từ internal Node API
  Future<List<AiProviderConfig>> listProviders() async {
    try {
      final res = await _dio.get('/internal/providers');
      if (res.statusCode == 200) {
        final list = res.data as List<dynamic>;
        return list
            .whereType<Map>()
            .map((item) => _connectionFromCore(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('Failed to list providers from core: $e');
    }
    return [];
  }

  Future<List<AiModelOption>> listModels(String connectionId) async {
    final res = await _dio.get(
      '/v1/models',
      queryParameters: {'connectionId': connectionId},
    );
    final data = res.data;
    if (res.statusCode != 200 || data is! Map || data['data'] is! List) {
      throw StateError('Danh sách mô hình không hợp lệ');
    }
    return (data['data'] as List)
        .whereType<Map>()
        .map((item) {
          final id = item['id']?.toString() ?? '';
          return AiModelOption(
            id: id,
            name: item['name']?.toString() ?? id,
            owner: item['owned_by']?.toString(),
          );
        })
        .where((model) => model.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> testModel({
    required String connectionId,
    required String providerKey,
    required String modelId,
  }) async {
    final trimmedConnectionId = connectionId.trim();
    final trimmedProviderKey = providerKey.trim();
    final trimmedModelId = modelId.trim();
    if (trimmedConnectionId.isEmpty ||
        trimmedProviderKey.isEmpty ||
        trimmedModelId.isEmpty) {
      return false;
    }

    try {
      final res = await _dio.post(
        '/v1/chat/completions',
        queryParameters: {'connectionId': trimmedConnectionId},
        data: {
          'model': '$trimmedProviderKey/$trimmedModelId',
          'messages': [
            {'role': 'user', 'content': 'Reply with OK.'},
          ],
          'max_tokens': 1,
          'stream': false,
        },
        options: Options(headers: {'x-model-probe': 'true'}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Model test failed for $trimmedConnectionId: $e');
      return false;
    }
  }

  Future<bool> saveModelSettings(AiProviderModelSettings settings) async {
    try {
      final res = await _dio.put(
        '/internal/model-settings/${Uri.encodeComponent(settings.providerKey)}',
        data: settings.toJson(),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to save model settings to core: $e');
      return false;
    }
  }

  // Thêm / Cập nhật provider connection
  Future<bool> saveProvider(
    AiProviderConfig config, {
    String? apiKey,
    String? sourceToken,
  }) async {
    // Chỉ đồng bộ các connection OpenAI compatible có baseUrl mạng hợp lệ
    if (!supportsProvider(config)) {
      return true;
    }

    try {
      // 1. Lưu API Key vào Secure Storage an toàn
      if (apiKey != null) {
        await secureStorage.write(
          key: '$_kSecretPrefix${config.id}',
          value: apiKey,
        );
      }

      // 2. Lấy API Key ra (nếu có) để sync qua Core
      final key =
          apiKey ??
          await secureStorage.read(key: '$_kSecretPrefix${config.id}');

      final providers = await listProviders();
      final exists = providers.any((p) => p.id == config.id);

      final payload = _connectionPayload(config);
      if (key != null) {
        payload['apiKey'] = key;
      }
      if (sourceToken != null) payload['sourceToken'] = sourceToken;

      if (exists) {
        final res = await _dio.patch(
          '/internal/providers/${config.id}',
          data: payload,
        );
        return res.statusCode == 200;
      } else {
        final res = await _dio.post('/internal/providers', data: payload);
        return res.statusCode == 201;
      }
    } catch (e) {
      debugPrint('Failed to save provider to core: $e');
      return false;
    }
  }

  // Xóa provider connection. 404 = resource đã vắng mặt trong core (chưa sync
  // hoặc đã bị xóa lần trước) → idempotent success.
  Future<bool> deleteProvider(String id) async {
    try {
      final res = await _dio.delete('/internal/providers/$id');
      return res.statusCode == 200 || res.statusCode == 404;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true;
      if (e.error is _CoreUnavailableError) return true;
      debugPrint('Failed to delete provider from core: $e');
      return false;
    } catch (e) {
      debugPrint('Failed to delete provider from core: $e');
      return false;
    }
  }


  Future<bool> testProvider(String id) async {
    try {
      // Đọc api key từ secure storage truyền qua header đặc biệt
      final key = await secureStorage.read(key: '$_kSecretPrefix$id');
      final headers = <String, dynamic>{};
      if (key != null) {
        headers['x-provider-key'] = key;
      }
      final res = await _dio.post(
        '/internal/providers/$id/test',
        options: Options(headers: headers),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed for $id: $e');
      return false;
    }
  }

  // Lấy lịch sử usage
  Future<List<dynamic>> getUsageHistory() async {
    try {
      final res = await _dio.get('/internal/usage/stats');
      if (res.statusCode == 200) {
        return res.data as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to fetch usage: $e');
    }
    return [];
  }

  // Xóa lịch sử usage
  Future<bool> clearUsage() async {
    try {
      final res = await _dio.delete('/internal/usage');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to clear usage: $e');
      return false;
    }
  }

  // Lấy Quota Snapshot
  Future<RouterQuotaSnapshot> getQuota([String? connectionId]) async {
    final path = connectionId == null
        ? '/internal/quota'
        : '/internal/quota/$connectionId';
    final res = await _dio.get(
      path,
      options: Options(validateStatus: (status) => status != null),
    );
    final data = res.data;
    if (data is! Map) throw const FormatException('Malformed quota response');
    return RouterQuotaSnapshot.fromJson(Map<String, dynamic>.from(data));
  }

  // Refresh Quota
  Future<RouterQuotaSnapshot> refreshQuota(String connectionId) async {
    final res = await _dio.post(
      '/internal/quota/$connectionId/refresh',
      options: Options(validateStatus: (status) => status != null),
    );
    final data = res.data;
    if (data is! Map) throw const FormatException('Malformed quota response');
    return RouterQuotaSnapshot.fromJson(Map<String, dynamic>.from(data));
  }

  // Reset toàn bộ dữ liệu Core AI nội bộ (providers, usage, quota)
  Future<bool> resetData() async {
    try {
      // 1. Clear API keys trong secure storage
      final providers = await listProviders();
      for (final p in providers) {
        await secureStorage.delete(key: '$_kSecretPrefix${p.id}');
      }

      // 2. Clear local DB file bằng cách gửi request reset sang Node core
      // Nhìn lại main.js, ta chưa định nghĩa route /internal/reset. Sẽ patch Node core sau.
      final res = await _dio.post('/internal/reset');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to reset core data: $e');
      return false;
    }
  }
}

AiProviderConfig _connectionFromCore(Map<String, dynamic> json) {
  final metadata = json['mobileMetadata'];
  final mobile = metadata is Map
      ? Map<String, dynamic>.from(metadata)
      : const <String, dynamic>{};
  final kind = mobile['kind']?.toString();
  return AiProviderConfig(
    id: json['id']?.toString() ?? '',
    name: json['displayName']?.toString() ?? '',
    kind: AiBackendKind.values.firstWhere(
      (value) => value.name == kind,
      orElse: () => AiBackendKind.openAiCompatible,
    ),
    baseUrl: mobile['baseUrl']?.toString() ?? '',
    presetId: json['providerId']?.toString(),
    systemPrompt: mobile['systemPrompt']?.toString(),
    authMode: json['authMode']?.toString() ?? 'apiKey',
    accountId: mobile['accountId']?.toString(),
    projectId: mobile['projectId']?.toString(),
    transportKind: mobile['transportKind']?.toString(),
    chatUrl: mobile['chatUrl']?.toString(),
    modelsUrl: mobile['modelsUrl']?.toString(),
    authHeader: mobile['authHeader']?.toString(),
    authScheme: mobile['authScheme']?.toString(),
    staticHeaders: mobile['staticHeaders'] is Map
        ? Map<String, String>.from(mobile['staticHeaders'] as Map)
        : const {},
  );
}

Map<String, dynamic> _connectionPayload(AiProviderConfig config) => {
  'id': config.id,
  'name': config.name,
  'kind': config.kind.name,
  'baseUrl': config.baseUrl,
  'presetId': config.presetId,
  'systemPrompt': config.systemPrompt,
  'authMode': config.authMode,
  'accountId': config.accountId,
  'projectId': config.projectId,
  'transportKind': config.transportKind,
  'chatUrl': config.chatUrl,
  'modelsUrl': config.modelsUrl,
  'authHeader': config.authHeader,
  'authScheme': config.authScheme,
  'staticHeaders': config.staticHeaders,
};

final routerAdminClientProvider = Provider<RouterAdminClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return RouterAdminClient(ref: ref, secureStorage: secureStorage);
});

final routerModelCatalogProvider = FutureProvider.autoDispose
    .family<List<AiModelOption>, String>((ref, connectionId) {
      return ref.watch(routerAdminClientProvider).listModels(connectionId);
    });

class _CoreUnavailableError implements Exception {
  const _CoreUnavailableError();
  @override
  String toString() => 'Core AI router runtime not ready';
}
