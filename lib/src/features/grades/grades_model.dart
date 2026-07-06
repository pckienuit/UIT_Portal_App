class GradesResponse {
  GradesResponse({required this.semesterGroups});

  final List<SemesterGroup> semesterGroups;

  factory GradesResponse.fromJson(Map<String, dynamic> json) {
    final bySemester = json['bySemester'] as Map<String, dynamic>?;
    final groupsJson = bySemester?['semester_groups'] as List<dynamic>? ?? [];
    return GradesResponse(
      semesterGroups:
          groupsJson
              .map((e) => SemesterGroup.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class SemesterGroup {
  SemesterGroup({
    required this.semesterKey,
    required this.semesterLabel,
    required this.yearName,
    required this.subjects,
  });

  final String semesterKey;
  final String semesterLabel;
  final String yearName;
  final List<GradeSubject> subjects;

  factory SemesterGroup.fromJson(Map<String, dynamic> json) {
    final subjectsJson = json['subjects'] as List<dynamic>? ?? [];
    return SemesterGroup(
      semesterKey: json['semester_key']?.toString() ?? '',
      semesterLabel: json['semester_label']?.toString() ?? '',
      yearName: json['year_name']?.toString() ?? '',
      subjects:
          subjectsJson
              .map((e) => GradeSubject.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class GradeSubject {
  GradeSubject({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.numberOfCredit,
    required this.trainingTypeCode,
    required this.processPoint,
    required this.midtermScore,
    required this.practicePoint,
    required this.finalPoint,
    required this.coursePoint,
    required this.statusPoint,
    required this.subjectRequired,
    required this.note,
    this.weights,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final int numberOfCredit;
  final String trainingTypeCode;
  final String processPoint;
  final String midtermScore;
  final String practicePoint;
  final String finalPoint;
  final String coursePoint;
  final String statusPoint;
  final bool subjectRequired;
  final String note;
  final GradeWeights? weights;

  factory GradeSubject.fromJson(Map<String, dynamic> json) {
    return GradeSubject(
      id: json['id']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      numberOfCredit:
          int.tryParse(json['number_of_credit']?.toString() ?? '0') ?? 0,
      trainingTypeCode: json['training_type_code']?.toString() ?? '',
      processPoint: json['process_point']?.toString() ?? '',
      midtermScore: json['midterm_score']?.toString() ?? '',
      practicePoint: json['practice_point']?.toString() ?? '',
      finalPoint: json['final_point']?.toString() ?? '',
      coursePoint: json['course_point']?.toString() ?? '',
      statusPoint: json['status_point']?.toString() ?? '',
      subjectRequired: json['subject_required'] == true,
      note: json['note']?.toString() ?? '',
      weights:
          json['weights'] != null
              ? GradeWeights.fromJson(json['weights'] as Map<String, dynamic>)
              : null,
    );
  }
}

class GradeWeights {
  GradeWeights({
    required this.midterm,
    required this.process,
    required this.practice,
    required this.finalWeight,
  });

  final int midterm;
  final int process;
  final int practice;
  final int finalWeight;

  factory GradeWeights.fromJson(Map<String, dynamic> json) {
    return GradeWeights(
      midterm: int.tryParse(json['midterm']?.toString() ?? '0') ?? 0,
      process: int.tryParse(json['process']?.toString() ?? '0') ?? 0,
      practice: int.tryParse(json['practice']?.toString() ?? '0') ?? 0,
      finalWeight: int.tryParse(json['final']?.toString() ?? '0') ?? 0,
    );
  }
}
