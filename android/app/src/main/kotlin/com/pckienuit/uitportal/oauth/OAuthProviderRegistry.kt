package com.pckienuit.uitportal.oauth

object OAuthProviderRegistry {
    private val authorizationProviders = mapOf(
        "codex" to AuthorizationOAuthProvider(
            id = "codex",
            clientId = "app_EMoamEEZ73f0CkXaXp7hrann",
            authorizeUrl = java.net.URI("https://auth.openai.com/oauth/authorize"),
            tokenUrl = java.net.URI("https://auth.openai.com/oauth/token"),
            scope = "openid profile email offline_access",
            usesPkce = true,
            callbackHost = "localhost",
            callbackPort = 1455,
            callbackPath = "/auth/callback",
            extraAuthorizationParams = mapOf(
                "id_token_add_organizations" to "true",
                "codex_cli_simplified_flow" to "true",
                "originator" to "codex_cli_rs",
            ),
            resolvesGoogleProject = false,
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
