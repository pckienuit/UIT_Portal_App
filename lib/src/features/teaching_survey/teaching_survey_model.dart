import 'package:flutter/foundation.dart';

@immutable
class SurveyItem {
  const SurveyItem({
    required this.id,
    this.tenMonHoc,
    this.maLop,
    this.giangVien,
    this.isDone,
    this.linkKhaoSat,
  });

  final String id;
  final String? tenMonHoc;
  final String? maLop;
  final String? giangVien;
  final bool? isDone;
  final String? linkKhaoSat;

  factory SurveyItem.fromJson(Map<String, dynamic> json) {
    return SurveyItem(
      id: json['id']?.toString() ?? '',
      tenMonHoc: json['tenMonHoc']?.toString(),
      maLop: json['maLop']?.toString(),
      giangVien: json['giangVien']?.toString(),
      isDone: json['isDone'] as bool?,
      linkKhaoSat: json['linkKhaoSat']?.toString(),
    );
  }
}

@immutable
class TeachingSurveyResponse {
  const TeachingSurveyResponse({
    this.items = const [],
    this.pendingCount = 0,
    this.doneCount = 0,
  });

  final List<SurveyItem> items;
  final int pendingCount;
  final int doneCount;

  factory TeachingSurveyResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return TeachingSurveyResponse(
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map(SurveyItem.fromJson)
          .toList(),
      pendingCount: _parseInt(json['pendingCount']) ?? 0,
      doneCount: _parseInt(json['doneCount']) ?? 0,
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
