package com.personal.uit_portal_app.oauth

import java.net.URI

data class DeviceOAuthProvider(
    val id: String,
    val clientId: String,
    val deviceCodeUrl: URI,
    val tokenUrl: URI,
    val scope: String,
    val usesPkce: Boolean = false,
    val refreshUrl: URI? = null,
) {
    constructor(
        id: String,
        clientId: String,
        deviceCodeUrl: String,
        tokenUrl: String,
        scope: String,
        usesPkce: Boolean = false,
        refreshUrl: String? = null,
    ) : this(
        id = id,
        clientId = clientId,
        deviceCodeUrl = requireHttps(deviceCodeUrl),
        tokenUrl = requireHttps(tokenUrl),
        scope = scope,
        usesPkce = usesPkce,
        refreshUrl = refreshUrl?.let(::requireHttps),
    )

    init {
        require(id.isNotBlank()) { "Provider id is required" }
        require(clientId.isNotBlank()) { "OAuth client id is required" }
        require(scope.isNotBlank()) { "OAuth scope is required" }
        require(deviceCodeUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
        require(tokenUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
        require(refreshUrl == null || refreshUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
    }
}

private fun requireHttps(value: String): URI = URI(value).also {
    require(it.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
}

private fun URI.isHttpsEndpoint(): Boolean =
    scheme == "https" && !host.isNullOrBlank() && isAbsolute

data class AuthorizationOAuthProvider(
    val id: String,
    val clientId: String,
    val clientSecret: String?,
    val authorizeUrl: URI,
    val tokenUrl: URI,
    val scope: String,
    val usesPkce: Boolean = false,
    val callbackHost: String? = null,
    val callbackPort: Int? = null,
    val callbackPath: String? = null,
    val extraAuthorizationParams: Map<String, String> = emptyMap(),
    val resolvesGoogleProject: Boolean = true,
) {
    init {
        require(id.isNotBlank()) { "Provider id is required" }
        require(clientId.isNotBlank()) { "OAuth client id is required" }
        require(clientSecret == null || clientSecret.isNotBlank()) { "OAuth client secret is invalid" }
        require(scope.isNotBlank()) { "OAuth scope is required" }
        require(authorizeUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
        require(tokenUrl.isHttpsEndpoint()) { "OAuth endpoints must use HTTPS" }
    }
}

data class NativeAuthorizationFlow(
    val flowId: String,
    val authorizationUri: URI,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "flowId" to flowId,
        "authorizationUri" to authorizationUri.toString(),
    )
}

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
    val projectId: String? = null,
    val accountId: String? = null,
) {
    init {
        require(accessToken.isNotBlank()) { "OAuth access token is required" }
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "accessToken" to accessToken,
        "refreshToken" to refreshToken,
        "expiresAt" to expiresAt,
        "scope" to scope,
        "projectId" to projectId,
        "accountId" to accountId,
    )
}
