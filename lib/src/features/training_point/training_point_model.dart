class TrainingPointResponse {
  TrainingPointResponse({
    this.averageTrainingPoint,
    this.averageRank,
    required this.trainingPointHistory,
  });

  final double? averageTrainingPoint;
  final String? averageRank;
  final List<TrainingPointHistory> trainingPointHistory;

  factory TrainingPointResponse.fromJson(Map<String, dynamic> json) {
    return TrainingPointResponse(
      averageTrainingPoint: (json['average_training_point'] as num?)?.toDouble(),
      averageRank: json['average_rank'] as String?,
      trainingPointHistory: (json['training_point_history'] as List<dynamic>?)
              ?.map((e) => TrainingPointHistory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TrainingPointHistory {
  TrainingPointHistory({
    this.id,
    this.semester,
    this.semesterLabel,
    this.yearName,
    this.specializedClassName,
    this.point,
    this.rank,
  });

  final String? id;
  final String? semester;
  final String? semesterLabel;
  final String? yearName;
  final String? specializedClassName;
  final int? point;
  final String? rank;

  factory TrainingPointHistory.fromJson(Map<String, dynamic> json) {
    return TrainingPointHistory(
      id: json['id'] as String?,
      semester: json['semester'] as String?,
      semesterLabel: json['semester_label'] as String?,
      yearName: json['year_name'] as String?,
      specializedClassName: json['specialized_class_name'] as String?,
      point: json['point'] as int?,
      rank: json['rank'] as String?,
    );
  }
}
