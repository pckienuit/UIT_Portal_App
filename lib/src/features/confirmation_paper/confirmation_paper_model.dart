class ConfirmationPaperResponse {
  ConfirmationPaperResponse({
    required this.parameters,
    required this.history,
    this.fullName,
    this.studentCode,
  });

  final List<ConfirmationParameter> parameters;
  final List<ConfirmationHistory> history;
  final String? fullName;
  final String? studentCode;

  factory ConfirmationPaperResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmationPaperResponse(
      parameters: _parseList(json['parameters'], (e) => ConfirmationParameter.fromJson(e as Map<String, dynamic>)),
      history: _parseList(json['history'], (e) => ConfirmationHistory.fromJson(e as Map<String, dynamic>)),
      fullName: json['fullName'] as String?,
      studentCode: json['studentCode'] as String?,
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

class ConfirmationParameter {
  ConfirmationParameter({
    this.id,
    this.parameter,
    this.displayName,
    this.cost,
  });

  final String? id;
  final String? parameter;
  final String? displayName;
  final int? cost;

  factory ConfirmationParameter.fromJson(Map<String, dynamic> json) {
    return ConfirmationParameter(
      id: json['id'] as String?,
      parameter: json['parameter'] as String?,
      displayName: json['display_name'] as String?,
      cost: json['cost'] as int?,
    );
  }
}

class ConfirmationHistory {
  ConfirmationHistory({
    this.id,
    this.certificatePaperCode,
    this.paperName,
    this.quantity,
    this.requestDate,
    this.amountDue,
    this.amountPaid,
    this.status,
  });

  final String? id;
  final String? certificatePaperCode;
  final String? paperName;
  final int? quantity;
  final String? requestDate;
  final int? amountDue;
  final int? amountPaid;
  final String? status;

  factory ConfirmationHistory.fromJson(Map<String, dynamic> json) {
    return ConfirmationHistory(
      id: json['id'] as String?,
      certificatePaperCode: json['certificate_paper_code'] as String?,
      paperName: json['paper_name'] as String?,
      quantity: json['quantity'] as int?,
      requestDate: json['request_date'] as String?,
      amountDue: json['amount_due'] as int?,
      amountPaid: json['amount_paid'] as int?,
      status: json['status'] as String?,
    );
  }
}
