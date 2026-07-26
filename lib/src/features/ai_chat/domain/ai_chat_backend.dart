import '../domain/ai_chat_models.dart';

class AiPortalContextSnapshot {
  const AiPortalContextSnapshot({
    this.profileSummary,
    this.scheduleSummary,
    this.gradesSummary,
    this.tuitionSummary,
  });

  final String? profileSummary;
  final String? scheduleSummary;
  final String? gradesSummary;
  final String? tuitionSummary;

  String buildSystemInstruction() {
    final sb = StringBuffer();
    sb.writeln('Bạn là trợ lý AI tích hợp trong ứng dụng UIT Portal Mobile.');
    sb.writeln('Dưới đây là dữ liệu học tập cá nhân của sinh viên hiện tại (đã được sinh viên đồng ý chia sẻ):');
    
    if (profileSummary != null) {
      sb.writeln('\n[HỒ SƠ SINH VIÊN]');
      sb.writeln(profileSummary);
    }
    if (scheduleSummary != null) {
      sb.writeln('\n[LỊCH HỌC TKB]');
      sb.writeln(scheduleSummary);
    }
    if (gradesSummary != null) {
      sb.writeln('\n[KẾT QUẢ HỌC TẬP]');
      sb.writeln(gradesSummary);
    }
    if (tuitionSummary != null) {
      sb.writeln('\n[HỌC PHÍ & CÔNG NỢ]');
      sb.writeln(tuitionSummary);
    }
    
    sb.writeln('\nQuy tắc quan trọng:');
    sb.writeln('1. Chỉ dựa trên thông tin được cung cấp ở trên để trả lời về các vấn đề cá nhân của sinh viên.');
    sb.writeln('2. Nếu thông tin không có hoặc thiếu, hãy nói rõ "Không tìm thấy dữ liệu trên hệ thống", tuyệt đối không tự bịa thông tin.');
    return sb.toString();
  }
}

class AiChatRequest {
  const AiChatRequest({
    required this.apiKey,
    required this.messages,
    this.context,
    this.modelId,
    this.config,
  });

  final String apiKey;
  final List<AiChatMessage> messages;
  final AiPortalContextSnapshot? context;
  final String? modelId;
  final dynamic config; // Để tránh dependency cycle hoặc dynamic reference
}

class AiModelCapabilities {
  const AiModelCapabilities({
    this.vision = false,
    this.reasoning = false,
    this.tools = false,
    this.contextWindow,
    this.maxOutput,
  });

  final bool vision;
  final bool reasoning;
  final bool tools;
  final int? contextWindow;
  final int? maxOutput;
}

class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.name,
    this.owner,
    this.capabilities = const AiModelCapabilities(),
  });

  final String id;
  final String name;
  final String? owner;
  final AiModelCapabilities capabilities;
}

enum AiStreamEventType { chunk, done, error }

class AiStreamEvent {
  const AiStreamEvent({
    required this.type,
    this.content,
    this.errorMessage,
  });

  final AiStreamEventType type;
  final String? content;
  final String? errorMessage;
}

abstract class AiChatBackend {
  Future<void> dispose();
  Future<void> cancel();

  /// Thử kết nối, ví dụ gọi test api keys hoặc test cụ thể modelId, trả về object `AiConnectionResult`
  Future<AiConnectionResult> testConnection({String? testModelId});

  /// Nạp các model hiện có
  Future<List<AiModelOption>> listModels();

  /// Chat với stream response
  Stream<AiStreamEvent> streamChat(AiChatRequest request);
}

class AiConnectionResult {
  const AiConnectionResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}