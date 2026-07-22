package com.personal.uit_portal_app.oauth

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeOAuthCoordinator {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDevice" -> {
                val providerId = call.argument<String>("providerId")
                if (providerId.isNullOrBlank()) {
                    result.error("invalid_provider", "Missing provider id", null)
                    return
                }
                try {
                    OAuthProviderRegistry.requireDeviceProvider(providerId)
                    result.error(
                        "flow_not_started",
                        "Native device transport is not enabled yet",
                        null,
                    )
                } catch (error: IllegalArgumentException) {
                    result.error("unsupported_provider", error.message, null)
                }
            }

            "cancel" -> {
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
