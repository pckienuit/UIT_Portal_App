class TranscriptRequestResponse {
  TranscriptRequestResponse({
    required this.parameters,
    required this.history,
    this.feePaymentLocation,
  });

  final List<TranscriptParameter> parameters;
  final List<dynamic> history;
  final String? feePaymentLocation;

  factory TranscriptRequestResponse.fromJson(Map<String, dynamic> json) {
    return TranscriptRequestResponse(
      parameters: (json['parameters'] as List<dynamic>?)
              ?.map((e) => TranscriptParameter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      history: json['history'] as List<dynamic>? ?? [],
      feePaymentLocation: json['feePaymentLocation'] as String?,
    );
  }
}

class TranscriptParameter {
  TranscriptParameter({
    this.id,
    this.parameter,
    this.displayName,
    this.cost,
  });

  final String? id;
  final String? parameter;
  final String? displayName;
  final int? cost;

  factory TranscriptParameter.fromJson(Map<String, dynamic> json) {
    return TranscriptParameter(
      id: json['id'] as String?,
      parameter: json['parameter'] as String?,
      displayName: json['display_name'] as String?,
      cost: json['cost'] as int?,
    );
  }
}
