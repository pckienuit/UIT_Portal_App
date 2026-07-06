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

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    } else if (data is Map) {
      return data.values.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    }
    return [];
  }
}
