import 'package:flutter/services.dart';

class NativeDeviceFlow {
  const NativeDeviceFlow({
    required this.flowId,
    required this.userCode,
    required this.verificationUri,
    required this.expiresAt,
    required this.interval,
  });

  final String flowId;
  final String userCode;
  final Uri verificationUri;
  final DateTime expiresAt;
  final Duration interval;

  factory NativeDeviceFlow.fromMap(Map<Object?, Object?> map) {
    final flowId = map['flowId'];
    final userCode = map['userCode'];
    final verificationUri = Uri.tryParse(
      map['verificationUri'] as String? ?? '',
    );
    final expiresAt = DateTime.tryParse(map['expiresAt'] as String? ?? '');
    final intervalSeconds = map['intervalSeconds'];
    if (flowId is! String ||
        flowId.isEmpty ||
        userCode is! String ||
        userCode.isEmpty ||
        verificationUri == null ||
        verificationUri.scheme != 'https' ||
        verificationUri.host.isEmpty ||
        expiresAt == null ||
        intervalSeconds is! int ||
        intervalSeconds < 1) {
      throw const NativeOAuthException('Phản hồi OAuth native không hợp lệ.');
    }
    return NativeDeviceFlow(
      flowId: flowId,
      userCode: userCode,
      verificationUri: verificationUri,
      expiresAt: expiresAt,
      interval: Duration(seconds: intervalSeconds),
    );
  }
}

class NativeOAuthException implements Exception {
  const NativeOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NativeOAuthClient {
  const NativeOAuthClient();

  static const _channel = MethodChannel(
    'com.personal.uitportal/provider_oauth',
  );

  Future<NativeDeviceFlow> startDevice(String providerId) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'startDevice',
        {'providerId': providerId},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả dữ liệu.');
      }
      return NativeDeviceFlow.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }

  Future<void> cancel(String flowId) =>
      _channel.invokeMethod<void>('cancel', {'flowId': flowId});
}
