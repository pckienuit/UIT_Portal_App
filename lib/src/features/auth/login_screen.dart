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
    Future.microtask(() => ref.read(authControllerProvider).signIn());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập UIT SSO')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đăng nhập native',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'App sẽ mở UIT SSO bằng trình duyệt hệ thống/Custom Tabs theo chuẩn OAuth, không dùng WebView đăng nhập.',
              ),
              const SizedBox(height: 20),
              if (auth.isBusy) const LinearProgressIndicator(),
              if (auth.lastError != null) ...[
                Text(
                  auth.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: auth.isBusy
                    ? null
                    : () => ref.read(authControllerProvider).signIn(),
                icon: const Icon(Icons.login),
                label: const Text('Mở UIT SSO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
