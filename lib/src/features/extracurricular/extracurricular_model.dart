class ExtracurricularResponse {
  ExtracurricularResponse({
    this.records,
    this.canMutate,
    this.presentStatusName,
  });

  final List<dynamic>? records;
  final bool? canMutate;
  final String? presentStatusName;

  factory ExtracurricularResponse.fromJson(Map<String, dynamic> json) {
    return ExtracurricularResponse(
      records: json['records'] as List<dynamic>?,
      canMutate: json['canMutate'] as bool?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }
}
