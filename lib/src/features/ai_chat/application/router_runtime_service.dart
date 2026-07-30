import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RouterState { stopped, starting, ready, failed }

class RouterStatus {
  const RouterStatus({
    required this.state,
    this.baseUrl,
    this.bearer,
    this.message,
  });

  final RouterState state;
  final String? baseUrl;
  final String? bearer;
  final String? message;

  factory RouterStatus.fromMap(Map<dynamic, dynamic> map) {
    final stateStr = map['state'] as String? ?? 'stopped';
    final state = RouterState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => RouterState.stopped,
    );
    return RouterStatus(
      state: state,
      baseUrl: map['baseUrl'] as String?,
      bearer: map['bearer'] as String?,
      message: map['message'] as String?,
    );
  }
}

class RouterRuntimeService extends Notifier<RouterStatus> {
  static const _channel = MethodChannel('com.pckienuit.uitportal/router');

  @override
  RouterStatus build() {
    return const RouterStatus(state: RouterState.stopped);
  }

  Future<RouterStatus> ensureStarted() async {
    if (state.state == RouterState.ready) return state;
    state = const RouterStatus(state: RouterState.starting);
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'ensureStarted',
      );
      if (res != null) {
        state = RouterStatus.fromMap(res);
      } else {
        state = const RouterStatus(
          state: RouterState.failed,
          message: 'JNI returned empty result',
        );
      }
    } catch (e) {
      state = RouterStatus(state: RouterState.failed, message: e.toString());
    }
    return state;
  }

  Future<RouterStatus> checkStatus() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('status');
      if (res != null) {
        state = RouterStatus.fromMap(res);
      }
    } catch (_) {}
    return state;
  }
}

final routerRuntimeServiceProvider =
    NotifierProvider<RouterRuntimeService, RouterStatus>(() {
      return RouterRuntimeService();
    });
