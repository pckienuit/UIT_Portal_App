import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../portal_module_registry.dart';
import 'service_tile.dart';

class ServiceBrowser extends StatefulWidget {
  const ServiceBrowser({super.key, this.onModuleSelected});

  final ValueChanged<PortalModule>? onModuleSelected;

  @override
  State<ServiceBrowser> createState() => _ServiceBrowserState();
}

class _ServiceBrowserState extends State<ServiceBrowser> {
  // Ẩn/loại bỏ các dịch vụ ít dùng hoặc đã có tab/nút riêng theo yêu cầu:
  // - profile: Thông tin cá nhân (đã có tab Cá nhân ở Navbar)
  // - notifications: Thông báo (đã có floating button/header action)
  // - confirmation_paper: Giấy xác nhận
  // - certificate_validation: Xác nhận chứng chỉ
  // - exam_postponement: Hoãn thi & Thi lại
  // - revaluation: Phúc khảo điểm
  // - ho-tro: Hỗ trợ SV
  // - student_card: Thẻ SV
  // - thoi-hoc-bao-luu: Bảo lưu
  // - gia-han-hoc-phi: Gia hạn học phí
  // - transcript_request: Xin bảng điểm
  // - khoa-luan: Khóa luận
  // - tot-nghiep: Tốt nghiệp
  // - hoc-bong: Học bổng
  static const _excludedIds = {
    'dashboard',
    'services',
    'profile',
    'notifications',
    'confirmation_paper',
    'certificate_validation',
    'exam_postponement',
    'revaluation',
    'ho-tro',
    'student_card',
    'thoi-hoc-bao-luu',
    'gia-han-hoc-phi',
    'transcript_request',
    'khoa-luan',
    'tot-nghiep',
    'hoc-bong',
  };

  static const _categories = <String, Set<String>>{
    'Tất cả': {},
    'Học tập': {
      'tkb',
      'grades',
      'training_point',
      'lich-thi',
      'khao-sat-giang-day',
    },
    'Tài chính': {'hoc-phi'},
    'Hồ sơ': {'bao-hiem'},
    'Tiện ích': {
      'parking_registration',
      'lich-sinh-hoat',
    },
  };

  String _query = '';
  String _category = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _normalizeVietnamese(_query.trim());
    final categoryIds = _categories[_category]!;
    final modules = PortalModuleRegistry.modules.where((module) {
      if (_excludedIds.contains(module.id)) return false;
      if (categoryIds.isNotEmpty && !categoryIds.contains(module.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      return _normalizeVietnamese(module.title).contains(query) ||
          _normalizeVietnamese(module.description).contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBar(
          hintText: 'Tìm dịch vụ',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.keys.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (modules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 40),
                SizedBox(height: 8),
                Text('Không tìm thấy dịch vụ phù hợp'),
              ],
            ),
          )
        else ...[
          ...modules.map(
            (module) => ServiceTile(
              key: ValueKey(module.id),
              module: module,
              onTap: () {
                final onModuleSelected = widget.onModuleSelected;
                if (onModuleSelected != null) {
                  onModuleSelected(module);
                } else {
                  context.push('/module/${module.id}');
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Các dịch vụ trên ứng dụng có thể không đầy đủ so với cổng thông tin web portal.uit.edu.vn.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _normalizeVietnamese(String value) {
    const accented = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
      'đ',
    ];
    const plain = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
    var normalized = value.toLowerCase();
    for (var group = 0; group < accented.length; group++) {
      for (final character in accented[group].split('')) {
        normalized = normalized.replaceAll(character, plain[group]);
      }
    }
    return normalized.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }
}
