package com.personal.uit_portal_app.oauth

import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.SocketTimeoutException
import java.net.URI
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Instant
import java.util.Base64
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class OAuthTransportException(val code: String, message: String) : Exception(message)

internal class LoopbackAuthorizationListener(
    private val server: ServerSocket,
    private val expectedState: String,
    private val callback: CompletableFuture<Map<String, String>>,
    private val cancelled: AtomicBoolean = AtomicBoolean(false),
    private val timeoutMillis: Long = 300_000L,
    private val log: (String) -> Unit = { android.util.Log.i("NativeOAuth", it) },
) {
    fun run() {
        try {
            val deadline = System.currentTimeMillis() + timeoutMillis
            while (!cancelled.get() && System.currentTimeMillis() < deadline) {
                server.soTimeout = (deadline - System.currentTimeMillis())
                    .coerceAtLeast(1L)
                    .coerceAtMost(Int.MAX_VALUE.toLong())
                    .toInt()
                server.accept().use { socket ->
                    val line = socket.getInputStream()
                        .bufferedReader(StandardCharsets.US_ASCII)
                        .readLine()
                        .orEmpty()
                    val target = line.split(' ').getOrNull(1).orEmpty()
                    val uri = runCatching { URI("http://127.0.0.1$target") }.getOrNull()
                    val params = uri?.rawQuery.orEmpty().split('&').mapNotNull { item ->
                        val pair = item.split('=', limit = 2)
                        pair.firstOrNull()?.takeIf { it.isNotBlank() }?.let {
                            URLDecoder.decode(it, StandardCharsets.UTF_8) to
                                URLDecoder.decode(pair.getOrElse(1) { "" }, StandardCharsets.UTF_8)
                        }
                    }.toMap()
                    val state = params["state"]
                    val stateMatches = state != null && MessageDigest.isEqual(
                        expectedState.toByteArray(StandardCharsets.UTF_8),
                        state.toByteArray(StandardCharsets.UTF_8),
                    )
                    val hasResult = params["code"]?.isNotBlank() == true ||
                        params["error"]?.isNotBlank() == true
                    val valid = uri?.path == "/callback" && stateMatches && hasResult
                    log(
                        "Callback path=${uri?.path} valid=$valid state_valid=$stateMatches " +
                            "code_present=${params["code"]?.isNotBlank() == true} " +
                            "error_present=${params["error"]?.isNotBlank() == true}",
                    )
                    respond(socket, valid)
                    if (valid) {
                        callback.complete(params)
                        return
                    }
                }
            }
            if (!callback.isDone) {
                callback.completeExceptionally(
                    OAuthTransportException("expired_flow", "OAuth Google đã hết hạn"),
                )
            }
        } catch (_: SocketTimeoutException) {
            callback.completeExceptionally(
                OAuthTransportException("expired_flow", "OAuth Google đã hết hạn"),
            )
        } catch (error: Exception) {
            if (!cancelled.get()) callback.completeExceptionally(error)
        } finally {
            runCatching { server.close() }
        }
    }

    private fun respond(socket: java.net.Socket, valid: Boolean) {
        val message = if (valid) {
            "Đang quay lại ứng dụng..."
        } else {
            "OAuth callback không hợp lệ."
        }
        val html = "<html><body><h2>$message</h2></body></html>"
        val body = html.toByteArray(StandardCharsets.UTF_8)
        val crlf = "${13.toChar()}${10.toChar()}"
        val headers = mutableListOf(
            "HTTP/1.1 ${if (valid) "302 Found" else "400 Bad Request"}",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: ${body.size}",
            "Connection: close",
        )
        if (valid) {
            headers += "Location: uitportal-provider://oauth-complete"
        }
        val response = headers.joinToString(crlf) + crlf + crlf
        socket.getOutputStream().use {
            it.write(response.toByteArray(StandardCharsets.US_ASCII))
            it.write(body)
            it.flush()
        }
    }
}

data class ActiveAuthorizationFlow(
    val provider: AuthorizationOAuthProvider,
    val state: String,
    val redirectUri: String,
    val server: ServerSocket,
    val cancelled: AtomicBoolean = AtomicBoolean(false),
    val callback: CompletableFuture<Map<String, String>> = CompletableFuture(),
)

