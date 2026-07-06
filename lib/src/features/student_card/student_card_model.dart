class StudentCardResponse {
  StudentCardResponse({
    required this.records,
  });

  final List<dynamic> records;

  factory StudentCardResponse.fromJson(Map<String, dynamic> json) {
    return StudentCardResponse(
      records: _parseList(json['records'], (e) => e),
    );
  }

  static List<T> _parseList<T>(dynamic data, T Function(dynamic) fromJson) {
    if (data is List) {
      return data.map((e) => fromJson(e)).toList();
    } else if (data is Map) {
      return data.values.map((e) => fromJson(e)).toList();
    }
    return [];
  }
}
