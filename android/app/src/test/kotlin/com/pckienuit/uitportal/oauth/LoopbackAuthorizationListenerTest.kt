package com.pckienuit.uitportal.oauth

import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.ServerSocket
import java.net.URL
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LoopbackAuthorizationListenerTest {
    @Test
    fun `listener accepts configured Codex callback path only`() {
        val server = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
        val callback = CompletableFuture<Map<String, String>>()
        val listener = LoopbackAuthorizationListener(
            server = server,
            expectedState = "codex-state",
            expectedCallbackPath = "/auth/callback",
            callback = callback,
            timeoutMillis = 2_000,
            log = {},
        )
        val thread = Thread(listener::run).apply { start() }

        assertEquals(400, get(server.localPort, "/callback?code=wrong&state=codex-state").status)
        assertFalse(callback.isDone)
        assertEquals(302, get(server.localPort, "/auth/callback?code=accepted&state=codex-state").status)
        assertEquals("accepted", callback.get(1, TimeUnit.SECONDS)["code"])
        thread.join(1_000)
        assertFalse(thread.isAlive)
    }

    @Test
    fun `listener ignores invalid request then completes valid callback`() {
        val server = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
        val callback = CompletableFuture<Map<String, String>>()
        val listener = LoopbackAuthorizationListener(
            server = server,
            expectedState = "expected-state",
            callback = callback,
            timeoutMillis = 2_000,
            log = {},
        )

        val thread = Thread(listener::run).apply { start() }

        assertEquals(400, get(server.localPort, "/wrong?code=ignored&state=expected-state").status)
        assertFalse(callback.isDone)
        assertEquals(400, get(server.localPort, "/callback?code=ignored&state=wrong-state").status)
        assertFalse(callback.isDone)
        val accepted = get(server.localPort, "/callback?code=accepted&state=expected-state")
        assertEquals(302, accepted.status)
        assertEquals("uitportal-provider://oauth-complete", accepted.location)

        val params = callback.get(1, TimeUnit.SECONDS)
        assertEquals("accepted", params["code"])
        assertEquals("expected-state", params["state"])
        thread.join(1_000)
        assertFalse(thread.isAlive)
        assertTrue(server.isClosed)
    }

    private fun get(port: Int, target: String): Response {
        val connection = URL("http://127.0.0.1:$port$target").openConnection() as HttpURLConnection
        connection.connectTimeout = 1_000
        connection.readTimeout = 1_000
        connection.instanceFollowRedirects = false
        return try {
            val status = connection.responseCode
            val body = (if (status < 400) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            Response(status, body, connection.getHeaderField("Location"))
        } finally {
            connection.disconnect()
        }
    }

    private data class Response(
        val status: Int,
        val body: String,
        val location: String?,
    )
}
