import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/portal_api_client.dart';

class ApiScanner {
  static const List<String> endpoints = [
    '/api/sinh-vien/tkb',
    '/api/sinh-vien/lich-thi',
    '/api/sinh-vien/lich-sinh-hoat',
    '/api/sinh-vien/khao-sat-giang-day',
    '/api/sinh-vien/giay-xac-nhan',
    '/api/sinh-vien/xac-nhan-chung-chi',
    '/api/sinh-vien/hoc-phi',
    '/api/sinh-vien/dang-vien',
    '/api/sinh-vien/de-tai-sinh-vien'
  ];

  static Future<void> scan(PortalApiClient client) async {
    debugPrint('=== STARTING API SCAN ===');
    for (final endpoint in endpoints) {
      try {
        final response = await client.get(endpoint);
        final data = response.data;
        
        final schema = _extractSchema(data);
        _printInChunks('--- SCHEMA FOR $endpoint ---\n$schema');
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          _printInChunks('--- SCHEMA FOR $endpoint ---\n404 NOT FOUND');
        } else if (e is DioException && e.response != null) {
          _printInChunks('--- SCHEMA FOR $endpoint ---\nERROR ${e.response?.statusCode}: ${e.response?.data}');
        } else {
          _printInChunks('--- SCHEMA FOR $endpoint ---\nERROR: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 3000));
    }
    debugPrint('=== END API SCAN ===');
  }

  static void _printInChunks(String text) {
    final pattern = RegExp('.{1,800}(?=\\s|\$)');
    final matches = pattern.allMatches(text);
    for (final match in matches) {
      debugPrint(match.group(0));
    }
  }

  static dynamic _extractSchema(dynamic data) {
    if (data == null) return 'null';
    if (data is String) return 'String';
    if (data is int) return 'int';
    if (data is double) return 'double';
    if (data is bool) return 'bool';
    
    if (data is List) {
      if (data.isEmpty) return ['EmptyList'];
      // Take schema of the first element
      return [_extractSchema(data.first)];
    }
    
    if (data is Map<String, dynamic>) {
      final schemaMap = <String, dynamic>{};
      for (final entry in data.entries) {
        schemaMap[entry.key] = _extractSchema(entry.value);
      }
      return schemaMap;
    }
    
    return data.runtimeType.toString();
  }
}
