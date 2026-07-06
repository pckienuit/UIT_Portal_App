import 'package:flutter/foundation.dart';

@immutable
class ExamItem {
  const ExamItem({
    required this.id,
    required this.maMonHoc,
    required this.tenMonHoc,
    required this.maLop,
    this.ngayThi,
    this.caThi,
    this.gioBatDau,
    this.gioKetThuc,
    this.tietBatDau,
    this.tietKetThuc,
    this.phong,
    this.hinhThuc,
    this.kyThi,
    this.namHoc,
    this.hocKy,
  });

  final String id;
  final String maMonHoc;
  final String tenMonHoc;
  final String maLop;
  final String? ngayThi;
  final int? caThi;
  final String? gioBatDau;
  final String? gioKetThuc;
  final int? tietBatDau;
  final int? tietKetThuc;
  final String? phong;
  final String? hinhThuc;
  final String? kyThi;
  final dynamic namHoc; // Could be int or string depending on API
  final dynamic hocKy;

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      id: json['id']?.toString() ?? '',
      maMonHoc: json['maMonHoc']?.toString() ?? '',
      tenMonHoc: json['tenMonHoc']?.toString() ?? '',
      maLop: json['maLop']?.toString() ?? '',
      ngayThi: json['ngayThi']?.toString(),
      caThi: _parseInt(json['caThi']),
      gioBatDau: json['gioBatDau']?.toString(),
      gioKetThuc: json['gioKetThuc']?.toString(),
      tietBatDau: _parseInt(json['tietBatDau']),
      tietKetThuc: _parseInt(json['tietKetThuc']),
      phong: json['phong']?.toString(),
      hinhThuc: json['hinhThuc']?.toString(),
      kyThi: json['kyThi']?.toString(),
      namHoc: json['namHoc'],
      hocKy: json['hocKy'],
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }
}

@immutable
class ExamScheduleResponse {
  const ExamScheduleResponse({
    this.items = const [],
  });

  final List<ExamItem> items;

  factory ExamScheduleResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return ExamScheduleResponse(
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map(ExamItem.fromJson)
          .toList(),
    );
  }
}
