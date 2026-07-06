import 'package:flutter/foundation.dart';

@immutable
class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.maLop,
    required this.maMonHoc,
    required this.tenMonHoc,
    required this.ngay,
    required this.thu,
    required this.tietBatDau,
    required this.tietKetThuc,
    this.phong = '',
    this.giangVien = '',
    this.loaiLich = '',
  });

  final String id;
  final String maLop;
  final String maMonHoc;
  final String tenMonHoc;
  final String ngay;
  final int thu;
  final int tietBatDau;
  final int tietKetThuc;
  final String phong;
  final String giangVien;
  final String loaiLich;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id']?.toString() ?? '',
      maLop: json['maLop']?.toString() ?? '',
      maMonHoc: json['maMonHoc']?.toString() ?? '',
      tenMonHoc: json['tenMonHoc']?.toString() ?? '',
      ngay: json['ngay']?.toString() ?? '',
      thu: _parseInt(json['thu']) ?? 0,
      tietBatDau: _parseInt(json['tietBatDau']) ?? 0,
      tietKetThuc: _parseInt(json['tietKetThuc']) ?? 0,
      phong: json['phong']?.toString() ?? '',
      giangVien: json['giangVien']?.toString() ?? '',
      loaiLich: json['loaiLich']?.toString() ?? '',
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
class ScheduleResponse {
  const ScheduleResponse({
    required this.hocKy,
    required this.namHoc,
    required this.tiets,
  });

  final int hocKy;
  final int namHoc;
  final List<ScheduleItem> tiets;

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    final tietsList = json['tiets'] as List<dynamic>? ?? [];
    return ScheduleResponse(
      hocKy: ScheduleItem._parseInt(json['hocKy']) ?? 0,
      namHoc: ScheduleItem._parseInt(json['namHoc']) ?? 0,
      tiets: tietsList
          .whereType<Map<String, dynamic>>()
          .map(ScheduleItem.fromJson)
          .toList(),
    );
  }
}
