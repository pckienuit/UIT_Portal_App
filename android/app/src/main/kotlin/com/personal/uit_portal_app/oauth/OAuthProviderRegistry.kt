package com.personal.uit_portal_app.oauth

object OAuthProviderRegistry {
    private val deviceProviders = mapOf(
        "github" to DeviceOAuthProvider(
            id = "github",
            clientId = "Iv1.b507a08c87ecfe98",
            deviceCodeUrl = "https://github.com/login/device/code",
            tokenUrl = "https://github.com/login/oauth/access_token",
            scope = "read:user",
        ),
    )

    fun requireDeviceProvider(providerId: String): DeviceOAuthProvider =
        requireNotNull(deviceProviders[providerId]) {
            "Provider does not expose a native Android device flow"
        }
}
