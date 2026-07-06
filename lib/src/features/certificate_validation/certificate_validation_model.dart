class CertificateValidationResponse {
  CertificateValidationResponse({
    required this.certs,
    required this.certTypes,
  });

  final List<CertificateRecord> certs;
  final List<CertificateType> certTypes;

  factory CertificateValidationResponse.fromJson(Map<String, dynamic> json) {
    return CertificateValidationResponse(
      certs: (json['certs'] as List<dynamic>?)
              ?.map((e) => CertificateRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      certTypes: (json['certTypes'] as List<dynamic>?)
              ?.map((e) => CertificateType.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CertificateRecord {
  CertificateRecord({
    this.id,
    this.name,
    this.status,
    this.submitDate,
    this.note,
  });

  final String? id;
  final String? name;
  final String? status;
  final String? submitDate;
  final String? note;

  factory CertificateRecord.fromJson(Map<String, dynamic> json) {
    return CertificateRecord(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      status: json['status'] as String?,
      submitDate: json['submit_date'] as String?,
      note: json['note'] as String?,
    );
  }
}

class CertificateType {
  CertificateType({
    this.id,
    this.code,
    this.name,
    this.type,
    this.abbrName,
  });

  final int? id;
  final String? code;
  final String? name;
  final String? type;
  final String? abbrName;

  factory CertificateType.fromJson(Map<String, dynamic> json) {
    return CertificateType(
      id: json['id'] as int?,
      code: json['code'] as String?,
      name: json['name'] as String?,
      type: json['type'] as String?,
      abbrName: json['abbrName'] as String?,
    );
  }
}
