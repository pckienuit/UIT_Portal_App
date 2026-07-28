import '../domain/ai_chat_models.dart';

enum AiPortalContextSection {
  profile,
  schedule,
  grades,
  tuition,
  examSchedule,
  trainingPoint,
  teachingSurvey,
  extracurricular,
  thesis,
  graduation,
  confirmationPaper,
  certificateValidation,
  revaluation,
  tuitionExtension,
  studyReservation,
  examPostponement,
  studentSupport,
  healthInsurance,
  parking,
  studentCard,
  transcriptRequest,
  scholarship,
}

extension AiPortalContextSectionLabel on AiPortalContextSection {
  String get contextLabel => switch (this) {
    AiPortalContextSection.profile => 'Hồ sơ học tập',
    AiPortalContextSection.schedule => 'Lịch học',
    AiPortalContextSection.grades => 'Điểm số',
    AiPortalContextSection.tuition => 'Học phí',
    AiPortalContextSection.examSchedule => 'Lịch thi',
    AiPortalContextSection.trainingPoint => 'Điểm rèn luyện',
    AiPortalContextSection.teachingSurvey => 'Khảo sát giảng dạy',
    AiPortalContextSection.extracurricular => 'Hoạt động ngoại khóa',
    AiPortalContextSection.thesis => 'Khóa luận',
    AiPortalContextSection.graduation => 'Tốt nghiệp',
    AiPortalContextSection.confirmationPaper => 'Giấy xác nhận',
    AiPortalContextSection.certificateValidation => 'Xác thực chứng chỉ',
    AiPortalContextSection.revaluation => 'Phúc khảo',
    AiPortalContextSection.tuitionExtension => 'Gia hạn học phí',
    AiPortalContextSection.studyReservation => 'Bảo lưu và thôi học',
    AiPortalContextSection.examPostponement => 'Hoãn thi',
    AiPortalContextSection.studentSupport => 'Hỗ trợ sinh viên',
    AiPortalContextSection.healthInsurance => 'Bảo hiểm y tế',
    AiPortalContextSection.parking => 'Đăng ký gửi xe',
    AiPortalContextSection.studentCard => 'Thẻ sinh viên',
    AiPortalContextSection.transcriptRequest => 'Yêu cầu bảng điểm',
    AiPortalContextSection.scholarship => 'Học bổng',
  };

  String get contextNote => switch (this) {
    AiPortalContextSection.profile => 'Khóa, lớp, ngành và giới tính.',
    AiPortalContextSection.schedule => 'Môn học, thời gian, phòng học.',
    AiPortalContextSection.grades =>
      'Tín chỉ tích lũy và điểm học kỳ mới nhất.',
    AiPortalContextSection.tuition =>
      'Khoản cần đóng, đã đóng, còn lại và hạn thanh toán.',
    _ => 'Chỉ gửi tóm tắt an toàn, không gửi ID, token hay dữ liệu thô.',
  };
}

class AiPortalContextSnapshot {
  const AiPortalContextSnapshot({
    this.profileSummary,
    this.scheduleSummary,
    this.gradesSummary,
    this.tuitionSummary,
    this.sectionSummaries = const {},
    this.sharedSections = const {},
  });

  final String? profileSummary;
  final String? scheduleSummary;
  final String? gradesSummary;
  final String? tuitionSummary;
  final Map<AiPortalContextSection, String> sectionSummaries;
  final Set<AiPortalContextSection> sharedSections;

  AiPortalContextSnapshot select(Set<AiPortalContextSection> sections) {
    final summaries = <AiPortalContextSection, String>{
      ...sectionSummaries,
      AiPortalContextSection.profile: ?profileSummary,
      AiPortalContextSection.schedule: ?scheduleSummary,
      AiPortalContextSection.grades: ?gradesSummary,
      AiPortalContextSection.tuition: ?tuitionSummary,
    }..removeWhere((section, _) => !sections.contains(section));
    return AiPortalContextSnapshot(
      profileSummary: summaries[AiPortalContextSection.profile],
      scheduleSummary: summaries[AiPortalContextSection.schedule],
      gradesSummary: summaries[AiPortalContextSection.grades],
      tuitionSummary: summaries[AiPortalContextSection.tuition],
      sectionSummaries: summaries,
      sharedSections: summaries.keys.toSet(),
    );
  }

  String buildSystemInstruction() {
    final sb = StringBuffer()
      ..writeln('Bạn là trợ lý AI tích hợp trong ứng dụng UIT Portal Mobile.')
      ..writeln('Dưới đây là dữ liệu Portal đã được sinh viên chọn chia sẻ:');
    for (final entry in sectionSummaries.entries) {
      sb
        ..writeln('\n[${entry.key.contextLabel.toUpperCase()}]')
        ..writeln(entry.value);
    }
    sb
      ..writeln('\nQuy tắc quan trọng:')
      ..writeln(
        '1. Chỉ dựa trên thông tin được cung cấp ở trên để trả lời về dữ liệu cá nhân.',
      )
      ..writeln(
        '2. Nếu thiếu dữ liệu, hãy nói rõ "Không tìm thấy dữ liệu trên hệ thống", không tự bịa.',
      );
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
  final dynamic config;
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
  const AiStreamEvent({required this.type, this.content, this.errorMessage});
  final AiStreamEventType type;
  final String? content;
  final String? errorMessage;
}

abstract class AiChatBackend {
  Future<void> dispose();
  Future<void> cancel();
  Future<AiConnectionResult> testConnection({String? testModelId});
  Future<List<AiModelOption>> listModels();
  Stream<AiStreamEvent> streamChat(AiChatRequest request);
}

class AiConnectionResult {
  const AiConnectionResult({required this.success, this.errorMessage});
  final bool success;
  final String? errorMessage;
}
