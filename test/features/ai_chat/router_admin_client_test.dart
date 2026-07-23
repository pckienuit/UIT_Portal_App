import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

class _QuotaAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"status":"unsupported","connectionId":"github-2",'
      '"providerId":"github","plan":null,"fetchedAt":null,'
      '"entries":[],"message":"Quota unavailable"}',
      501,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'quota client targets connection and parses typed non-2xx body',
    () async {
      final adapter = _QuotaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = adapter;
      final client = RouterAdminClient.forTest(dio);

      final snapshot = await client.getQuota('github-2');

      expect(adapter.requests.single.path, '/internal/quota/github-2');
      expect(snapshot.status, RouterQuotaStatus.unsupported);
      expect(snapshot.connectionId, 'github-2');
      expect(snapshot.message, 'Quota unavailable');
    },
  );
}
