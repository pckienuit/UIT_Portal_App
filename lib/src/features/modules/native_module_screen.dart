import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../profile/profile_screen.dart';
import '../../portal_module_registry.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_controller.dart';
import '../../data/portal_api_client.dart';
import '../../data/portal_api_providers.dart';

class NativeModuleScreen extends ConsumerWidget {
  const NativeModuleScreen({super.key, required this.module});

  final PortalModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: SafeArea(
        child: switch (module.id) {
          'dashboard' => const _DashboardNativeBody(),
          'profile' => _PendingApiBody(module: module),
          'services' => _PendingApiBody(module: module),
          'notifications' => _PendingApiBody(module: module),
          _ => _PendingApiBody(module: module),
        },
      ),
    );
  }
}

class _DashboardNativeBody extends ConsumerWidget {
  const _DashboardNativeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final apiClient = ref.watch(portalApiClientProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NativeInfoPanel(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard native',
          message:
              'Màn hình này đã được render bằng Flutter. Các dữ liệu động sẽ được nối sau khi API portal được inventory.',
        ),
        const SizedBox(height: 12),
        _NativeInfoPanel(
          icon: auth.isSignedIn ? Icons.verified_user : Icons.lock_outline,
          title: auth.isSignedIn ? 'Đã đăng nhập' : 'Chưa đăng nhập',
          message: auth.isSignedIn
              ? 'App đã có phiên SSO native.'
              : 'Đăng nhập UIT SSO để lấy phiên phục vụ các màn native.',
        ),
        if (auth.isSignedIn) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Đường dẫn (VD: /sinh-vien, /trang-chu)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _testRscPayload(context, apiClient, auth),
            child: const Text('Fetch RSC (Next.js)'),
          ),
        ],
      ],
    );
  }
}

final TextEditingController _urlController = TextEditingController(
  text: '/sinh-vien/ly-lich',
);

extension on _DashboardNativeBody {
  Future<void> _testRscPayload(
    BuildContext context,
    PortalApiClient client,
    AuthController auth,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Đang fetch...'),
          ],
        ),
      ),
    );

    String result = '';
    final path = _urlController.text.trim();
    try {
      final res = await client.get<dynamic>(
        path,
        options: Options(headers: {'RSC': '1'}),
      );

      final dataStr = res.data.toString();
      print('=== RSC PAYLOAD START ===');
      final pattern = RegExp('.{1,500}', dotAll: true);
      for (var match in pattern.allMatches(dataStr)) {
        print(match.group(0));
      }
      print('=== RSC PAYLOAD END ===');
      final preview = dataStr.length > 3000
          ? dataStr.substring(0, 3000)
          : dataStr;
      result = '✅ $path (RSC): ${res.statusCode}\n\n$preview';
    } on PortalApiException catch (e) {
      result = '❌ $path: ${e.statusCode}';
    } catch (e) {
      if (e is DioException) {
        result = '❌ Dio Error: ${e.response?.statusCode}\n${e.message}';
      } else {
        result = '❌ Error: $e';
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Kết quả lấy RSC Payload'),
          content: SingleChildScrollView(child: Text(result)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }
}

class _PendingApiBody extends StatelessWidget {
  const _PendingApiBody({required this.module});

  final PortalModule module;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NativeInfoPanel(
          icon: Icons.construction_outlined,
          title: 'Đang chờ API portal',
          message:
              '${module.title} đã được chuyển sang màn Flutter native. Dữ liệu thật sẽ được nối sau khi endpoint được xác minh và ghi vào API inventory.',
        ),
        const SizedBox(height: 12),
        _NativeInfoPanel(
          icon: Icons.security_outlined,
          title: 'Không dùng WebView',
          message:
              'Màn hình này không mở portal web. Nếu endpoint chưa rõ, app giữ trạng thái native pending thay vì quay lại WebView.',
        ),
      ],
    );
  }
}

class _NativeInfoPanel extends StatelessWidget {
  const _NativeInfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: const Text('Xem Hồ sơ cá nhân (RSC Parsed)'),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