data class ActiveFlow(
    val provider: DeviceOAuthProvider,
    val deviceCode: String,
    val expiresAt: Instant,
    var intervalSeconds: Int,
    val codeVerifier: String?,
    val cancelled: AtomicBoolean = AtomicBoolean(false),
    val completing: AtomicBoolean = AtomicBoolean(false),
)

class NativeOAuthCoordinator {
    companion object {
        private val executor = Executors.newCachedThreadPool()
        private val flows = ConcurrentHashMap<String, ActiveFlow>()
        private val authorizationFlows = ConcurrentHashMap<String, ActiveAuthorizationFlow>()
        var activeAuthFlowId: String? = null
    }

    fun close() {
        // Static flows intentionally outlive Activity/FlutterEngine recreation.
        // They expire or are cancelled explicitly while the Android process remains alive.
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDevice" -> startDevice(call, result)
            "completeDevice" -> completeDevice(call, result)
            "startAuthorization" -> startAuthorization(call, result)
            "completeAuthorization" -> completeAuthorization(call, result)
            "refresh" -> refresh(call, result)
            "cancel" -> {
                val flowIdArg = call.argument<String>("flowId")
                val flowId = if (flowIdArg != null && (flows.containsKey(flowIdArg) || authorizationFlows.containsKey(flowIdArg))) flowIdArg else activeAuthFlowId
                android.util.Log.i("NativeOAuth", "cancel flowIdArg=$flowIdArg activeAuthFlowId=$activeAuthFlowId final=$flowId")
                if (flowId != null) {
                    flows.remove(flowId)?.cancelled?.set(true)
                    authorizationFlows.remove(flowId)?.let {
                        it.cancelled.set(true)
                        it.callback.completeExceptionally(OAuthTransportException("cancelled", "OAuth flow đã bị hủy"))
                        runCatching { it.server.close() }
                    }
                    if (flowId == activeAuthFlowId) {
                        activeAuthFlowId = null
                    }
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startDevice(call: MethodCall, result: MethodChannel.Result) {
        val providerId = call.argument<String>("providerId") ?: return result.error("invalid_provider", "Missing provider id", null)
        val provider = try {
            val registered = OAuthProviderRegistry.requireDeviceProvider(providerId)
            val overrideClientId = call.argument<String>("clientId")
            if (overrideClientId.isNullOrBlank()) registered else registered.copy(clientId = overrideClientId)
        } catch (error: IllegalArgumentException) {
            return result.error("unsupported_provider", error.message, null)
        }

        executor.execute {
            try {
                val codeVerifier = provider.takeIf { it.usesPkce }?.let { generateCodeVerifier() }
                val fields = mutableMapOf("client_id" to provider.clientId, "scope" to provider.scope)
                if (codeVerifier != null) {
                    fields["code_challenge"] = codeChallenge(codeVerifier)
                    fields["code_challenge_method"] = "S256"
                }
                val payload = postForm(provider.deviceCodeUrl, fields)
                val expiresIn = payload.requirePositiveInt("expires_in")
                val interval = payload.optInt("interval", 5).coerceAtLeast(1)
                val verificationUri = requireHttpsUri(payload.requireString("verification_uri"))
                val flowId = UUID.randomUUID().toString()
                val flow = ActiveFlow(
                    provider = provider,
                    deviceCode = payload.requireString("device_code"),
                    expiresAt = Instant.now().plusSeconds(expiresIn.toLong()),
                    intervalSeconds = interval,
                    codeVerifier = codeVerifier,
                )
                flows[flowId] = flow
                executor.execute {
                    try {
                        Thread.sleep((expiresIn + 1L) * 1000L)
                        flows.remove(flowId)?.cancelled?.set(true)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
                result.success(
                    NativeDeviceFlow(
                        flowId = flowId,
                        providerId = provider.id,
                        userCode = payload.requireString("user_code"),
                        verificationUri = verificationUri,
                        expiresAt = flow.expiresAt.toString(),
                        intervalSeconds = interval,
                    ).toMap(),
                )
            } catch (error: OAuthTransportException) {
                result.error(error.code, error.message, null)
            } catch (_: Exception) {
                result.error("oauth_transport", "Không thể bắt đầu OAuth native", null)
            }
        }
    }

    private fun completeDevice(call: MethodCall, result: MethodChannel.Result) {
        val flowId = call.argument<String>("flowId") ?: return result.error("invalid_flow", "Flow ID is required", null)
        val flow = flows[flowId] ?: return result.error("invalid_flow", "OAuth flow không tồn tại hoặc đã hết hạn", null)
        if (!flow.completing.compareAndSet(false, true)) {
            return result.error("flow_in_progress", "OAuth flow đang được hoàn tất", null)
        }

        executor.execute {
            try {
                Thread.sleep(flow.intervalSeconds * 1000L)
                while (!flow.cancelled.get() && Instant.now().isBefore(flow.expiresAt)) {
                    val fields = mutableMapOf(
                        "client_id" to flow.provider.clientId,
                        "device_code" to flow.deviceCode,
                        "grant_type" to "urn:ietf:params:oauth:grant-type:device_code",
                    )
                    flow.codeVerifier?.let { fields["code_verifier"] = it }
                    val payload = postForm(flow.provider.tokenUrl, fields, allowOAuthError = true)
                    when (val error = payload.optString("error").ifBlank { null }) {
                        null -> {
                            val credential = NativeOAuthCredential(
                                accessToken = payload.requireString("access_token"),
                                refreshToken = payload.optString("refresh_token").ifBlank { null },
                                expiresAt = payload.optLong("expires_in", 0)
                                    .takeIf { it > 0 }
                                    ?.let { Instant.now().plusSeconds(it).toString() },
                                scope = payload.optString("scope").ifBlank { null },
                            )
                            flows.remove(flowId)
                            result.success(credential.toMap())
                            return@execute
                        }
                        "authorization_pending" -> Unit
                        "slow_down" -> flow.intervalSeconds += 5
                        "access_denied" -> throw OAuthTransportException("access_denied", "Người dùng đã từ chối đăng nhập")
                        "expired_token" -> throw OAuthTransportException("expired_flow", "Mã đăng nhập đã hết hạn")
                        else -> throw OAuthTransportException("oauth_rejected", payload.optString("error_description", error))
                    }
                    Thread.sleep(flow.intervalSeconds * 1000L)
                }
                throw OAuthTransportException(if (flow.cancelled.get()) "cancelled" else "expired_flow", "OAuth flow đã dừng hoặc hết hạn")
            } catch (error: OAuthTransportException) {
                flows.remove(flowId)
                result.error(error.code, error.message, null)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                flows.remove(flowId)
                result.error("cancelled", "OAuth flow đã bị hủy", null)
            } catch (_: Exception) {
                flows.remove(flowId)
                result.error("oauth_transport", "Không thể hoàn tất OAuth native", null)
            }
        }
    }

    private fun startAuthorization(call: MethodCall, result: MethodChannel.Result) {
        val providerId = call.argument<String>("providerId") ?: return result.error("invalid_provider", "Missing provider id", null)
        val provider = try {
            OAuthProviderRegistry.requireAuthorizationProvider(providerId)
        } catch (error: IllegalArgumentException) {
            return result.error("unsupported_provider", error.message, null)
        }
        executor.execute {
            try {
                val server = ServerSocket(
                    0,
                    1,
                    java.net.InetAddress.getByName("127.0.0.1"),
                ).apply { soTimeout = 300_000 }
                val flowId = UUID.randomUUID().toString()
                val state = generateCodeVerifier()
                val redirectUri = "http://127.0.0.1:${server.localPort}/callback"
                val flow = ActiveAuthorizationFlow(provider, state, redirectUri, server)
                authorizationFlows[flowId] = flow
                activeAuthFlowId = flowId
                android.util.Log.i("NativeOAuth", "Started auth flow: $flowId on port ${server.localPort}")
                executor.execute { receiveAuthorizationCallback(flowId, flow) }
                val query = mapOf(
                    "client_id" to provider.clientId,
                    "response_type" to "code",
                    "redirect_uri" to redirectUri,
                    "scope" to provider.scope,
                    "state" to state,
                    "access_type" to "offline",
                    "prompt" to "consent",
                ).entries.joinToString("&") { (key, value) -> "${encode(key)}=${encode(value)}" }
                result.success(
                    NativeAuthorizationFlow(flowId, URI("${provider.authorizeUrl}?$query")).toMap()
                )
            } catch (_: Exception) {
                result.error("oauth_transport", "Không thể bắt đầu OAuth Google", null)
            }
        }
    }

    private fun receiveAuthorizationCallback(flowId: String, flow: ActiveAuthorizationFlow) {
        LoopbackAuthorizationListener(
            server = flow.server,
            expectedState = flow.state,
            callback = flow.callback,
            cancelled = flow.cancelled,
        ).run()
        if (flow.callback.isCompletedExceptionally) authorizationFlows.remove(flowId)
    }

    private fun completeAuthorization(call: MethodCall, result: MethodChannel.Result) {
        val flowIdArg = call.argument<String>("flowId")
        val flowId = if (flowIdArg != null && authorizationFlows.containsKey(flowIdArg)) flowIdArg else activeAuthFlowId
        android.util.Log.i("NativeOAuth", "completeAuthorization flowIdArg=$flowIdArg activeAuthFlowId=$activeAuthFlowId final=$flowId")
        val flow = flowId?.let(authorizationFlows::get) ?: return result.error("invalid_flow", "OAuth flow không tồn tại hoặc đã hết hạn", null)
        executor.execute {
            try {
                val callback = flow.callback.get()
                callback["error"]?.let { throw OAuthTransportException(it, callback["error_description"] ?: it) }
                val code = callback["code"]?.takeIf { it.isNotBlank() } ?: throw OAuthTransportException("invalid_response", "Google không trả authorization code")
                val tokenFields = mutableMapOf(
                    "grant_type" to "authorization_code",
                    "client_id" to flow.provider.clientId,
                    "code" to code,
                    "redirect_uri" to flow.redirectUri,
                )
                flow.provider.clientSecret?.let { tokenFields["client_secret"] = it }
                val tokens = postForm(flow.provider.tokenUrl, tokenFields)
                val accessToken = tokens.requireString("access_token")
                val project = loadGeminiProject(accessToken)
                result.success(NativeOAuthCredential(
                    accessToken = accessToken,
                    refreshToken = tokens.optString("refresh_token").ifBlank { null },
                    expiresAt = tokens.optLong("expires_in", 0).takeIf { it > 0 }?.let { Instant.now().plusSeconds(it).toString() },
                    scope = tokens.optString("scope").ifBlank { null },
                    projectId = project,
                ).toMap())
            } catch (error: Exception) {
                val oauth = error.cause as? OAuthTransportException ?: error as? OAuthTransportException
                result.error(oauth?.code ?: "oauth_transport", oauth?.message ?: "Không thể hoàn tất OAuth Google", null)
            } finally {
                authorizationFlows.remove(flowId)?.let { runCatching { it.server.close() } }
                if (activeAuthFlowId == flowId) activeAuthFlowId = null
            }
        }
    }

    private fun refresh(call: MethodCall, result: MethodChannel.Result) {
        val providerId = call.argument<String>("providerId") ?: return result.error("invalid_refresh", "Thiếu provider", null)
        val refreshToken = call.argument<String>("refreshToken") ?: return result.error("invalid_refresh", "Thiếu refresh token", null)
        val clientAndUrl = try {
            val authorizationProvider = OAuthProviderRegistry.authorizationProviderOrNull(providerId)
            if (authorizationProvider != null) {
                Triple(
                    authorizationProvider.clientId,
                    authorizationProvider.clientSecret,
                    authorizationProvider.tokenUrl,
                )
            } else {
                val provider = OAuthProviderRegistry.requireDeviceProvider(providerId)
                Triple(provider.clientId, null, provider.refreshUrl ?: throw IllegalArgumentException("Provider không hỗ trợ refresh native"))
            }
        } catch (error: IllegalArgumentException) {
            return result.error("unsupported_provider", error.message, null)
        }
        val (clientId, clientSecret, refreshUrl) = clientAndUrl
        executor.execute {
            try {
                val fields = mutableMapOf(
                    "grant_type" to "refresh_token",
                    "refresh_token" to refreshToken,
                    "client_id" to clientId,
                )
                clientSecret?.let { fields["client_secret"] = it }
                val payload = postForm(refreshUrl, fields)
                result.success(
                    NativeOAuthCredential(
                        accessToken = payload.requireString("access_token"),
                        refreshToken = payload.optString("refresh_token").ifBlank { refreshToken },
                        expiresAt = payload.optLong("expires_in", 0).takeIf { it > 0 }?.let { Instant.now().plusSeconds(it).toString() },
                        scope = payload.optString("scope").ifBlank { null },
                    ).toMap()
                )
            } catch (error: Exception) {
                result.error("refresh_failed", "Không thể tự động cập nhật token", null)
            }
        }
    }

    private fun loadGeminiProject(accessToken: String): String {
        val connection = URL("https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist").openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.doOutput = true
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Authorization", "Bearer $accessToken")
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("User-Agent", "google-api-nodejs-client/9.15.1")
        connection.setRequestProperty("X-Goog-Api-Client", "google-cloud-sdk vscode_cloudshelleditor/0.1")
        val metadata = JSONObject().put("ideType", 9).put("platform", 4).put("pluginType", 2)
        connection.setRequestProperty("Client-Metadata", metadata.toString())
        val body = JSONObject().put("metadata", metadata).put("mode", 1).toString()
        connection.outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
        val payload = readJsonResponse(connection, "Cloud Code Assist")
        val project = payload.opt("cloudaicompanionProject")
        return when (project) {
            is String -> project.trim()
            is JSONObject -> project.optString("id").trim()
            else -> ""
        }.takeIf { it.isNotBlank() } ?: throw OAuthTransportException("missing_project", "Google không trả Cloud Code project")
    }

    private fun readJsonResponse(connection: HttpURLConnection, label: String): JSONObject = try {
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
        if (status !in 200..299) throw OAuthTransportException("oauth_http", "$label trả HTTP $status")
        runCatching { JSONObject(text) }.getOrElse {
            throw OAuthTransportException("invalid_response", "$label trả dữ liệu không hợp lệ")
        }
    } finally {
        connection.disconnect()
    }

    private fun postForm(uri: URI, fields: Map<String, String>, allowOAuthError: Boolean = false): JSONObject {
        val connection = URL(uri.toString()).openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.doOutput = true
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
        val body = fields.entries.joinToString("&") { (key, value) -> "${encode(key)}=${encode(value)}" }
        return try {
            connection.outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            val payload = runCatching { JSONObject(text) }.getOrElse {
                throw OAuthTransportException("invalid_response", "OAuth server trả dữ liệu không hợp lệ")
            }
            if (status !in 200..299 && !(allowOAuthError && payload.optString("error").isNotBlank())) {
                throw OAuthTransportException("oauth_http", "OAuth server trả HTTP $status")
            }
            payload
        } finally {
            connection.disconnect()
        }
    }

    private fun encode(value: String): String = URLEncoder.encode(value, StandardCharsets.UTF_8.toString())
    private fun generateCodeVerifier(): String {
        val bytes = ByteArray(64).also(SecureRandom()::nextBytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
    private fun codeChallenge(verifier: String): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(
            MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
        )
    private fun requireHttpsUri(value: String): URI = URI(value).also {
        if (it.scheme != "https" || it.host.isNullOrBlank()) {
            throw OAuthTransportException("invalid_response", "OAuth server trả URL không hợp lệ")
        }
    }
    private fun JSONObject.requireString(key: String): String =
        optString(key).takeIf { it.isNotBlank() } ?: throw OAuthTransportException("invalid_response", "OAuth server thiếu $key")
    private fun JSONObject.requirePositiveInt(key: String): Int =
        optInt(key).takeIf { it > 0 } ?: throw OAuthTransportException("invalid_response", "OAuth server thiếu $key")
}
