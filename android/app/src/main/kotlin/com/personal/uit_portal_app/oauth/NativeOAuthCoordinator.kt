package com.personal.uit_portal_app.oauth

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class NativeOAuthCoordinator {
    private data class ActiveFlow(
        val provider: DeviceOAuthProvider,
        val deviceCode: String,
        val expiresAt: Instant,
        var intervalSeconds: Int,
        val cancelled: AtomicBoolean = AtomicBoolean(false),
        val completing: AtomicBoolean = AtomicBoolean(false),
    )

    private val executor = Executors.newCachedThreadPool()
    private val flows = ConcurrentHashMap<String, ActiveFlow>()

    fun close() {
        flows.values.forEach { it.cancelled.set(true) }
        flows.clear()
        executor.shutdownNow()
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDevice" -> startDevice(call, result)
            "completeDevice" -> completeDevice(call, result)
            "cancel" -> {
                call.argument<String>("flowId")?.let { flowId ->
                    flows.remove(flowId)?.cancelled?.set(true)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startDevice(call: MethodCall, result: MethodChannel.Result) {
        val providerId = call.argument<String>("providerId")
        if (providerId.isNullOrBlank()) {
            result.error("invalid_provider", "Missing provider id", null)
            return
        }
        val provider = try {
            val registered = OAuthProviderRegistry.requireDeviceProvider(providerId)
            val overrideClientId = call.argument<String>("clientId")
            if (overrideClientId.isNullOrBlank()) registered else registered.copy(clientId = overrideClientId)
        } catch (error: IllegalArgumentException) {
            result.error("unsupported_provider", error.message, null)
            return
        }

        executor.execute {
            try {
                val payload = postForm(
                    provider.deviceCodeUrl,
                    mapOf("client_id" to provider.clientId, "scope" to provider.scope),
                )
                val expiresIn = payload.requirePositiveInt("expires_in")
                val interval = payload.optInt("interval", 5).coerceAtLeast(1)
                val verificationUri = requireHttpsUri(payload.requireString("verification_uri"))
                val flowId = UUID.randomUUID().toString()
                val flow = ActiveFlow(
                    provider = provider,
                    deviceCode = payload.requireString("device_code"),
                    expiresAt = Instant.now().plusSeconds(expiresIn.toLong()),
                    intervalSeconds = interval,
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
        val flowId = call.argument<String>("flowId")
        val flow = flowId?.let(flows::get)
        if (flowId.isNullOrBlank() || flow == null) {
            result.error("invalid_flow", "OAuth flow không tồn tại hoặc đã hết hạn", null)
            return
        }
        if (!flow.completing.compareAndSet(false, true)) {
            result.error("flow_in_progress", "OAuth flow đang được hoàn tất", null)
            return
        }

        executor.execute {
            try {
                while (!flow.cancelled.get() && Instant.now().isBefore(flow.expiresAt)) {
                    val payload = postForm(
                        flow.provider.tokenUrl,
                        mapOf(
                            "client_id" to flow.provider.clientId,
                            "device_code" to flow.deviceCode,
                            "grant_type" to "urn:ietf:params:oauth:grant-type:device_code",
                        ),
                    )
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
                        "access_denied" -> throw OAuthTransportException(
                            "access_denied",
                            "Người dùng đã từ chối đăng nhập",
                        )
                        "expired_token" -> throw OAuthTransportException(
                            "expired_flow",
                            "Mã đăng nhập đã hết hạn",
                        )
                        else -> throw OAuthTransportException(
                            "oauth_rejected",
                            payload.optString("error_description", error),
                        )
                    }
                    Thread.sleep(flow.intervalSeconds * 1000L)
                }
                val code = if (flow.cancelled.get()) "cancelled" else "expired_flow"
                throw OAuthTransportException(code, "OAuth flow đã dừng hoặc hết hạn")
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

    private fun postForm(uri: URI, fields: Map<String, String>): JSONObject {
        val connection = URL(uri.toString()).openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.doOutput = true
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
        val body = fields.entries.joinToString("&") { (key, value) ->
            "${encode(key)}=${encode(value)}"
        }
        return try {
            connection.outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                throw OAuthTransportException("oauth_http", "OAuth server trả HTTP $status")
            }
            JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.toString())

    private fun requireHttpsUri(value: String): URI = URI(value).also {
        if (it.scheme != "https" || it.host.isNullOrBlank()) {
            throw OAuthTransportException("invalid_response", "OAuth server trả URL không hợp lệ")
        }
    }

    private fun JSONObject.requireString(key: String): String =
        optString(key).takeIf { it.isNotBlank() }
            ?: throw OAuthTransportException("invalid_response", "OAuth server thiếu $key")

    private fun JSONObject.requirePositiveInt(key: String): Int =
        optInt(key).takeIf { it > 0 }
            ?: throw OAuthTransportException("invalid_response", "OAuth server thiếu $key")

    private class OAuthTransportException(val code: String, message: String) : Exception(message)
}
