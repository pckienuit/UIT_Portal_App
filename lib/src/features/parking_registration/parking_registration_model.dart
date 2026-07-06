class ParkingRegistrationResponse {
  ParkingRegistrationResponse({required this.records, this.feeConfig});

  final List<ParkingRecord> records;
  final Map<String, dynamic>? feeConfig;

  factory ParkingRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ParkingRegistrationResponse(
      records: _parseList(json['records'], (e) => ParkingRecord.fromJson(e)),
      feeConfig: json['feeConfig'] as Map<String, dynamic>?,
    );
  }

  static List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(e))
          .toList();
    } else if (data is Map) {
      return data.values
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(e))
          .toList();
    }
    return [];
  }
}

class ParkingRecord {
  ParkingRecord({
    this.id,
    this.vehicleType,
    this.licensePlateNumber,
    this.numberOfMonths,
    this.registrationTime,
    this.paymentTime,
    this.effectiveDate,
    this.amountDue,
    this.amountPaid,
    this.status,
  });

  final String? id;
  final String? vehicleType;
  final String? licensePlateNumber;
  final int? numberOfMonths;
  final String? registrationTime;
  final String? paymentTime;
  final String? effectiveDate;
  final int? amountDue;
  final int? amountPaid;
  final String? status;

  factory ParkingRecord.fromJson(Map<String, dynamic> json) {
    return ParkingRecord(
      id: json['id']?.toString(),
      vehicleType: json['vehicle_type'] as String?,
      licensePlateNumber: json['license_plate_number'] as String?,
      numberOfMonths: json['number_of_months'] as int?,
      registrationTime: json['registration_time'] as String?,
      paymentTime: json['payment_time'] as String?,
      effectiveDate: json['effective_date'] as String?,
      amountDue: json['amount_due'] as int?,
      amountPaid: json['amount_paid'] as int?,
      status: json['status'] as String?,
    );
  }
}
