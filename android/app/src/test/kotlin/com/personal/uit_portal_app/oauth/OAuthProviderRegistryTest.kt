package com.personal.uit_portal_app.oauth

import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class OAuthProviderRegistryTest {
    @Test
    fun `GitHub is the only ready native device provider`() {
        val provider = OAuthProviderRegistry.requireDeviceProvider("github")

        assertEquals("https://github.com/login/device/code", provider.deviceCodeUrl.toString())
        assertEquals("https://github.com/login/oauth/access_token", provider.tokenUrl.toString())
        assertEquals("read:user", provider.scope)
    }

    @Test
    fun `unknown and blocked providers fail closed`() {
        assertFailsWith<IllegalArgumentException> {
            OAuthProviderRegistry.requireDeviceProvider("codex")
        }
        assertFailsWith<IllegalArgumentException> {
            OAuthProviderRegistry.requireDeviceProvider("unknown")
        }
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
