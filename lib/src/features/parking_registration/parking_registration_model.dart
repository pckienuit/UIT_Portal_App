class ParkingRegistrationResponse {
  ParkingRegistrationResponse({
    required this.records,
    this.feeConfig,
  });

  final List<dynamic> records;
  final Map<String, dynamic>? feeConfig;

  factory ParkingRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ParkingRegistrationResponse(
      records: json['records'] as List<dynamic>? ?? [],
      feeConfig: json['feeConfig'] as Map<String, dynamic>?,
    );
  }
}
