class ParkingRegistrationResponse {
  ParkingRegistrationResponse({
    required this.records,
    this.feeConfig,
    this.canMutate = true,
    this.presentStatusName,
  });

  final List<ParkingRecord> records;
  final Map<String, dynamic>? feeConfig;
  final bool? canMutate;
  final String? presentStatusName;

  factory ParkingRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ParkingRegistrationResponse(
      records: _parseList(json['records'], (e) => ParkingRecord.fromJson(e)),
      feeConfig: json['feeConfig'] as Map<String, dynamic>?,
      canMutate: json['canMutate'] as bool?,
      presentStatusName: json['presentStatusName'] as String?,
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
    this.dbId,
    this.vehicleType,
    this.licensePlateNumber,
    this.numberOfMonths,
    this.registrationTime,
    this.paymentTime,
    this.effectiveDate,
    this.amountDue,
    this.amountPaid,
    this.status,
    this.qrCode,
  });

  final String? id;
  final int? dbId;
  final String? vehicleType;
  final String? licensePlateNumber;
  final int? numberOfMonths;
  final String? registrationTime;
  final String? paymentTime;
  final String? effectiveDate;
  final int? amountDue;
  final int? amountPaid;
  final String? status;
  final String? qrCode;

  factory ParkingRecord.fromJson(Map<String, dynamic> json) {
    return ParkingRecord(
      id: json['id']?.toString(),
      dbId: json['dbId'] is int
          ? json['dbId'] as int
          : int.tryParse(json['dbId']?.toString() ?? ''),
      vehicleType: json['vehicle_type'] as String?,
      licensePlateNumber: json['license_plate_number'] as String?,
      numberOfMonths: json['number_of_months'] is int
          ? json['number_of_months'] as int
          : (json['months_registered'] is int ? json['months_registered'] as int : null),
      registrationTime: json['registration_time'] as String?,
      paymentTime: json['payment_time'] as String?,
      effectiveDate: json['effective_date'] as String?,
      amountDue: json['amount_due'] is int ? json['amount_due'] as int : null,
      amountPaid: json['amount_paid'] is int ? json['amount_paid'] as int : null,
      status: json['status'] as String?,
      qrCode: json['qr_code'] as String?,
    );
  }
}

class ParkingRegistrationRequest {
  const ParkingRegistrationRequest({
    required this.licensePlateNumber,
    required this.vehicleType,
    required this.numberOfMonths,
  });

  final String licensePlateNumber;
  final String vehicleType; // 'motorcycle' | 'bicycle'
  final int numberOfMonths; // 1..12

  Map<String, dynamic> toJson() {
    return {
      'vehicle_type': vehicleType,
      'license_plate_number': licensePlateNumber.trim().toUpperCase(),
      'months_registered': numberOfMonths,
    };
  }
}
