class ConfirmationPaperResponse {
  ConfirmationPaperResponse({
    required this.history,
    this.fullName,
    this.studentCode,
  });

  final List<dynamic> history;
  final String? fullName;
  final String? studentCode;

  factory ConfirmationPaperResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmationPaperResponse(
      history: json['history'] as List<dynamic>? ?? [],
      fullName: json['fullName'] as String?,
      studentCode: json['studentCode'] as String?,
    );
  }
}
