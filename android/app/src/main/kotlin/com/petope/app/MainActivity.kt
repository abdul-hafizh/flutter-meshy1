package com.petope.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * "Bagikan ke Petope": a file shared from another app arrives as an
 * ACTION_SEND intent with a content:// URI that only this activity may read,
 * so it is copied into the app's cache first. Flutter takes it over the
 * "com.petope.app/share" channel (lib/services/shared_file_service.dart).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingShare: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Hands the shared file over once, then forgets it.
                    "takeSharedFile" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShare(intent)
    }

    private fun handleShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val uri: Uri = streamOf(intent) ?: return
        // Don't take the same share again when the activity is recreated.
        intent.action = Intent.ACTION_MAIN
        Thread {
            val shared = try {
                copyToCache(uri)
            } catch (e: Exception) {
                mapOf("error" to "read_failed")
            }
            runOnUiThread {
                pendingShare = shared
                channel?.invokeMethod("sharedFileAvailable", null)
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    /** Copies the shared file to cache/shared/ → { path, name, size } or { error, name }. */
    private fun copyToCache(uri: Uri): Map<String, Any?> {
        var name = "file"
        var size = -1L
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                c.getColumnIndex(OpenableColumns.DISPLAY_NAME).takeIf { it >= 0 && !c.isNull(it) }?.let { name = c.getString(it) }
                c.getColumnIndex(OpenableColumns.SIZE).takeIf { it >= 0 && !c.isNull(it) }?.let { size = c.getLong(it) }
            }
        }
        if (size > MAX_BYTES) return mapOf("error" to "too_large", "name" to name)

        val dir = File(cacheDir, "shared").apply {
            // Only the latest shared file is kept.
            deleteRecursively()
            mkdirs()
        }
        val safeName = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val target = File(dir, safeName)
        var copied = 0L
        contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    copied += read
                    if (copied > MAX_BYTES) {
                        output.close()
                        target.delete()
                        return mapOf("error" to "too_large", "name" to name)
                    }
                    output.write(buffer, 0, read)
                }
            }
        } ?: return mapOf("error" to "read_failed", "name" to name)
        return mapOf("path" to target.absolutePath, "name" to name, "size" to copied)
    }

    companion object {
        private const val CHANNEL = "com.petope.app/share"
        // Same limit as the print-file upload (PrintFileService.maxBytes).
        private const val MAX_BYTES = 50L * 1024 * 1024
    }
}
