class StudentProfile {
  // Session User Info (from basic user object)
  final String? sub;
  final String? username;
  final String? displayName;
  final String? email;
  final String? role;

  // Detailed Profile Info
  final int? studentId;
  final String? studentCode;
  final String? fullName;
  final String? avatarUrl;
  final PersonalInfo? personal;
  final MembershipInfo? membership;
  final BankInfo? bank;
  final BackgroundInfo? background;
  final FamilyInfo? family;
  final AcademicInfo? academic;

  StudentProfile({
    this.sub,
    this.username,
    this.displayName,
    this.email,
    this.role,
    this.studentId,
    this.studentCode,
    this.fullName,
    this.avatarUrl,
    this.personal,
    this.membership,
    this.bank,
    this.background,
    this.family,
    this.academic,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json, {AcademicInfo? academic, Map<String, dynamic>? sessionUser}) {
    return StudentProfile(
      sub: sessionUser?['sub'] as String?,
      username: sessionUser?['username'] as String?,
      displayName: sessionUser?['displayName'] as String?,
      email: sessionUser?['email'] as String?,
      role: sessionUser?['role'] as String?,
      studentId: json['studentId'] as int?,
      studentCode: json['studentCode'] as String?,
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      personal: json['personal'] != null ? PersonalInfo.fromJson(json['personal'] as Map<String, dynamic>) : null,
      membership: json['membership'] != null ? MembershipInfo.fromJson(json['membership'] as Map<String, dynamic>) : null,
      bank: json['bank'] != null ? BankInfo.fromJson(json['bank'] as Map<String, dynamic>) : null,
      background: json['background'] != null ? BackgroundInfo.fromJson(json['background'] as Map<String, dynamic>) : null,
      family: json['family'] != null ? FamilyInfo.fromJson(json['family'] as Map<String, dynamic>) : null,
      academic: academic,
    );
  }
}

class AcademicInfo {
  final String? cohort;
  final String? className;
  final String? major;

  AcademicInfo({this.cohort, this.className, this.major});
}

class PersonalInfo {
  final String? fullName;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String? ethnicity;
  final String? religion;
  final String? nationality;
  final String? maritalStatus;
  final String? idCardNumber;
  final String? idCardIssueDate;
  final String? idCardIssuePlace;
  final String? schoolEmail;
  final String? personalEmail;
  final String? phone;
  final String? fbAddress;
  final String? permanentAddress;
  final String? currentAddress;
  final String? bloodType;
  final int? heightCm;
  final int? weightKg;

  PersonalInfo({
    this.fullName,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.ethnicity,
    this.religion,
    this.nationality,
    this.maritalStatus,
    this.idCardNumber,
    this.idCardIssueDate,
    this.idCardIssuePlace,
    this.schoolEmail,
    this.personalEmail,
    this.phone,
    this.fbAddress,
    this.permanentAddress,
    this.currentAddress,
    this.bloodType,
    this.heightCm,
    this.weightKg,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      fullName: json['full_name'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      placeOfBirth: json['place_of_birth'] as String?,
      ethnicity: json['ethnicity'] as String?,
      religion: json['religion'] as String?,
      nationality: json['nationality'] as String?,
      maritalStatus: json['marital_status'] as String?,
      idCardNumber: json['id_card_number'] as String?,
      idCardIssueDate: json['id_card_issue_date'] as String?,
      idCardIssuePlace: json['id_card_issue_place'] as String?,
      schoolEmail: json['school_email'] as String?,
      personalEmail: json['personal_email'] as String?,
      phone: json['phone'] as String?,
      fbAddress: json['fb_address'] as String?,
      permanentAddress: json['permanent_address'] as String?,
      currentAddress: json['current_address'] as String?,
      bloodType: json['blood_type'] as String?,
      heightCm: json['height_cm'] as int?,
      weightKg: json['weight_kg'] as int?,
    );
  }
}

class MembershipInfo {
  final bool? memberStatus;
  final String? memberDate;
  final bool? partyMemberStatus;
  final String? partyMemberDate;
  final String? highestPosition;
  final String? educationAndWorkHistory;
  final String? achievementsAndAwards;

  MembershipInfo({
    this.memberStatus,
    this.memberDate,
    this.partyMemberStatus,
    this.partyMemberDate,
    this.highestPosition,
    this.educationAndWorkHistory,
    this.achievementsAndAwards,
  });

  factory MembershipInfo.fromJson(Map<String, dynamic> json) {
    return MembershipInfo(
      memberStatus: json['member_status'] as bool?,
      memberDate: json['member_date'] as String?,
      partyMemberStatus: json['party_member_status'] as bool?,
      partyMemberDate: json['party_member_date'] as String?,
      highestPosition: json['highest_position'] as String?,
      educationAndWorkHistory: json['education_and_work_history'] as String?,
      achievementsAndAwards: json['achievements_and_awards'] as String?,
    );
  }
}

class BankInfo {
  final String? bankName;
  final String? accountNumber;
  final String? branch;

  BankInfo({this.bankName, this.accountNumber, this.branch});

  factory BankInfo.fromJson(Map<String, dynamic> json) {
    return BankInfo(
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      branch: json['branch'] as String?,
    );
  }
}

class BackgroundInfo {
  final String? priorityHouseholdType;
  final String? detailedObject;
  final String? background;
  final String? region;
  final String? studentArea;
  final String? policy;

  BackgroundInfo({
    this.priorityHouseholdType,
    this.detailedObject,
    this.background,
    this.region,
    this.studentArea,
    this.policy,
  });

  factory BackgroundInfo.fromJson(Map<String, dynamic> json) {
    return BackgroundInfo(
      priorityHouseholdType: json['priority_household_type'] as String?,
      detailedObject: json['detailed_object'] as String?,
      background: json['background'] as String?,
      region: json['region'] as String?,
      studentArea: json['student_area'] as String?,
      policy: json['policy'] as String?,
    );
  }
}

class FamilyInfo {
  final ParentInfo? father;
  final ParentInfo? mother;

  FamilyInfo({this.father, this.mother});

  factory FamilyInfo.fromJson(Map<String, dynamic> json) {
    return FamilyInfo(
      father: json['father'] != null ? ParentInfo.fromJson(json['father'] as Map<String, dynamic>) : null,
      mother: json['mother'] != null ? ParentInfo.fromJson(json['mother'] as Map<String, dynamic>) : null,
    );
  }
}

class ParentInfo {
  final bool? isDeceasedOrUnknown;
  final String? fullName;
  final String? dateOfBirth;
  final String? occupation;
  final String? phone;
  final String? email;
  final String? nationality;
  final String? ethnicity;
  final String? religion;
  final String? permanentAddress;

  ParentInfo({
    this.isDeceasedOrUnknown,
    this.fullName,
    this.dateOfBirth,
    this.occupation,
    this.phone,
    this.email,
    this.nationality,
    this.ethnicity,
    this.religion,
    this.permanentAddress,
  });

  factory ParentInfo.fromJson(Map<String, dynamic> json) {
    return ParentInfo(
      isDeceasedOrUnknown: json['is_deceased_or_unknown'] as bool?,
      fullName: json['full_name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      occupation: json['occupation'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      nationality: json['nationality'] as String?,
      ethnicity: json['ethnicity'] as String?,
      religion: json['religion'] as String?,
      permanentAddress: json['permanent_address'] as String?,
    );
  }
}
