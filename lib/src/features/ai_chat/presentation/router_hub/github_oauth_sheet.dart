import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/foundations/portal_spacing.dart';
import '../../application/ai_provider_controller.dart';
import '../../data/github_oauth_service.dart';
import '../../data/native_oauth_client.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/router_models.dart';

class GithubOAuthSheet extends ConsumerStatefulWidget {
  const GithubOAuthSheet({super.key, required this.definition});

  final RouterProviderDefinition definition;

  @override
  ConsumerState<GithubOAuthSheet> createState() => _GithubOAuthSheetState();
}

class _GithubOAuthSheetState extends ConsumerState<GithubOAuthSheet>
    with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.personal.uitportal/oauth');
  static const _nativeOAuth = NativeOAuthClient();

  NativeDeviceFlow? _flow;
  NativeAuthorizationFlow? _authorizationFlow;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _authorizationFlow != null &&
        !_busy) {
      _complete();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final flow = _flow;
    if (flow != null) _nativeOAuth.cancel(flow.flowId).catchError((_) {});
    final authorizationFlow = _authorizationFlow;
    if (authorizationFlow != null) {
      _nativeOAuth.cancel(authorizationFlow.flowId).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final clientId = widget.definition.id == 'github'
          ? ref.read(githubOAuthServiceProvider).clientId
          : null;
      if (widget.definition.androidAuth == RouterAndroidAuth.loopback ||
          widget.definition.androidAuth == RouterAndroidAuth.pkce) {
        final flow = await _nativeOAuth.startAuthorization(
          widget.definition.id,
        );
        if (!mounted) {
          await _nativeOAuth.cancel(flow.flowId);
          return;
        }
        setState(() => _authorizationFlow = flow);
        await _platform.invokeMethod<void>('openUrl', {
          'url': flow.authorizationUri.toString(),
        });
        return;
      }
      final flow = await _nativeOAuth.startDevice(
        widget.definition.id,
        clientId: clientId,
      );
      if (!mounted) {
        await _nativeOAuth.cancel(flow.flowId);
        return;
      }
      setState(() => _flow = flow);
      await Clipboard.setData(ClipboardData(text: flow.userCode));
      await _platform.invokeMethod<void>('openUrl', {
        'url': flow.verificationUri.toString(),
      });
    } catch (error) {
      final flow = _flow;
      if (flow != null) {
        await _nativeOAuth.cancel(flow.flowId);
        _flow = null;
      }
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final flow = _flow;
    final authorizationFlow = _authorizationFlow;
    if (flow == null && authorizationFlow == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final oauth = authorizationFlow != null
          ? await _nativeOAuth.completeAuthorization(authorizationFlow.flowId)
          : await _nativeOAuth.completeDevice(flow!.flowId);
      var runtimeToken = oauth.accessToken;
      var runtimeExpiry = oauth.expiresAt;
      var credentialKind = 'refreshToken';
      String? sourceToken = oauth.refreshToken;
      if (widget.definition.id == 'github') {
        final copilot = await ref
            .read(githubOAuthServiceProvider)
            .exchangeCopilotToken(oauth.accessToken);
        runtimeToken = copilot.accessToken;
        runtimeExpiry = copilot.expiresAt;
        credentialKind = 'githubSourceToken';
        sourceToken = oauth.accessToken;
      }
      if (credentialKind == 'refreshToken' && sourceToken == null) {
        throw const NativeOAuthException(
          'Provider không cấp refresh token. Cần đăng nhập lại khi token hết hạn.',
        );
      }
      final modelId = widget.definition.id == 'gemini-cli'
          ? 'gemini-2.5-flash'
          : widget.definition.models.firstOrNull?.id ?? '';
      final baseUrl = widget.definition.defaultBaseUrl ?? '';
      if (modelId.isEmpty || baseUrl.isEmpty) {
        throw const NativeOAuthException(
          'Provider thiếu model hoặc Base URL mobile.',
        );
      }
      final config = AiProviderConfig(
        id: 'provider-${widget.definition.id}',
        name: widget.definition.name,
        kind: AiBackendKind.openAiCompatible,
        baseUrl: baseUrl,
        modelId: modelId,
        presetId: widget.definition.id,
        authMode: 'oauth',
        credentialKind: credentialKind,
        tokenExpiresAt: runtimeExpiry,
        projectId: oauth.projectId,
      );
      await ref
          .read(aiProviderControllerProvider.notifier)
          .saveProvider(
            config,
            oauthAccessToken: runtimeToken,
            oauthSourceToken: sourceToken,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      final failedFlowId = authorizationFlow?.flowId ?? flow?.flowId;
      if (failedFlowId != null) await _nativeOAuth.cancel(failedFlowId);
      if (mounted) {
        setState(() {
          _flow = null;
          _authorizationFlow = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.definition.name;
    final githubConfigured =
        widget.definition.id != 'github' ||
        ref.watch(githubOAuthServiceProvider).isConfigured;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đăng nhập $name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PortalSpacing.md),
            if (!githubConfigured)
              const Text(
                'Cần build app với --dart-define=GITHUB_OAUTH_CLIENT_ID=<client-id>.',
              ),
            if (_flow != null) ...[
              Text('Mã đã được sao chép. Nhập mã này trên $name:'),
              const SizedBox(height: PortalSpacing.sm),
              SelectableText(
                _flow!.userCode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
            if (_authorizationFlow != null)
              const Text(
                'Hoàn tất đăng nhập trên trình duyệt, sau đó quay lại đây.',
              ),
            if (_error != null) ...[
              const SizedBox(height: PortalSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: PortalSpacing.lg),
            FilledButton(
              onPressed: _busy || !githubConfigured
                  ? null
                  : _flow == null && _authorizationFlow == null
                  ? _start
                  : _complete,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _flow == null && _authorizationFlow == null
                          ? 'Mở $name'
                          : 'Tôi đã xác nhận',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
