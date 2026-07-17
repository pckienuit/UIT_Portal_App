import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_surface.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthController>(authControllerProvider, (previous, next) {
      if (next.isSignedIn) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    });

    final auth = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalScaffold(
      maxContentWidth: 560,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: PortalSpacing.lg,
              vertical: PortalSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > PortalSpacing.xxl
                    ? constraints.maxHeight - PortalSpacing.xxl
                    : 0,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 88),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: PortalSpacing.lg),
                    PortalSurface(
                      padding: const EdgeInsets.all(PortalSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'UIT Portal',
                              style: textTheme.headlineMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: PortalSpacing.xs),
                            Text(
                              'Đăng nhập nội bộ hệ thống',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: PortalSpacing.lg),
                            TextFormField(
                              key: const Key('usernameField'),
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Mã sinh viên / Username',
                              ),
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập mã sinh viên hoặc username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: PortalSpacing.md),
                            TextFormField(
                              key: const Key('passwordField'),
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                suffixIcon: Semantics(
                                  button: true,
                                  label: _obscurePassword
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  onTap: _togglePassword,
                                  excludeSemantics: true,
                                  child: IconButton(
                                    key: const Key('passwordVisibilityButton'),
                                    tooltip: _obscurePassword
                                        ? 'Hiện mật khẩu'
                                        : 'Ẩn mật khẩu',
                                    onPressed: _togglePassword,
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                return null;
                              },
                            ),
                            if (auth.lastError != null) ...[
                              const SizedBox(height: PortalSpacing.md),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    PortalSpacing.sm,
                                  ),
                                  child: Text(
                                    auth.lastError!,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: PortalSpacing.lg),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: auth.isBusy ? null : _submit,
                                child: auth.isBusy
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Đăng nhập'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _togglePassword() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    ref
        .read(authControllerProvider)
        .signInWithCredentials(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }
}
