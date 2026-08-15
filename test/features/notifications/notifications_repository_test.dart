import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/data/portal_api_client.dart';
import 'package:uit_portal_app/src/features/notifications/notifications_providers.dart';

void main() {
  test('fetches public announcements from verified endpoint', () async {
    final adapter = _JsonAdapter({
      'items': [
        {
          'id': '7',
          'slug': 'thong-bao-moi',
          'title': 'Thông báo mới',
          'excerpt': 'Nội dung tóm tắt',
          'category_names': ['Sinh viên'],
        },
      ],
    });
    final client = PortalApiClient(
      dio: Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter,
    );

    final result = await NotificationsRepository(client).fetchAnnouncements();

    expect(adapter.path, '/api/public/announcements');
    expect(result.single.id, 7);
    expect(result.single.categories, ['Sinh viên']);
    expect(
      result.single.detailUri,
      Uri.parse('https://portal.uit.edu.vn/bai-viet/thong-bao-moi'),
    );
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Map<String, dynamic> body;
  String? path;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
