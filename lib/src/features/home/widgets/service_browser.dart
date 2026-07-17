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
  static const _excludedIds = {'dashboard', 'services', 'notifications'};
  static const _categories = <String, Set<String>>{
    'Tất cả': {},
    'Học tập': {
      'tkb',
      'grades',
      'training_point',
      'transcript_request',
      'lich-thi',
      'exam_postponement',
      'revaluation',
      'khoa-luan',
      'tot-nghiep',
      'khao-sat-giang-day',
      'certificate_validation',
    },
    'Tài chính': {'hoc-phi', 'gia-han-hoc-phi', 'hoc-bong'},
    'Hồ sơ': {
      'profile',
      'student_card',
      'confirmation_paper',
      'thoi-hoc-bao-luu',
      'bao-hiem',
    },
    'Tiện ích': {'parking_registration', 'lich-sinh-hoat', 'ho-tro'},
  };

  String _query = '';
  String _category = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final categoryIds = _categories[_category]!;
    final modules = PortalModuleRegistry.modules.where((module) {
      if (_excludedIds.contains(module.id)) return false;
      if (categoryIds.isNotEmpty && !categoryIds.contains(module.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      return module.title.toLowerCase().contains(query) ||
          module.description.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBar(
          hintText: 'Tìm dịch vụ',
          leading: const Icon(Icons.search),
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
        else
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
      ],
    );
  }
}
