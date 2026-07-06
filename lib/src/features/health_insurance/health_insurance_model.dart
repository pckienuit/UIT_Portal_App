class HealthInsuranceConfig {
  HealthInsuranceConfig({
    this.id,
    this.period,
    this.year,
    this.amount,
    this.note,
    this.searchLink,
    this.startDate,
    this.endDate,
  });

  final int? id;
  final int? period;
  final String? year;
  final int? amount;
  final String? note;
  final String? searchLink;
  final String? startDate;
  final String? endDate;

  factory HealthInsuranceConfig.fromJson(Map<String, dynamic> json) {
    return HealthInsuranceConfig(
      id: json['id'] as int?,
      period: json['period'] as int?,
      year: json['year'] as String?,
      amount: json['amount'] as int?,
      note: json['note'] as String?,
      searchLink: json['search_link'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }
}

class HealthInsuranceProfile {
  HealthInsuranceProfile({
    this.insuranceCode,
    this.insurancePeriod,
    this.insuranceType,
    this.hasIdImages,
  });

  final String? insuranceCode;
  final String? insurancePeriod;
  final String? insuranceType;
  final bool? hasIdImages;

  factory HealthInsuranceProfile.fromJson(Map<String, dynamic> json) {
    return HealthInsuranceProfile(
      insuranceCode: json['insurance_code'] as String?,
      insurancePeriod: json['insurance_period'] as String?,
      insuranceType: json['insurance_type'] as String?,
      hasIdImages: json['has_id_images'] as bool?,
    );
  }
}

class HealthHospital {
  HealthHospital({
    this.id,
    this.code,
    this.name,
  });

  final int? id;
  final String? code;
  final String? name;

  factory HealthHospital.fromJson(Map<String, dynamic> json) {
    return HealthHospital(
      id: json['id'] as int?,
      code: json['code'] as String?,
      name: json['name'] as String?,
    );
  }
}

class HealthInsuranceResponse {
  HealthInsuranceResponse({
    this.config,
    this.profile,
    this.hospitals,
    this.existedPurchase,
    this.existedUpdate,
    this.canMutate,
    this.presentStatusName,
  });

  final HealthInsuranceConfig? config;
  final HealthInsuranceProfile? profile;
  final List<HealthHospital>? hospitals;
  final dynamic existedPurchase;
  final dynamic existedUpdate;
  final bool? canMutate;
  final String? presentStatusName;

  factory HealthInsuranceResponse.fromJson(Map<String, dynamic> json) {
    return HealthInsuranceResponse(
      config: json['config'] != null ? HealthInsuranceConfig.fromJson(json['config']) : null,
      profile: json['profile'] != null ? HealthInsuranceProfile.fromJson(json['profile']) : null,
      hospitals: (json['hospitals'] as List<dynamic>?)
          ?.map((e) => HealthHospital.fromJson(e as Map<String, dynamic>))
          .toList(),
      existedPurchase: json['existed_purchase'],
      existedUpdate: json['existed_update'],
      canMutate: json['canMutate'] as bool?,
      presentStatusName: json['presentStatusName'] as String?,
    );
  }
}
