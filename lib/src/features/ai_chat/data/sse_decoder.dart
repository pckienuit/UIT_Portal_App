import 'dart:convert';

/// Một SSE event được decode từ Server-Sent Events stream.
class SseEvent {
  const SseEvent({this.event, required this.data, this.id, this.retry});

  final String? event;
  final String data;
  final String? id;
  final int? retry;

  @override
  String toString() =>
      'SseEvent(event: $event, data: $data, id: $id, retry: $retry)';
}

/// Bộ giải mã SSE stream độc lập. Phục vụ việc biến đổi `Stream<List<int>>` từ HTTP response
/// thành `Stream<SseEvent>` một cách mượt mà và an toàn trước các trường hợp:
/// - Event bị ngắt ở giữa các byte buffer
/// - Nhiều events chứa trong một buffer duy nhất
/// - UTF-8 multi-byte character bị cắt ngang ở ranh giới buffer.
class SseDecoder {
  const SseDecoder();

  Stream<SseEvent> bind(Stream<List<int>> stream) {
    String buffer = '';

    return stream
        .cast<
          List<int>
        >() // Cast Uint8List sang List<int> để tương thích Utf8Decoder ở runtime
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .expand((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            // Ranh giới kết thúc một Event block
            final event = _parseEventBlock(buffer);
            buffer = '';
            return event != null ? [event] : const <SseEvent>[];
          }
          buffer += '$line\n';
          return const <SseEvent>[];
        });
  }

  SseEvent? _parseEventBlock(String block) {
    String? eventType;
    String data = '';
    String? id;
    int? retry;
    bool hasData = false;

    final lines = block.split('\n');
    for (final line in lines) {
      if (line.isEmpty || line.startsWith(':')) {
        continue; // Bỏ qua comment lines
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex <= 0) continue;

      final field = line.substring(0, colonIndex).trim();
      var value = line.substring(colonIndex + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'event':
          eventType = value;
          break;
        case 'data':
          data = hasData ? '$data\n$value' : value;
          hasData = true;
          break;
        case 'id':
          id = value;
          break;
        case 'retry':
          retry = int.tryParse(value);
          break;
      }
    }

    if (!hasData) return null;
    return SseEvent(event: eventType, data: data, id: id, retry: retry);
  }
}
