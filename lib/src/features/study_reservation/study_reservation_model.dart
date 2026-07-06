class StudyReservationResponse {
  StudyReservationResponse({
    this.history,
    this.canMutate,
    this.presentStatusName,
    this.error,
  });

  final List<dynamic>? history;
  final bool? canMutate;
  final String? presentStatusName;
  final String? error;

  factory StudyReservationResponse.fromJson(Map<String, dynamic> json) {
    return StudyReservationResponse(
      history: json['history'] as List<dynamic>?,
      canMutate: json['canMutate'] as bool?,
      presentStatusName: json['presentStatusName'] as String?,
      error: json['error'] as String?,
    );
  }
}
