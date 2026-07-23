import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../application/router_runtime_service.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
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
          if (runtimeState.state == RouterState.ready) {
            options.baseUrl = runtimeState.baseUrl!;
            options.headers['Authorization'] = 'Bearer ${runtimeState.bearer}';
          }
          return handler.next(options);
        },
      ),
    );
  }

  RouterAdminClient.forTest(Dio dio) : _dio = dio;

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
            .map((e) => AiProviderConfig.fromJson(e as Map<String, dynamic>))
            .toList();
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

      final payload = config.toJson();
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

  // Xóa provider connection
  Future<bool> deleteProvider(String id) async {
    try {
      final res = await _dio.delete('/internal/providers/$id');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to delete provider from core: $e');
      return false;
    }
  }

  // Đặt connection active
  Future<bool> setActiveProvider(String id) async {
    try {
      final res = await _dio.patch(
        '/internal/providers/$id',
        data: {'active': true},
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to set active provider in core: $e');
      return false;
    }
  }

  // Test connection
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

final routerAdminClientProvider = Provider<RouterAdminClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return RouterAdminClient(ref: ref, secureStorage: secureStorage);
});

final routerModelCatalogProvider = FutureProvider.autoDispose
    .family<List<AiModelOption>, String>((ref, connectionId) {
      return ref.watch(routerAdminClientProvider).listModels(connectionId);
    });
