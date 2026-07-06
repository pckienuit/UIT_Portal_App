import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authControllerProvider);
      if (auth.config.canStartNativeAuth) {
        auth.signIn();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final configProblem = auth.config.configurationProblem;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập UIT SSO')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Đăng nhập native',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'App sẽ mở UIT SSO bằng trình duyệt hệ thống/Custom Tabs theo chuẩn OAuth, không dùng WebView đăng nhập.',
            ),
            const SizedBox(height: 20),
            if (configProblem != null)
              _ConfigWarning(
                message: configProblem,
                redirectUrl: auth.config.redirectUrl,
              ),
            if (auth.isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (auth.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: auth.isBusy || configProblem != null
                  ? null
                  : () => ref.read(authControllerProvider).signIn(),
              icon: const Icon(Icons.login),
              label: const Text('Mở UIT SSO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigWarning extends StatelessWidget {
  const _ConfigWarning({required this.message, required this.redirectUrl});

  final String message;
  final String redirectUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cần cấu hình OAuth mobile client',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Text(
              'Redirect URI cần whitelist: $redirectUrl',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
