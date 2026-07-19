import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/sse_decoder.dart';

void main() {
  group('SseDecoder parsing', () {
    test('splits and decodes standard SSE chunk stream', () async {
      final sseLines = [
        'event: message\n',
        'data: {"id": "1", "choices": [{"delta": {"content": "Hello"}}]}\n',
        '\n',
        'data: {"id": "2", "choices": [{"delta": {"content": " world"}}]}\n',
        '\n',
        'data: [DONE]\n',
        '\n',
      ];

      final byteStream = Stream.fromIterable(sseLines.map((s) => utf8.encode(s)));
      final decoded = await const SseDecoder().bind(byteStream).toList();

      expect(decoded.length, 3);
      expect(decoded[0].event, 'message');
      expect(decoded[0].data, '{"id": "1", "choices": [{"delta": {"content": "Hello"}}]}');
      expect(decoded[1].event, isNull);
      expect(decoded[1].data, '{"id": "2", "choices": [{"delta": {"content": " world"}}]}');
      expect(decoded[2].data, '[DONE]');
    });

    test('ignores comment lines and keepalive blanks', () async {
      final sseLines = [
        ': keepalive\n',
        '\n',
        'data: first block\n',
        '\n',
      ];

      final byteStream = Stream.fromIterable(sseLines.map((s) => utf8.encode(s)));
      final decoded = await const SseDecoder().bind(byteStream).toList();

      expect(decoded.length, 1);
      expect(decoded.first.data, 'first block');
    });

    test('reconstructs split multi-byte characters', () async {
      // Dùng utf8.encode để có các byte UTF-8 chuẩn xác, và cắt ngang ở byte ranh giới
      final fullBytes = utf8.encode('data: Tiếng Việt\n\n');
      
      // Cắt đôi mảng byte tại vị trí ngẫu nhiên (ví dụ byte thứ 10, rơi vào giữa chữ 'ế')
      final firstPart = fullBytes.sublist(0, 10);
      final secondPart = fullBytes.sublist(10);

      final byteStream = Stream.fromIterable([firstPart, secondPart]);
      final decoded = await const SseDecoder().bind(byteStream).toList();

      expect(decoded.length, 1);
      expect(decoded.first.data, 'Tiếng Việt');
    });
  });
}
