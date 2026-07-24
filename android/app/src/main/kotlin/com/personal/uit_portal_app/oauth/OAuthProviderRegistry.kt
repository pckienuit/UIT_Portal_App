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
        "antigravity" to AuthorizationOAuthProvider(
            id = "antigravity",
            clientId = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com",
            clientSecret = "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",
            authorizeUrl = java.net.URI("https://accounts.google.com/o/oauth2/v2/auth"),
            tokenUrl = java.net.URI("https://oauth2.googleapis.com/token"),
            scope = listOf(
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile",
                "https://www.googleapis.com/auth/cclog",
                "https://www.googleapis.com/auth/experimentsandconfigs",
            ).joinToString(" "),
        ),
        "codex" to AuthorizationOAuthProvider(
            id = "codex",
            clientId = "app_EMoamEEZ73f0CkXaXp7hrann",
            clientSecret = null,
            authorizeUrl = java.net.URI("https://auth.openai.com/oauth/authorize"),
            tokenUrl = java.net.URI("https://auth.openai.com/oauth/token"),
            scope = "openid profile email offline_access model.request",
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
        "grok-cli" to DeviceOAuthProvider(
            id = "grok-cli",
            clientId = "b1a00492-073a-47ea-816f-4c329264a828",
            deviceCodeUrl = "https://auth.x.ai/oauth2/device/code",
            tokenUrl = "https://auth.x.ai/oauth2/token",
            scope = "openid profile email offline_access grok-cli:access api:access",
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

    fun authorizationProviderOrNull(providerId: String): AuthorizationOAuthProvider? =
        authorizationProviders[providerId]
}
