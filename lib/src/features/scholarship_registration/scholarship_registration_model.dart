class ScholarshipRegistrationResponse {
  ScholarshipRegistrationResponse({
    required this.scholarships,
    this.presentStatusName,
  });

  final List<dynamic> scholarships;
  final String? presentStatusName;

  factory ScholarshipRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ScholarshipRegistrationResponse(
      scholarships: _parseList(json['scholarships'], (e) => e),
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
