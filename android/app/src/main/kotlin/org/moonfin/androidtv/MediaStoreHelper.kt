package org.moonfin.androidtv

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MediaStoreHelper(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.moonfin/media_store"
        private const val SUBFOLDER = "Moonfin"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDownloadPath" -> {
                val relativePath = call.argument<String>("relativePath") ?: ""
                val fileName = call.argument<String>("fileName") ?: ""
                if (fileName.isEmpty()) {
                    result.error("INVALID_ARG", "fileName is required", null)
                    return
                }
                try {
                    val path = createMediaStoreEntry(relativePath, fileName)
                    result.success(path)
                } catch (e: Exception) {
                    result.error("MEDIA_STORE_ERROR", e.message, null)
                }
            }
            "writeFile" -> {
                val relativePath = call.argument<String>("relativePath") ?: ""
                val fileName = call.argument<String>("fileName") ?: ""
                val bytes = call.argument<ByteArray>("bytes")
                if (fileName.isEmpty() || bytes == null) {
                    result.error("INVALID_ARG", "fileName and bytes are required", null)
                    return
                }
                try {
                    result.success(writeFile(relativePath, fileName, bytes))
                } catch (e: Exception) {
                    result.error("MEDIA_STORE_ERROR", e.message, null)
                }
            }
            "getMediaStorePath" -> {
                val base = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                ).absolutePath + "/$SUBFOLDER"
                result.success(base)
            }
            else -> result.notImplemented()
        }
    }

    private fun collectionUri(): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Files.getContentUri("external")
        }

    private fun targetFile(relativePath: String, fileName: String): File {
        val base = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        val dir = if (relativePath.isEmpty()) {
            File(base, SUBFOLDER)
        } else {
            File(File(base, SUBFOLDER), relativePath)
        }
        return File(dir, fileName)
    }

    private fun buildRelativePath(relativePath: String): String =
        if (relativePath.isEmpty()) {
            "${Environment.DIRECTORY_DOWNLOADS}/$SUBFOLDER"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$SUBFOLDER/$relativePath"
        }

    // Removes any existing entry (and its file) for this name, so a re-download
    // overwrites instead of MediaStore renaming the new file to "name (1).ext".
    private fun deleteExisting(fileName: String, fullRelativePath: String) {
        val collection = collectionUri()
        val selection: String
        val selectionArgs: Array<String>
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            selection =
                "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
            selectionArgs = arrayOf(fileName, "$fullRelativePath/")
        } else {
            selection = "${MediaStore.Files.FileColumns.DISPLAY_NAME} = ?"
            selectionArgs = arrayOf(fileName)
        }

        val existingPhysicalPath: String? = try {
            context.contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns.DATA),
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA))
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }

        context.contentResolver.delete(collection, selection, selectionArgs)

        existingPhysicalPath?.let { File(it).delete() }
    }

    private fun insertEntry(
        fileName: String,
        fullRelativePath: String,
        pending: Boolean,
    ): Uri {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, guessMimeType(fileName))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.RELATIVE_PATH, fullRelativePath)
                put(MediaStore.Downloads.IS_PENDING, if (pending) 1 else 0)
            }
        }

        return context.contentResolver.insert(collectionUri(), values)
            ?: throw IllegalStateException("Failed to create MediaStore entry for $fileName")
    }

    private fun dataPath(uri: Uri): String? =
        try {
            context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DATA),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA))
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }

    private fun createMediaStoreEntry(relativePath: String, fileName: String): String {
        val fullRelativePath = buildRelativePath(relativePath)

        deleteExisting(fileName, fullRelativePath)

        val uri = insertEntry(fileName, fullRelativePath, pending = false)

        // Resolve the real file path from the URI
        return dataPath(uri) ?: targetFile(relativePath, fileName).absolutePath
    }

    /**
     * Writes [bytes] into `Download/Moonfin/<relativePath>/<fileName>` through the
     * MediaStore and returns the file's absolute path.
     *
     * Android 16 silently discards a raw `File` write into the public Downloads
     * folder (measured on device: a 0-byte file that then vanishes), which is why
     * small sidecars like subtitles cannot use the path [createMediaStoreEntry]
     * returns — the bytes have to go through the ContentResolver.
     */
    private fun writeFile(relativePath: String, fileName: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val target = targetFile(relativePath, fileName)
            target.parentFile?.mkdirs()
            target.writeBytes(bytes)
            return target.absolutePath
        }

        val fullRelativePath = buildRelativePath(relativePath)

        deleteExisting(fileName, fullRelativePath)

        val uri = insertEntry(fileName, fullRelativePath, pending = true)

        val out = context.contentResolver.openOutputStream(uri, "w")
            ?: throw IllegalStateException("Failed to open $uri for writing")
        out.use { it.write(bytes) }

        context.contentResolver.update(
            uri,
            ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
            null,
            null
        )

        return dataPath(uri) ?: targetFile(relativePath, fileName).absolutePath
    }

    private fun guessMimeType(fileName: String): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".mkv") -> "video/x-matroska"
            lower.endsWith(".mp4") || lower.endsWith(".m4v") -> "video/mp4"
            lower.endsWith(".avi") -> "video/x-msvideo"
            lower.endsWith(".webm") -> "video/webm"
            lower.endsWith(".ts") -> "video/mp2t"
            lower.endsWith(".flac") -> "audio/flac"
            lower.endsWith(".mp3") -> "audio/mpeg"
            lower.endsWith(".m4a") -> "audio/mp4"
            lower.endsWith(".ogg") -> "audio/ogg"
            lower.endsWith(".opus") -> "audio/opus"
            lower.endsWith(".wav") -> "audio/wav"
            lower.endsWith(".srt") -> "application/x-subrip"
            lower.endsWith(".ass") || lower.endsWith(".ssa") -> "text/x-ssa"
            lower.endsWith(".vtt") -> "text/vtt"
            lower.endsWith(".ttml") || lower.endsWith(".dfxp") -> "application/ttml+xml"
            lower.endsWith(".sub") -> "text/plain"
            lower.endsWith(".epub") -> "application/epub+zip"
            lower.endsWith(".pdf") -> "application/pdf"
            else -> "application/octet-stream"
        }
    }
}
