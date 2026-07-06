import 'package:flutter/foundation.dart';

@immutable
class ExtracurricularItem {
  const ExtracurricularItem({
    required this.id,
    this.tenHoatDong,
    this.ngayBatDau,
    this.diaDiem,
    this.ghiChu,
  });

  final String id;
  final String? tenHoatDong;
  final String? ngayBatDau;
  final String? diaDiem;
  final String? ghiChu;

  factory ExtracurricularItem.fromJson(Map<String, dynamic> json) {
    return ExtracurricularItem(
      id: json['id']?.toString() ?? '',
      tenHoatDong: json['tenHoatDong']?.toString(),
      ngayBatDau: json['ngayBatDau']?.toString(),
      diaDiem: json['diaDiem']?.toString(),
      ghiChu: json['ghiChu']?.toString(),
    );
  }
}

@immutable
class ExtracurricularResponse {
  const ExtracurricularResponse({
    this.items = const [],
  });

  final List<ExtracurricularItem> items;

  factory ExtracurricularResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return ExtracurricularResponse(
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map(ExtracurricularItem.fromJson)
          .toList(),
    );
  }
}
