class RevaluationResponse {
  RevaluationResponse({
    required this.eligible,
    required this.history,
  });

  final List<RevaluationEligible> eligible;
  final List<RevaluationHistory> history;

  factory RevaluationResponse.fromJson(Map<String, dynamic> json) {
    return RevaluationResponse(
      eligible: (json['eligible'] as List<dynamic>?)
              ?.map((e) => RevaluationEligible.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => RevaluationHistory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RevaluationEligible {
  RevaluationEligible({
    this.id,
    this.sectionClassCode,
    this.subjectCode,
    this.subjectName,
    this.dateExam,
    this.roomCode,
    this.currentPoint,
    this.examination,
    this.revaluationDeadline,
  });

  final String? id;
  final String? sectionClassCode;
  final String? subjectCode;
  final String? subjectName;
  final String? dateExam;
  final String? roomCode;
  final double? currentPoint;
  final String? examination;
  final String? revaluationDeadline;

  factory RevaluationEligible.fromJson(Map<String, dynamic> json) {
    return RevaluationEligible(
      id: json['id'] as String?,
      sectionClassCode: json['section_class_code'] as String?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      dateExam: json['date_exam'] as String?,
      roomCode: json['room_code'] as String?,
      currentPoint: (json['current_point'] as num?)?.toDouble(),
      examination: json['examination'] as String?,
      revaluationDeadline: json['revaluation_deadline'] as String?,
    );
  }
}

class RevaluationHistory {
  RevaluationHistory({
    this.id,
    this.subjectCode,
    this.subjectName,
    this.classCode,
    this.examDay,
    this.currentPoint,
    this.status,
    this.createDate,
  });

  final String? id;
  final String? subjectCode;
  final String? subjectName;
  final String? classCode;
  final String? examDay;
  final num? currentPoint;
  final String? status;
  final String? createDate;

  factory RevaluationHistory.fromJson(Map<String, dynamic> json) {
    return RevaluationHistory(
      id: json['id'] as String?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      classCode: json['class_code'] as String?,
      examDay: json['exam_day'] as String?,
      currentPoint: json['current_point'] as num?,
      status: json['status'] as String?,
      createDate: json['create_date'] as String?,
    );
  }
}
