class GraduationRegistrationResponse {
  GraduationRegistrationResponse({this.error, this.presentStatusName});

  final String? error;
  final String? presentStatusName;

  factory GraduationRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return GraduationRegistrationResponse(
      error: json['error'] as String?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }
}
