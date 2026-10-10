package com.familyfinance.family_finance_manager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var shareChannel: MethodChannel? = null

    // Path of an image shared into the app, waiting for Flutter to take it.
    private var sharedImage: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSharedImage" -> {
                        result.success(sharedImage)
                        sharedImage = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Finance data must not show in the recent-apps preview. Unlike
        // FLAG_SECURE this still allows the user's own screenshots.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        // A recreated activity gets the same intent again; read it once.
        if (savedInstanceState == null) receiveShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (receiveShare(intent)) shareChannel?.invokeMethod("sharedImage", null)
    }

    /**
     * Share -> Family Finance with a screenshot or receipt photo. The read
     * permission for the shared item ends with this intent, so the image is
     * copied into the app's cache for the on-device text reader.
     */
    private fun receiveShare(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        if (intent.type?.startsWith("image/") != true) return false
        val uri: Uri = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }) ?: return false
        // Handled: a later recreation must not import the same image again.
        intent.action = Intent.ACTION_MAIN

        cacheDir.listFiles { f -> f.name.startsWith(SHARED_PREFIX) }?.forEach { it.delete() }
        val target = File(cacheDir, "$SHARED_PREFIX${System.currentTimeMillis()}")
        return try {
            val copied = contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > MAX_SHARED_BYTES) return@use false
                        output.write(buffer, 0, read)
                    }
                    true
                }
            } ?: false
            if (copied) sharedImage = target.absolutePath else target.delete()
            copied
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the shared image", e)
            target.delete()
            false
        }
    }

    companion object {
        private const val TAG = "FamilyFinanceShare"
        private const val SHARE_CHANNEL = "family_finance/share"
        private const val SHARED_PREFIX = "shared_scan_"

        // Screenshots and receipt photos are a few MB; refuse anything huge.
        private const val MAX_SHARED_BYTES = 25L * 1024 * 1024
    }
}
