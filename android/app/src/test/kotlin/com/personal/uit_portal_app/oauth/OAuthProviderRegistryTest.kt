package com.personal.uit_portal_app.oauth

import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

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
    fun `Gemini CLI exposes loopback authorization code flow`() {
        val provider = OAuthProviderRegistry.requireAuthorizationProvider("gemini-cli")

        assertEquals("https://accounts.google.com/o/oauth2/v2/auth", provider.authorizeUrl.toString())
        assertEquals("https://oauth2.googleapis.com/token", provider.tokenUrl.toString())
        assertEquals(true, provider.scope.contains("cloud-platform"))
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
