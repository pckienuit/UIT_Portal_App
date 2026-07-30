package com.pckienuit.uitportal.router

class RouterRuntimeConfig(
    val host: String,
    val port: Int,
) {
    init {
        require(host == IPV4_LOOPBACK || host == IPV6_LOOPBACK) {
            "Router runtime must bind to loopback only"
        }
        require(port in 0..65535) {
            "Router runtime port must be between 0 and 65535"
        }
    }

    companion object {
        const val IPV4_LOOPBACK = "127.0.0.1"
        const val IPV6_LOOPBACK = "::1"
    }
}
