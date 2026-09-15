package org.moonfin.androidtv

import android.app.DownloadManager
import android.content.Context
import android.database.Cursor
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands media downloads to Android's DownloadManager instead of streaming them
 * through dart:io.
 *
 * Measured on a OnePlus Pad 2 against the same Jellyfin server over the same
 * wifi: dart:io's HttpClient sustains ~8 MB/s per connection while pegging a
 * CPU core, where DownloadManager sustains ~45 MB/s on one connection. It also
 * survives the app being killed and retries on its own, which the Dart isolate
 * path had to hand-roll.
 */
class NativeDownloader(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.moonfin/native_downloader"
    }

    private val manager: DownloadManager
        get() = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enqueue" -> enqueue(call, result)
            "status" -> status(call, result)
            "cancel" -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val savePath = call.argument<String>("savePath")
        if (url.isNullOrEmpty() || savePath.isNullOrEmpty()) {
            result.error("INVALID_ARG", "url and savePath are required", null)
            return
        }

        try {
            val target = File(savePath)
            target.parentFile?.mkdirs()
            // DownloadManager fails rather than overwriting, so clear any
            // partial file left by a previous attempt.
            if (target.exists()) {
                target.delete()
            }

            val request = DownloadManager.Request(Uri.parse(url))
                .setDestinationUri(Uri.fromFile(target))
                .setTitle(call.argument<String>("title") ?: target.name)
                .setAllowedOverRoaming(false)
                .setAllowedOverMetered(call.argument<Boolean>("allowMetered") ?: false)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)

            call.argument<Map<String, String>>("headers")?.forEach { (name, value) ->
                request.addRequestHeader(name, value)
            }

            result.success(manager.enqueue(request))
        } catch (e: Exception) {
            result.error("ENQUEUE_FAILED", e.message, null)
        }
    }

    private fun status(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        if (id == null) {
            result.error("INVALID_ARG", "id is required", null)
            return
        }

        var cursor: Cursor? = null
        try {
            cursor = manager.query(DownloadManager.Query().setFilterById(id))
            if (cursor == null || !cursor.moveToFirst()) {
                // Row is gone: the download was removed, or cleared by the system.
                result.success(mapOf("status" to "gone"))
                return
            }

            val code = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            val soFar = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            )
            val reason = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
            )

            result.success(
                mapOf(
                    "status" to when (code) {
                        DownloadManager.STATUS_SUCCESSFUL -> "done"
                        DownloadManager.STATUS_FAILED -> "failed"
                        DownloadManager.STATUS_PAUSED -> "paused"
                        DownloadManager.STATUS_PENDING -> "pending"
                        else -> "running"
                    },
                    "bytesSoFar" to soFar,
                    "totalBytes" to total,
                    "reason" to reason,
                )
            )
        } catch (e: Exception) {
            result.error("STATUS_FAILED", e.message, null)
        } finally {
            cursor?.close()
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        if (id == null) {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        // remove() both stops the transfer and deletes the partial file.
        manager.remove(id)
        result.success(true)
    }
}
