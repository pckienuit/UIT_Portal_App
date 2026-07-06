import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../portal_constants.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _progress = progress / 100);
          },
          onPageFinished: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null && AuthController.isPortalAuthenticatedUrl(uri)) {
              ref.read(authControllerProvider).markSignedIn();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(PortalConstants.loginUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập UIT SSO')),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress < 1)
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          ],
        ),
      ),
    );
  }
}
