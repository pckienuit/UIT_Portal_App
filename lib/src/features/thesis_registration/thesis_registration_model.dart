class ThesisRegistrationResponse {
  ThesisRegistrationResponse({
    this.hasThesis,
    this.message,
    this.presentStatusName,
  });

  final bool? hasThesis;
  final String? message;
  final String? presentStatusName;

  factory ThesisRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ThesisRegistrationResponse(
      hasThesis: json['hasThesis'] as bool?,
      message: json['message'] as String?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }
}
