class GradesResponse {
  GradesResponse({
    required this.semesterGroups,
    this.totalProgramCredits,
    this.summary,
    this.ctdtStatistics,
    this.programScores = const [],
    this.outsideProgramSubjects = const [],
    this.defenseEducation,
    this.foreignLanguage,
    this.termSummaries = const [],
    this.isGraduated = false,
  });

  final List<SemesterGroup> semesterGroups;
  final int? totalProgramCredits;
  final GradesSummary? summary;
  final CtdtStatistics? ctdtStatistics;
  final List<ProgramScoreGroup> programScores;
  final List<OutsideProgramSubject> outsideProgramSubjects;
  final CertificateInfo? defenseEducation;
  final CertificateInfo? foreignLanguage;
  final List<TermSummary> termSummaries;
  final bool isGraduated;

  factory GradesResponse.fromJson(Map<String, dynamic> json) {
    final bySemester = json['bySemester'] as Map<String, dynamic>?;
    final groupsJson = bySemester?['semester_groups'] as List<dynamic>? ?? [];
    final summaryJson = bySemester?['summary'] as Map<String, dynamic>?;

    final byCtdt = json['byCtdt'] as Map<String, dynamic>?;
    final ctdtStatsJson = byCtdt?['statistics'] as Map<String, dynamic>?;
    final progScoresJson = byCtdt?['program_scores'] as List<dynamic>? ?? [];
    final outsideJson = byCtdt?['outsideProgramSubjects'] as List<dynamic>? ?? [];

    final termSummariesJson = json['termSummaries'] as List<dynamic>? ?? [];

    return GradesResponse(
      totalProgramCredits: _positiveInt(
        bySemester?['total_program_credits'] ?? json['total_program_credits'],
      ),
      semesterGroups: groupsJson
          .map((e) => SemesterGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: summaryJson != null ? GradesSummary.fromJson(summaryJson) : null,
      ctdtStatistics: ctdtStatsJson != null ? CtdtStatistics.fromJson(ctdtStatsJson) : null,
      programScores: progScoresJson
          .map((e) => ProgramScoreGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      outsideProgramSubjects: outsideJson
          .map((e) => OutsideProgramSubject.fromJson(e as Map<String, dynamic>))
          .toList(),
      defenseEducation: byCtdt?['defenseEducation'] != null
          ? CertificateInfo.fromJson(byCtdt!['defenseEducation'] as Map<String, dynamic>)
          : null,
      foreignLanguage: byCtdt?['foreignLanguage'] != null
          ? CertificateInfo.fromJson(byCtdt!['foreignLanguage'] as Map<String, dynamic>)
          : null,
      termSummaries: termSummariesJson
          .map((e) => TermSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      isGraduated: json['isGraduated'] as bool? ?? false,
    );
  }

  static int? _positiveInt(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

class GradesSummary {
  const GradesSummary({
    this.totalCreditsAll,
    this.accumulatedCredits,
    this.gpaAll,
    this.gpaAccumulated,
    this.graduationCredits,
  });

  final num? totalCreditsAll;
  final num? accumulatedCredits;
  final num? gpaAll;
  final num? gpaAccumulated;
  final num? graduationCredits;

  factory GradesSummary.fromJson(Map<String, dynamic> json) {
    return GradesSummary(
      totalCreditsAll: json['total_credits_all'] as num?,
      accumulatedCredits: json['accumulated_credits'] as num?,
      gpaAll: json['gpa_all'] as num?,
      gpaAccumulated: json['gpa_accumulated'] as num?,
      graduationCredits: json['graduation_credits'] as num?,
    );
  }
}

class CtdtStatistics {
  const CtdtStatistics({
    this.notLearned,
    this.passed,
    this.retake,
    this.inProgress,
    this.outsideProgram,
    this.electiveLearned,
    this.passedCredit,
    this.totalProgramCredit,
    this.totalStudiedCredit,
    this.avgScore,
    this.accumulatedGpa,
    this.creditInCtdt,
    this.creditOutside,
  });

  final int? notLearned;
  final int? passed;
  final int? retake;
  final int? inProgress;
  final int? outsideProgram;
  final int? electiveLearned;
  final int? passedCredit;
  final int? totalProgramCredit;
  final int? totalStudiedCredit;
  final num? avgScore;
  final num? accumulatedGpa;
  final int? creditInCtdt;
  final int? creditOutside;

  factory CtdtStatistics.fromJson(Map<String, dynamic> json) {
    return CtdtStatistics(
      notLearned: json['not_learned'] as int?,
      passed: json['passed'] as int?,
      retake: json['retake'] as int?,
      inProgress: json['in_progress'] as int?,
      outsideProgram: json['outside_program'] as int?,
      electiveLearned: json['elective_learned'] as int?,
      passedCredit: json['passed_credit'] as int?,
      totalProgramCredit: json['total_program_credit'] as int?,
      totalStudiedCredit: json['total_studied_credit'] as int?,
      avgScore: json['avg_score'] as num?,
      accumulatedGpa: json['accumulated_gpa'] as num?,
      creditInCtdt: json['credit_in_ctdt'] as int?,
      creditOutside: json['credit_outside'] as int?,
    );
  }
}

class CertificateInfo {
  const CertificateInfo({
    this.passed = false,
    this.score,
    this.rank,
    this.rankLabel,
    this.certificate,
    this.yearName,
  });

  final bool passed;
  final num? score;
  final String? rank;
  final String? rankLabel;
  final String? certificate;
  final String? yearName;

  factory CertificateInfo.fromJson(Map<String, dynamic> json) {
    return CertificateInfo(
      passed: json['passed'] as bool? ?? false,
      score: json['score'] as num?,
      rank: json['rank'] as String?,
      rankLabel: json['rank_label'] as String?,
      certificate: json['certificate'] as String?,
      yearName: json['year_name'] as String?,
    );
  }
}

class TermSummary {
  const TermSummary({
    this.id,
    this.yearId,
    this.yearName,
    this.semester,
    this.termGpa,
    this.cumulativeGpa,
    this.trainingScore,
    this.termCredit,
    this.accumulatedCredit,
    this.classify,
    this.classifyLabel,
  });

  final int? id;
  final int? yearId;
  final String? yearName;
  final String? semester;
  final num? termGpa;
  final num? cumulativeGpa;
  final int? trainingScore;
  final int? termCredit;
  final int? accumulatedCredit;
  final String? classify;
  final String? classifyLabel;

  factory TermSummary.fromJson(Map<String, dynamic> json) {
    return TermSummary(
      id: json['id'] as int?,
      yearId: json['yearId'] as int?,
      yearName: json['yearName'] as String?,
      semester: json['semester']?.toString(),
      termGpa: json['termGpa'] as num?,
      cumulativeGpa: json['cumulativeGpa'] as num?,
      trainingScore: json['trainingScore'] as int?,
      termCredit: json['termCredit'] as int?,
      accumulatedCredit: json['accumulatedCredit'] as int?,
      classify: json['classify'] as String?,
      classifyLabel: json['classifyLabel'] as String?,
    );
  }
}

class ProgramScoreGroup {
  const ProgramScoreGroup({
    required this.semester,
    required this.semesterLabel,
    required this.totalCredit,
    required this.lines,
  });

  final int semester;
  final String semesterLabel;
  final int totalCredit;
  final List<ProgramScoreSubject> lines;

  factory ProgramScoreGroup.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'] as List<dynamic>? ?? [];
    return ProgramScoreGroup(
      semester: json['semester'] as int? ?? 0,
      semesterLabel: json['semester_label']?.toString() ?? '',
      totalCredit: json['total_credit'] as int? ?? 0,
      lines: linesJson
          .map((e) => ProgramScoreSubject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProgramScoreSubject {
  const ProgramScoreSubject({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.credit,
    this.creditTheory = 0,
    this.creditPract = 0,
    this.subjectRequired = false,
    this.coursePoint,
    this.status,
    this.weights,
  });

  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final int credit;
  final int creditTheory;
  final int creditPract;
  final bool subjectRequired;
  final String? coursePoint;
  final String? status; // 'passed' | 'not_learned' | 'in_progress'
  final GradeWeights? weights;

  factory ProgramScoreSubject.fromJson(Map<String, dynamic> json) {
    return ProgramScoreSubject(
      subjectId: json['subject_id']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      credit: int.tryParse(json['credit']?.toString() ?? '0') ?? 0,
      creditTheory: int.tryParse(json['credit_theory']?.toString() ?? '0') ?? 0,
      creditPract: int.tryParse(json['credit_pract']?.toString() ?? '0') ?? 0,
      subjectRequired: json['subject_required'] == true,
      coursePoint: json['course_point']?.toString(),
      status: json['status']?.toString(),
      weights: json['weights'] != null
          ? GradeWeights.fromJson(json['weights'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OutsideProgramSubject {
  const OutsideProgramSubject({
    required this.subjectCode,
    required this.subjectName,
    required this.credit,
  });

  final String subjectCode;
  final String subjectName;
  final int credit;

  factory OutsideProgramSubject.fromJson(Map<String, dynamic> json) {
    return OutsideProgramSubject(
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      credit: int.tryParse(json['credit']?.toString() ?? '0') ?? 0,
    );
  }
}

class SemesterGroup {
  SemesterGroup({
    required this.semesterKey,
    required this.semesterLabel,
    required this.yearName,
    required this.subjects,
    this.totalCredit,
    this.averagePoint,
  });

  final String semesterKey;
  final String semesterLabel;
  final String yearName;
  final List<GradeSubject> subjects;
  final num? totalCredit;
  final num? averagePoint;

  factory SemesterGroup.fromJson(Map<String, dynamic> json) {
    final subjectsJson = json['subjects'] as List<dynamic>? ?? [];
    return SemesterGroup(
      semesterKey: json['semester_key']?.toString() ?? '',
      semesterLabel: json['semester_label']?.toString() ?? '',
      yearName: json['year_name']?.toString() ?? '',
      totalCredit: json['total_credit'] as num?,
      averagePoint: json['average_point'] as num?,
      subjects: subjectsJson
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
      weights: json['weights'] != null
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
