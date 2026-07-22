import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/foundations/portal_spacing.dart';
import '../../application/ai_provider_controller.dart';
import '../../data/ai_provider_repository.dart';
import '../../data/github_oauth_service.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/router_models.dart';

class GithubOAuthSheet extends ConsumerStatefulWidget {
  const GithubOAuthSheet({super.key, required this.definition});

  final RouterProviderDefinition definition;

  @override
  ConsumerState<GithubOAuthSheet> createState() => _GithubOAuthSheetState();
}

class _GithubOAuthSheetState extends ConsumerState<GithubOAuthSheet> {
  static const _platform = MethodChannel('com.personal.uitportal/oauth');

  GithubDeviceFlow? _flow;
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flow = await ref.read(githubOAuthServiceProvider).start();
      await Clipboard.setData(ClipboardData(text: flow.userCode));
      await _platform.invokeMethod<void>('openUrl', {
        'url': flow.verificationUri,
      });
      if (mounted) setState(() => _flow = flow);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final flow = _flow;
    if (flow == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(githubOAuthServiceProvider);
      final oauth = await service.poll(flow);
      if (oauth == null) {
        setState(
          () => _error =
              'GitHub chưa xác nhận. Hoàn tất trên trình duyệt rồi thử lại.',
        );
        return;
      }
      final copilot = await service.exchangeCopilotToken(oauth.accessToken);
      final modelId = widget.definition.models.firstOrNull?.id ?? 'gpt-5.4';
      final config = AiProviderConfig(
        id: 'provider-github-${DateTime.now().millisecondsSinceEpoch}',
        name: widget.definition.name,
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.githubcopilot.com',
        modelId: modelId,
        presetId: 'github',
        authMode: 'oauth',
      );
      await ref
          .read(aiProviderControllerProvider.notifier)
          .saveProvider(config, apiKey: copilot.accessToken);
      await ref
          .read(aiProviderRepositoryProvider)
          .saveProvider(
            config,
            oauthAccessToken: copilot.accessToken,
            oauthRefreshToken: oauth.refreshToken ?? oauth.accessToken,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(githubOAuthServiceProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đăng nhập GitHub Copilot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PortalSpacing.md),
            if (!service.isConfigured)
              const Text(
                'Cần build app với --dart-define=GITHUB_OAUTH_CLIENT_ID=<client-id>.',
              ),
            if (_flow != null) ...[
              const Text('Mã đã được sao chép. Nhập mã này trên GitHub:'),
              const SizedBox(height: PortalSpacing.sm),
              SelectableText(
                _flow!.userCode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: PortalSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: PortalSpacing.lg),
            FilledButton(
              onPressed: _busy || !service.isConfigured
                  ? null
                  : _flow == null
                  ? _start
                  : _complete,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_flow == null ? 'Mở GitHub' : 'Tôi đã xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}
