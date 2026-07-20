import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../application/router_runtime_service.dart';
import '../domain/ai_chat_models.dart';
import 'ai_provider_repository.dart';

class RouterAdminClient {
  RouterAdminClient({
    required this.ref,
    required this.secureStorage,
  }) {
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

  final Ref ref;
  final FlutterSecureStorage secureStorage;
  late final Dio _dio;

  static const String _kSecretPrefix = 'ai_provider_key_';

  // Lấy danh sách providers từ internal Node API
  Future<List<AiProviderConfig>> listProviders() async {
    try {
      final res = await _dio.get('/internal/providers');
      if (res.statusCode == 200) {
        final list = res.data as List<dynamic>;
        return list.map((e) => AiProviderConfig.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Failed to list providers from core: $e');
    }
    return [];
  }

  // Thêm / Cập nhật provider connection
  Future<bool> saveProvider(AiProviderConfig config, {String? apiKey}) async {
    // Chỉ đồng bộ các connection OpenAI compatible có baseUrl mạng hợp lệ
    if (config.kind != AiBackendKind.openAiCompatible || config.baseUrl.isEmpty) {
      return true; 
    }

    try {
      // 1. Lưu API Key vào Secure Storage an toàn
      if (apiKey != null) {
        await secureStorage.write(key: '$_kSecretPrefix${config.id}', value: apiKey);
      }

      // 2. Lấy API Key ra (nếu có) để sync qua Core
      final key = apiKey ?? await secureStorage.read(key: '$_kSecretPrefix${config.id}');

      final providers = await listProviders();
      final exists = providers.any((p) => p.id == config.id);

      final payload = config.toJson();
      if (key != null) {
        payload['apiKey'] = key;
      }

      if (exists) {
        final res = await _dio.patch('/internal/providers/${config.id}', data: payload);
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
      await secureStorage.delete(key: '$_kSecretPrefix$id');
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
      final res = await _dio.patch('/internal/providers/$id', data: {'active': true});
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
  Future<Map<String, dynamic>?> getQuota() async {
    try {
      final res = await _dio.get('/internal/quota');
      if (res.statusCode == 200) {
        return res.data as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Failed to get quota: $e');
    }
    return null;
  }

  // Refresh Quota
  Future<Map<String, dynamic>?> refreshQuota(String connectionId) async {
    try {
      final res = await _dio.post('/internal/quota/$connectionId/refresh');
      if (res.statusCode == 200) {
        return res.data as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Failed to refresh quota: $e');
    }
    return null;
  }
}

final routerAdminClientProvider = Provider<RouterAdminClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return RouterAdminClient(ref: ref, secureStorage: secureStorage);
});
