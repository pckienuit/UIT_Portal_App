import 'package:flutter/material.dart';

@immutable
class PortalSemanticColors extends ThemeExtension<PortalSemanticColors> {
  const PortalSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.error,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color error;

  static const light = PortalSemanticColors(
    success: Color(0xFF176B3A),
    onSuccess: Colors.white,
    successContainer: Color(0xFFB9F5CD),
    onSuccessContainer: Color(0xFF00210D),
    warning: Color(0xFF8A4F00),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFFDDB6),
    onWarningContainer: Color(0xFF2C1600),
    info: Color(0xFF00639A),
    onInfo: Colors.white,
    infoContainer: Color(0xFFCDE5FF),
    onInfoContainer: Color(0xFF001D32),
    error: Color(0xFFBA1A1A),
  );

  static const dark = PortalSemanticColors(
    success: Color(0xFF9BD8B1),
    onSuccess: Color(0xFF00391B),
    successContainer: Color(0xFF005229),
    onSuccessContainer: Color(0xFFB9F5CD),
    warning: Color(0xFFFFB95F),
    onWarning: Color(0xFF492900),
    warningContainer: Color(0xFF693C00),
    onWarningContainer: Color(0xFFFFDDB6),
    info: Color(0xFF94CCFF),
    onInfo: Color(0xFF003352),
    infoContainer: Color(0xFF004A75),
    onInfoContainer: Color(0xFFCDE5FF),
    error: Color(0xFFFFB4AB),
  );

  @override
  PortalSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? error,
  }) {
    return PortalSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      error: error ?? this.error,
    );
  }

  @override
  PortalSemanticColors lerp(covariant PortalSemanticColors? other, double t) {
    if (other == null) return this;
    return PortalSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
