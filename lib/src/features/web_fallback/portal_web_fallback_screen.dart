import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../portal_module_registry.dart';

class PortalWebFallbackScreen extends StatefulWidget {
  const PortalWebFallbackScreen({super.key, required this.module});

  final PortalModule module;

  @override
  State<PortalWebFallbackScreen> createState() =>
      _PortalWebFallbackScreenState();
}

class _PortalWebFallbackScreenState extends State<PortalWebFallbackScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

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
          onPageFinished: (_) => _refreshNavigationState(),
        ),
      )
      ..loadRequest(widget.module.webUri);
  }

  Future<void> _refreshNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
        actions: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: _canGoBack ? _controller.goBack : null,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Đi tới',
            onPressed: _canGoForward ? _controller.goForward : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
