class TuitionExtensionResponse {
  TuitionExtensionResponse({
    this.periodStatusOpen,
    this.history,
    this.canMutate,
    this.presentStatusName,
  });

  final bool? periodStatusOpen;
  final List<dynamic>? history;
  final bool? canMutate;
  final String? presentStatusName;

  factory TuitionExtensionResponse.fromJson(Map<String, dynamic> json) {
    return TuitionExtensionResponse(
      periodStatusOpen: (json['periodStatus'] as Map<String, dynamic>?)?['open'] as bool?,
      history: json['history'] as List<dynamic>?,
      canMutate: json['canMutate'] as bool?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }
}
