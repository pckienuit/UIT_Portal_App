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
            clientId = "108493108920-lksbd0b3v54mbfp4b21650r39v03d274.apps.googleusercontent.com",
            clientSecret = "GOCSPX-d16c5n2-uX2W7g5P7L4i_63Y",
            authorizeUrl = java.net.URI("https://accounts.google.com/o/oauth2/v2/auth"),
            tokenUrl = java.net.URI("https://oauth2.googleapis.com/token"),
            scope = listOf(
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile",
            ).joinToString(" "),
        ),
        "codex" to AuthorizationOAuthProvider(
            id = "codex",
            clientId = "app-4f89d5a7",
            clientSecret = null,
            authorizeUrl = java.net.URI("https://auth.openai.com/authorize"),
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
}
