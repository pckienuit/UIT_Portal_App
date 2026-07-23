package com.personal.uit_portal_app.router

import android.content.Context
import android.content.pm.PackageManager
import android.util.Base64
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.URL
import java.security.SecureRandom
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class RouterRuntime(private val context: Context) {
    sealed interface Status {
        data object Stopped : Status
        data object Starting : Status
        data class Ready(val baseUrl: String, val bearer: String) : Status
        data class Failed(val message: String) : Status
    }

    fun ensureStarted(onComplete: (Status) -> Unit) {
        synchronized(processLock) {
            when (val current = status) {
                is Status.Ready, is Status.Failed -> onComplete(current)
                Status.Starting -> executor.execute { onComplete(awaitReady()) }
                Status.Stopped -> {
                    status = Status.Starting
                    executor.execute {
                        status = runCatching { startAndWait() }
                            .getOrElse {
                                Status.Failed(
                                    it.message ?: "Không thể khởi động Core AI nội bộ",
                                )
                            }
                        onComplete(status)
                    }
                }
            }
        }
    }

    fun currentStatus(): Status = status

    private fun startAndWait(): Status.Ready {
        val port = ServerSocket(0).use { it.localPort }
        val bearer = newBearer()
        val projectDirectory = File(context.filesDir, "nodejs-project")
        copyProjectIfNeeded(projectDirectory)

        Thread {
            startNodeWithArguments(
                arrayOf(
                    "node",
                    File(projectDirectory, "main.js").absolutePath,
                    port.toString(),
                    bearer,
                    context.filesDir.absolutePath,
                ),
            )
        }.apply {
            name = "embedded-ai-core-node"
            isDaemon = true
            start()
        }

        val baseUrl = "http://${RouterRuntimeConfig.IPV4_LOOPBACK}:$port"
        repeat(200) {
            if (isHealthy(baseUrl, bearer)) return Status.Ready(baseUrl, bearer)
            Thread.sleep(100)
        }
        throw IllegalStateException("Core AI nội bộ không phản hồi health check")
    }

    private fun awaitReady(): Status {
        repeat(200) {
            val current = status
            if (current !is Status.Starting) return current
            Thread.sleep(100)
        }
        return Status.Failed("Core AI nội bộ khởi động quá lâu")
    }

    private fun isHealthy(baseUrl: String, bearer: String): Boolean {
        return runCatching {
            val connection = URL("$baseUrl/health").openConnection() as HttpURLConnection
            connection.connectTimeout = 250
            connection.readTimeout = 250
            connection.setRequestProperty("Authorization", "Bearer $bearer")
            try {
                connection.responseCode == HttpURLConnection.HTTP_OK
            } finally {
                connection.disconnect()
            }
        }.getOrDefault(false)
    }

    private fun copyProjectIfNeeded(destination: File) {
        val apkUpdateTime = context.packageManager
            .getPackageInfo(context.packageName, 0)
            .lastUpdateTime
        val preferences = context.getSharedPreferences("router_runtime", Context.MODE_PRIVATE)
        if (destination.exists() && preferences.getLong("apk_update_time", 0) == apkUpdateTime) return

        destination.deleteRecursively()
        copyAssetTree("nodejs-project", destination)
        check(preferences.edit().putLong("apk_update_time", apkUpdateTime).commit()) {
            "Không thể lưu phiên bản Core AI asset"
        }
    }

    private fun copyAssetTree(assetPath: String, destination: File) {
        val children = context.assets.list(assetPath) ?: emptyArray()
        if (children.isEmpty()) {
            destination.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input ->
                FileOutputStream(destination).use { output -> input.copyTo(output) }
            }
            return
        }

        destination.mkdirs()
        children.forEach { child -> copyAssetTree("$assetPath/$child", File(destination, child)) }
    }

    private fun newBearer(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.NO_PADDING or Base64.NO_WRAP or Base64.URL_SAFE)
    }

    private external fun startNodeWithArguments(arguments: Array<String>): Int

    companion object {
        private val processLock = Any()
        private val executor: ExecutorService = Executors.newSingleThreadExecutor()

        @Volatile
        private var status: Status = Status.Stopped

        init {
            System.loadLibrary("node")
            System.loadLibrary("router_node_bridge")
        }
    }
}
