package com.personal.uit_portal_app

import com.personal.uit_portal_app.router.RouterRuntime
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var routerRuntime: RouterRuntime

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        routerRuntime = RouterRuntime(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.personal.uitportal/router")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureStarted" -> routerRuntime.ensureStarted { status ->
                        runOnUiThread { result.success(status.toMap()) }
                    }
                    "status" -> result.success(routerRuntime.currentStatus().toMap())
                    else -> result.notImplemented()
                }
            }
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
