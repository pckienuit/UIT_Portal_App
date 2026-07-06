class GraduationRegistrationResponse {
  GraduationRegistrationResponse({
    this.error,
    this.presentStatusName,
  });

  final String? error;
  final String? presentStatusName;

  factory GraduationRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return GraduationRegistrationResponse(
      error: json['error'] as String?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    } else if (data is Map) {
      return data.values.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    }
    return [];
  }
}
