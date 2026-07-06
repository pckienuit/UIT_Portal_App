class CertificateValidationResponse {
  CertificateValidationResponse({
    required this.certs,
    required this.certTypes,
  });

  final List<dynamic> certs;
  final List<dynamic> certTypes;

  factory CertificateValidationResponse.fromJson(Map<String, dynamic> json) {
    return CertificateValidationResponse(
      certs: json['certs'] as List<dynamic>? ?? [],
      certTypes: json['certTypes'] as List<dynamic>? ?? [],
    );
  }
}
