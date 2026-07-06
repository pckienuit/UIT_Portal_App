class StudentCardResponse {
  StudentCardResponse({
    required this.records,
  });

  final List<dynamic> records;

  factory StudentCardResponse.fromJson(Map<String, dynamic> json) {
    return StudentCardResponse(
      records: json['records'] as List<dynamic>? ?? [],
    );
  }
}
