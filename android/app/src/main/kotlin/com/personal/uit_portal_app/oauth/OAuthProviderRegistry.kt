package com.personal.uit_portal_app.oauth

object OAuthProviderRegistry {
    private val authorizationProviders = mapOf(
        "gemini-cli" to AuthorizationOAuthProvider(
            id = "gemini-cli",
            clientId = "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com",
            clientSecret = "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",
            authorizeUrl = java.net.URI("https://accounts.google.com/o/oauth2/v2/auth"),
            tokenUrl = java.net.URI("https://oauth2.googleapis.com/token"),
            scope = listOf(
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile",
            ).joinToString(" "),
        ),
    )

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

    fun requireAuthorizationProvider(providerId: String): AuthorizationOAuthProvider =
        requireNotNull(authorizationProviders[providerId]) {
            "Provider does not expose a native Android authorization flow"
        }
}
