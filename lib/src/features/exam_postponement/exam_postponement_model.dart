class ExamPostponementResponse {
  ExamPostponementResponse({
    this.eligible,
    required this.history,
    required this.reexamEligible,
    required this.reexamHistory,
  });

  final ExamEligible? eligible;
  final List<dynamic> history;
  final List<dynamic> reexamEligible;
  final List<dynamic> reexamHistory;

  factory ExamPostponementResponse.fromJson(Map<String, dynamic> json) {
    return ExamPostponementResponse(
      eligible: json['eligible'] != null
          ? ExamEligible.fromJson(json['eligible'] as Map<String, dynamic>)
          : null,
      history: json['history'] as List<dynamic>? ?? [],
      reexamEligible: json['reexamEligible'] as List<dynamic>? ?? [],
      reexamHistory: json['reexamHistory'] as List<dynamic>? ?? [],
    );
  }
}

class ExamEligible {
  ExamEligible({
    this.isOpen,
    this.titleRegister,
    required this.subjects,
  });

  final bool? isOpen;
  final String? titleRegister;
  final List<dynamic> subjects;

  factory ExamEligible.fromJson(Map<String, dynamic> json) {
    return ExamEligible(
      isOpen: json['is_open'] as bool?,
      titleRegister: json['title_register'] as String?,
      subjects: json['subjects'] as List<dynamic>? ?? [],
    );
  }
}
