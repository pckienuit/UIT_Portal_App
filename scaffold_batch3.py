import os

features = {
    "thesis_registration": {
        "name": "ThesisRegistration",
        "api": "khoa-luan",
        "title": "Khóa luận",
        "icon": "Icons.book",
        "color": "Colors.purple"
    },
    "graduation_registration": {
        "name": "GraduationRegistration",
        "api": "tot-nghiep",
        "title": "Tốt nghiệp",
        "icon": "Icons.school",
        "color": "Colors.red"
    },
    "scholarship_registration": {
        "name": "ScholarshipRegistration",
        "api": "hoc-bong",
        "title": "Học bổng",
        "icon": "Icons.card_giftcard",
        "color": "Colors.orange"
    },
    "student_support": {
        "name": "StudentSupport",
        "api": "ho-tro",
        "title": "Hỗ trợ SV",
        "icon": "Icons.support_agent",
        "color": "Colors.teal"
    }
}

base_path = "lib/src/features"

for slug, info in features.items():
    name = info["name"]
    api = info["api"]
    title = info["title"]
    
    dir_path = os.path.join(base_path, slug)
    os.makedirs(dir_path, exist_ok=True)
    
    # Model
    model_content = f"""class {name}Response {{
  {name}Response();

  factory {name}Response.fromJson(Map<String, dynamic> json) {{
    return {name}Response();
  }}

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {{
    if (data is List) {{
      return data.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    }} else if (data is Map) {{
      return data.values.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    }}
    return [];
  }}
}}
"""
    with open(os.path.join(dir_path, f"{slug}_model.dart"), "w", encoding="utf-8") as f:
        f.write(model_content)

    # Provider
    provider_content = f"""import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import '{slug}_model.dart';

final {slug}Provider = FutureProvider.autoDispose<{name}Response>((ref) async {{
  final client = ref.watch(portalApiClientProvider);
  final data = await client.fetchModuleData('{api}');
  return {name}Response.fromJson(data);
}});
"""
    with open(os.path.join(dir_path, f"{slug}_providers.dart"), "w", encoding="utf-8") as f:
        f.write(provider_content)
        
    # Screen
    screen_content = f"""import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{slug}_providers.dart';
import '{slug}_model.dart';

class {name}Screen extends ConsumerWidget {{
  const {name}Screen({{super.key}});

  @override
  Widget build(BuildContext context, WidgetRef ref) {{
    final theme = Theme.of(context);
    final state = ref.watch({slug}Provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('{title}'),
        centerTitle: true,
      ),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Lỗi khi tải dữ liệu:\\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate({slug}Provider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              )
            ],
          ),
        ),
      ),
    );
  }}

  Widget _buildContent(BuildContext context, {name}Response data, ThemeData theme) {{
    return const Center(
      child: Text('Dữ liệu đã tải thành công. Cần code giao diện chi tiết.'),
    );
  }}
}}
"""
    with open(os.path.join(dir_path, f"{slug}_screen.dart"), "w", encoding="utf-8") as f:
        f.write(screen_content)

print("Scaffolding Batch 3 complete.")
