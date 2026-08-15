package com.pckienuit.uitportal

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import com.pckienuit.uitportal.oauth.NativeOAuthCoordinator
import java.net.URI
import java.net.URISyntaxException
import com.pckienuit.uitportal.router.RouterRuntime
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private val portalArticleSlug = Regex("[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*")

internal fun isPortalArticleUrl(value: String): Boolean {
    return try {
        val uri = URI(value)
        val segments = uri.path?.trimStart('/')?.split('/') ?: return false
        uri.scheme == "https" &&
            uri.host == "portal.uit.edu.vn" &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            segments.size == 2 &&
            segments.first() == "bai-viet" &&
            segments.last().matches(portalArticleSlug)
    } catch (_: URISyntaxException) {
        false
    }
}

class MainActivity : FlutterActivity() {
    private lateinit var routerRuntime: RouterRuntime
    private val nativeOAuthCoordinator = NativeOAuthCoordinator()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        routerRuntime = RouterRuntime(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pckienuit.uitportal/router")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureStarted" -> routerRuntime.ensureStarted { status ->
                        runOnUiThread { result.success(status.toMap()) }
                    }
                    "status" -> result.success(routerRuntime.currentStatus().toMap())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pckienuit.uitportal/oauth")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("invalid_url", "Missing URL", null)
                        } else {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pckienuit.uitportal/external_url")
            .setMethodCallHandler { call, result ->
                if (call.method != "openPortalArticle") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = call.argument<String>("url")?.let(Uri::parse)
                if (uri == null || !isPortalArticleUrl(uri.toString())) {
                    result.error("invalid_url", "Invalid UIT article URL", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri))
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("no_browser", "No browser can open UIT articles", null)
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.pckienuit.uitportal/provider_oauth",
        ).setMethodCallHandler(nativeOAuthCoordinator::handle)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeOAuthCoordinator.close()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun RouterRuntime.Status.toMap(): Map<String, String> = when (this) {
        RouterRuntime.Status.Stopped -> mapOf("state" to "stopped")
        RouterRuntime.Status.Starting -> mapOf("state" to "starting")
        is RouterRuntime.Status.Ready -> mapOf(
            "state" to "ready",
            "baseUrl" to baseUrl,
            "bearer" to bearer,
        )
        is RouterRuntime.Status.Failed -> mapOf(
            "state" to "failed",
            "message" to message,
        )
    }
}
