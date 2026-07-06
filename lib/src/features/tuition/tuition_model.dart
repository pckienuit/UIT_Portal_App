num _parseNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

class TuitionResponse {
  final List<TuitionRecord> records;

  TuitionResponse({required this.records});

  factory TuitionResponse.fromJson(Map<String, dynamic> json) {
    final recordsList = json['records'] as List?;
    return TuitionResponse(
      records: recordsList?.map((e) => TuitionRecord.fromJson(e)).toList() ?? [],
    );
  }
}

class TuitionRecord {
  final String? id;
  final String? period;
  final String? yearId;
  final num tuitionAmount;
  final num tuitionCreditNumber;
  final num mustBePaid;
  final num paid;
  final num remaining;
  final num debtInAdvance;
  final String? paymentStatus;
  final String? latePaymentDate;
  final String? paidTime;
  final String? note;
  final List<TuitionDetail> details;
  final List<TuitionPayment> payments;
  final String? qrCode;

  // Computed properties
  String get semesterLabel {
    if (period == null) return '';
    final parts = period!.split('/');
    if (parts.isEmpty) return period!;
    return parts[0].trim();
  }

  String get yearName {
    if (period == null) return yearId ?? '';
    final parts = period!.split('/');
    if (parts.length < 2) return yearId ?? '';
    return parts.sublist(1).join('/').trim();
  }
  
  num get totalAmount => tuitionAmount;
  num get amountPaid => paid;
  num get amountDue => remaining;

  TuitionRecord({
    this.id,
    this.period,
    this.yearId,
    required this.tuitionAmount,
    required this.tuitionCreditNumber,
    required this.mustBePaid,
    required this.paid,
    required this.remaining,
    required this.debtInAdvance,
    this.paymentStatus,
    this.latePaymentDate,
    this.paidTime,
    this.note,
    required this.details,
    required this.payments,
    this.qrCode,
  });

  factory TuitionRecord.fromJson(Map<String, dynamic> json) {
    final detailsList = json['detail_ids'] as List?;
    final paymentsList = json['payment_ids'] as List?;

    var qr = json['qr_code'];
    String? parsedQrCode;
    if (qr is String && qr.isNotEmpty) {
      parsedQrCode = qr.startsWith('data:') ? qr : 'data:image/png;base64,$qr';
    }

    return TuitionRecord(
      id: json['id']?.toString(),
      period: json['period']?.toString() ?? json['semester']?.toString(),
      yearId: json['year_id']?.toString(),
      tuitionAmount: _parseNum(json['tuition_amount']),
      tuitionCreditNumber: _parseNum(json['tuition_credit_number']),
      mustBePaid: _parseNum(json['must_be_paid'] ?? json['tuition_amount']),
      paid: _parseNum(json['paid']),
      remaining: _parseNum(json['remaining']),
      debtInAdvance: _parseNum(json['debt_in_advance']),
      paymentStatus: json['payment_status']?.toString(),
      latePaymentDate: json['late_payment_date']?.toString(),
      paidTime: json['paid_time']?.toString(),
      note: json['note']?.toString(),
      details: detailsList?.map((e) => TuitionDetail.fromJson(e)).toList() ?? [],
      payments: paymentsList?.map((e) => TuitionPayment.fromJson(e)).toList() ?? [],
      qrCode: parsedQrCode,
    );
  }
}

class TuitionDetail {
  final String? id;
  final String? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final num tuitionCreditNumber;
  final num unitPrice;
  final num additionalTuition;
  final num amount;
  final String? note;

  String get computedSubjectCode {
    if (subjectCode != null && subjectCode!.trim().isNotEmpty) return subjectCode!.trim();
    if (subjectName != null && subjectName!.contains(' - ')) {
       return subjectName!.split(' - ')[0].trim();
    }
    return '';
  }

  TuitionDetail({
    this.id,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    required this.tuitionCreditNumber,
    required this.unitPrice,
    required this.additionalTuition,
    required this.amount,
    this.note,
  });

  factory TuitionDetail.fromJson(Map<String, dynamic> json) {
    return TuitionDetail(
      id: json['id']?.toString(),
      subjectId: json['subject_id']?.toString(),
      subjectCode: json['subject_code']?.toString(),
      subjectName: json['subject_name']?.toString() ?? json['subject_id_name']?.toString(),
      tuitionCreditNumber: _parseNum(json['tuition_credit_number']),
      unitPrice: _parseNum(json['unit_price']),
      additionalTuition: _parseNum(json['additional_tuition']),
      amount: _parseNum(json['amount']),
      note: json['note']?.toString(),
    );
  }
}

class TuitionPayment {
  final String? id;
  final num amount;
  final String? paymentTime;
  final String? bankName;
  final String? transId;
  final String? invoiceCode;
  final String? status;

  TuitionPayment({
    this.id,
    required this.amount,
    this.paymentTime,
    this.bankName,
    this.transId,
    this.invoiceCode,
    this.status,
  });

  factory TuitionPayment.fromJson(Map<String, dynamic> json) {
    return TuitionPayment(
      id: json['id']?.toString(),
      amount: _parseNum(json['amount']),
      paymentTime: json['payment_time']?.toString(),
      bankName: json['bank_name']?.toString(),
      transId: json['trans_id']?.toString(),
      invoiceCode: json['invoice_code']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
