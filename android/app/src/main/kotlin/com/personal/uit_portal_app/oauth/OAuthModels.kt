package com.personal.uit_portal_app.oauth

import java.net.URI

data class DeviceOAuthProvider(
    val id: String,
    val clientId: String,
    val deviceCodeUrl: URI,
    val tokenUrl: URI,
    val scope: String,
) {
    constructor(
        id: String,
        clientId: String,
        deviceCodeUrl: String,
        tokenUrl: String,
        scope: String,
    ) : this(
        id = id,
        clientId = clientId,
        deviceCodeUrl = requireHttps(deviceCodeUrl),
        tokenUrl = requireHttps(tokenUrl),
        scope = scope,
    )

    init {
        require(id.isNotBlank()) { "Provider id is required" }
        require(clientId.isNotBlank()) { "OAuth client id is required" }
        require(scope.isNotBlank()) { "OAuth scope is required" }
        require(deviceCodeUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
        require(tokenUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
    }
}

private fun requireHttps(value: String): URI = URI(value).also {
    require(it.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
}

private fun URI.isHttpsEndpoint(): Boolean =
    scheme == "https" && !host.isNullOrBlank() && isAbsolute

data class NativeDeviceFlow(
    val flowId: String,
    val providerId: String,
    val userCode: String,
    val verificationUri: URI,
    val expiresAt: String,
    val intervalSeconds: Int,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "flowId" to flowId,
        "userCode" to userCode,
        "verificationUri" to verificationUri.toString(),
        "expiresAt" to expiresAt,
        "intervalSeconds" to intervalSeconds,
    )
}

data class NativeOAuthCredential(
    val accessToken: String,
    val refreshToken: String?,
    val expiresAt: String?,
    val scope: String?,
) {
    init {
        require(accessToken.isNotBlank()) { "OAuth access token is required" }
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "accessToken" to accessToken,
        "refreshToken" to refreshToken,
        "expiresAt" to expiresAt,
        "scope" to scope,
    )
}
