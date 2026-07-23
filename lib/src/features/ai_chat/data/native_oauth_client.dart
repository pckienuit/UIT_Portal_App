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

class NativeAuthorizationFlow {
  const NativeAuthorizationFlow({
    required this.flowId,
    required this.authorizationUri,
  });

  final String flowId;
  final Uri authorizationUri;

  factory NativeAuthorizationFlow.fromMap(Map<Object?, Object?> map) {
    final flowId = map['flowId'];
    final uri = Uri.tryParse(map['authorizationUri'] as String? ?? '');
    if (flowId is! String ||
        flowId.isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const NativeOAuthException('Phản hồi OAuth native không hợp lệ.');
    }
    return NativeAuthorizationFlow(flowId: flowId, authorizationUri: uri);
  }
}

class NativeOAuthCredential {
  const NativeOAuthCredential({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.scope,
    this.projectId,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? scope;
  final String? projectId;

  factory NativeOAuthCredential.fromMap(Map<Object?, Object?> map) {
    final accessToken = map['accessToken'];
    final expiresAtValue = map['expiresAt'] as String?;
    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue);
    if (accessToken is! String ||
        accessToken.isEmpty ||
        (expiresAtValue != null && expiresAt == null)) {
      throw const NativeOAuthException('Credential OAuth native không hợp lệ.');
    }
    return NativeOAuthCredential(
      accessToken: accessToken,
      refreshToken: map['refreshToken'] as String?,
      expiresAt: expiresAt,
      scope: map['scope'] as String?,
      projectId: map['projectId'] as String?,
    );
  }
}

class NativeOAuthException implements Exception {
  const NativeOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class NativeOAuthApi {
  Future<NativeDeviceFlow> startDevice(String providerId, {String? clientId});
  Future<NativeOAuthCredential> completeDevice(String flowId);
  Future<void> cancel(String flowId);
  Future<NativeOAuthCredential> refresh(String providerId, String refreshToken);
  Future<NativeAuthorizationFlow> startAuthorization(String providerId);
  Future<NativeOAuthCredential> completeAuthorization(String flowId);
}

class NativeOAuthClient implements NativeOAuthApi {
  const NativeOAuthClient();

  static const _channel = MethodChannel(
    'com.personal.uitportal/provider_oauth',
  );

  @override
  Future<NativeDeviceFlow> startDevice(
    String providerId, {
    String? clientId,
  }) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'startDevice',
        {'providerId': providerId, 'clientId': clientId},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả dữ liệu.');
      }
      return NativeDeviceFlow.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }

  @override
  Future<NativeOAuthCredential> completeDevice(String flowId) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'completeDevice',
        {'flowId': flowId},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả credential.');
      }
      return NativeOAuthCredential.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }

  @override
  Future<void> cancel(String flowId) =>
      _channel.invokeMethod<void>('cancel', {'flowId': flowId});

  @override
  Future<NativeOAuthCredential> refresh(
    String providerId,
    String refreshToken,
  ) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'refresh',
        {'providerId': providerId, 'refreshToken': refreshToken},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả credential.');
      }
      return NativeOAuthCredential.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }

  @override
  Future<NativeAuthorizationFlow> startAuthorization(String providerId) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'startAuthorization',
        {'providerId': providerId},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả dữ liệu.');
      }
      return NativeAuthorizationFlow.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }

  @override
  Future<NativeOAuthCredential> completeAuthorization(String flowId) async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'completeAuthorization',
        {'flowId': flowId},
      );
      if (response == null) {
        throw const NativeOAuthException('OAuth native không trả credential.');
      }
      return NativeOAuthCredential.fromMap(response);
    } on PlatformException catch (error) {
      throw NativeOAuthException(error.message ?? 'OAuth native thất bại.');
    }
  }
}
