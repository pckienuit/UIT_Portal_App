package com.pckienuit.uitportal.router

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class RouterRuntimeConfigTest {
    @Test
    fun acceptsIpv4Loopback() {
        val config = RouterRuntimeConfig(host = "127.0.0.1", port = 20128)

        assertEquals("127.0.0.1", config.host)
        assertEquals(20128, config.port)
    }

    @Test
    fun acceptsIpv6Loopback() {
        assertEquals("::1", RouterRuntimeConfig(host = "::1", port = 20128).host)
    }

    @Test
    fun rejectsExternalBindAddress() {
        assertFailsWith<IllegalArgumentException> {
            RouterRuntimeConfig(host = "0.0.0.0", port = 20128)
        }
    }

    @Test
    fun rejectsOutOfRangePort() {
        assertFailsWith<IllegalArgumentException> {
            RouterRuntimeConfig(host = "127.0.0.1", port = 65536)
        }
    }
}
