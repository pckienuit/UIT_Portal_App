package com.pckienuit.uitportal.oauth

import java.net.URI
import java.util.Base64
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class OAuthProviderRegistryTest {
    @Test
    fun `GitHub exposes native device provider`() {
        val provider = OAuthProviderRegistry.requireDeviceProvider("github")

        assertEquals("https://github.com/login/device/code", provider.deviceCodeUrl.toString())
        assertEquals("https://github.com/login/oauth/access_token", provider.tokenUrl.toString())
        assertEquals("read:user", provider.scope)
    }

    @Test
    fun `unknown, EOL, and blocked providers fail closed`() {
        assertFailsWith<IllegalArgumentException> {
            OAuthProviderRegistry.requireDeviceProvider("qwen")
        }
        assertFailsWith<IllegalArgumentException> {
            OAuthProviderRegistry.requireDeviceProvider("codex")
        }
        assertFailsWith<IllegalArgumentException> {
            OAuthProviderRegistry.requireDeviceProvider("unknown")
        }
    }

    @Test
    fun `device providers lock GitHub and Grok CLI native contracts`() {
        val github = OAuthProviderRegistry.requireDeviceProvider("github")
        val grok = OAuthProviderRegistry.requireDeviceProvider("grok-cli")

        assertEquals("https://github.com/login/device/code", github.deviceCodeUrl.toString())
        assertEquals("https://github.com/login/oauth/access_token", github.tokenUrl.toString())
        assertEquals("read:user", github.scope)
        assertEquals("https://auth.x.ai/oauth2/device/code", grok.deviceCodeUrl.toString())
        assertEquals("https://auth.x.ai/oauth2/token", grok.tokenUrl.toString())
        assertEquals(
            "openid profile email offline_access grok-cli:access api:access",
            grok.scope,
        )
        assertFalse(github.usesPkce)
        assertFalse(grok.usesPkce)
    }

    @Test
    fun `Google desktop OAuth providers are not exposed by Android registry`() {
        listOf("gemini-cli", "antigravity").forEach { providerId ->
            assertFailsWith<IllegalArgumentException> {
                OAuthProviderRegistry.requireAuthorizationProvider(providerId)
            }
        }
    }


    @Test
    fun `Codex uses upstream native OAuth scope without model request`() {
        val provider = OAuthProviderRegistry.requireAuthorizationProvider("codex")

        assertEquals("openid profile email offline_access", provider.scope)
    }

    @Test
    fun `Codex declares PKCE fixed callback and upstream authorization extras`() {
        val provider = OAuthProviderRegistry.requireAuthorizationProvider("codex")

        assertTrue(provider.usesPkce)
        assertEquals("localhost", provider.callbackHost)
        assertEquals(1455, provider.callbackPort)
        assertEquals("/auth/callback", provider.callbackPath)
        assertEquals(
            mapOf(
                "id_token_add_organizations" to "true",
                "codex_cli_simplified_flow" to "true",
                "originator" to "codex_cli_rs",
            ),
            provider.extraAuthorizationParams,
        )
        assertFalse(provider.resolvesGoogleProject)
    }

    @Test
    fun `Codex authorization URI sends S256 challenge and exact contract`() {
        val provider = OAuthProviderRegistry.requireAuthorizationProvider("codex")

        val uri = OAuthAuthorizationContract.authorizationUri(
            provider = provider,
            redirectUri = "http://localhost:1455/auth/callback",
            state = "state-value",
            codeVerifier = "verifier-value",
        )

        val query = uri.rawQuery.split('&').associate { item ->
            item.split('=', limit = 2).let { it[0] to java.net.URLDecoder.decode(it[1], "UTF-8") }
        }
        assertEquals("http://localhost:1455/auth/callback", query["redirect_uri"])
        assertEquals("S256", query["code_challenge_method"])
        assertEquals("true", query["id_token_add_organizations"])
        assertEquals("true", query["codex_cli_simplified_flow"])
        assertEquals("codex_cli_rs", query["originator"])
        assertTrue(query["code_challenge"].orEmpty().isNotBlank())
    }

    @Test
    fun `Codex token exchange keeps matching verifier and excludes Google project resolver`() {
        val provider = OAuthProviderRegistry.requireAuthorizationProvider("codex")

        val fields = OAuthAuthorizationContract.tokenFields(
            provider = provider,
            code = "authorization-code",
            redirectUri = "http://localhost:1455/auth/callback",
            codeVerifier = "verifier-value",
        )

        assertEquals(
            mapOf(
                "grant_type" to "authorization_code",
                "client_id" to provider.clientId,
                "code" to "authorization-code",
                "redirect_uri" to "http://localhost:1455/auth/callback",
                "code_verifier" to "verifier-value",
            ),
            fields,
        )
        assertFalse(provider.resolvesGoogleProject)
    }

    @Test
    fun `callback accepts configured Codex path only`() {
        assertTrue(OAuthAuthorizationContract.callbackPathMatches("/auth/callback", "/auth/callback"))
        assertFalse(OAuthAuthorizationContract.callbackPathMatches("/callback", "/auth/callback"))
    }

    @Test
    fun `JWT account extraction returns safe subject without retaining raw token`() {
        val jwt = "header.${Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"acct_123\",\"email\":\"user@example.com\"}".toByteArray())}.signature"

        assertEquals("acct_123", OAuthAuthorizationContract.accountIdFromIdToken(jwt))
        assertEquals(null, OAuthAuthorizationContract.accountIdFromIdToken("not-a-jwt"))
    }

    @Test
    fun `provider endpoints must use https`() {
        assertFailsWith<IllegalArgumentException> {
            DeviceOAuthProvider(
                id = "unsafe",
                clientId = "client",
                deviceCodeUrl = "http://example.com/device",
                tokenUrl = "https://example.com/token",
                scope = "read",
            )
        }
        assertFailsWith<IllegalArgumentException> {
            DeviceOAuthProvider(
                id = "unsafe-uri",
                clientId = "client",
                deviceCodeUrl = URI("http://example.com/device"),
                tokenUrl = URI("https://example.com/token"),
                scope = "read",
            )
        }
    }
}
