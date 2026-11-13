package com.in4up

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.Locale

// PSRC-222 — Trich xuat va chep ngay URI ben ngoai (ACTION_VIEW, ACTION_SEND)
// vao bo nho rieng cua ung dung truoc khi quyen doc tam cua content URI het han.
// Chi phu thuoc android.jar de co the bien dich doc lap bang kotlinc.
object IncomingFileResolver {

    private const val INCOMING_DIR_NAME = "in4up_incoming"
    private const val BUFFER_BYTES = 64 * 1024
    private const val MAX_STAGED_FILES = 24
    private const val STALE_AGE_MS = 24L * 60L * 60L * 1000L

    fun isIncomingFileIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = extractViewUri(intent) ?: return false
                val scheme = uri.scheme?.lowercase(Locale.ROOT) ?: return false
                scheme == "content" || scheme == "file"
            }
            Intent.ACTION_SEND -> {
                extractSendUri(intent) != null
            }
            else -> false
        }
    }

    fun materializeIncomingIntent(
        context: Context,
        intent: Intent,
    ): Map<String, Any?>? {
        val action = intent.action ?: return null
        val uri: Uri = when (action) {
            Intent.ACTION_VIEW -> extractViewUri(intent)
            Intent.ACTION_SEND -> extractSendUri(intent)
            else -> null
        } ?: return null

        val sourceTag = if (action == Intent.ACTION_SEND) "android_send" else "android_view"
        val incomingDir = File(context.filesDir, INCOMING_DIR_NAME)
        if (!incomingDir.exists() && !incomingDir.mkdirs()) {
            throw IOException("Cannot create incoming dir: ${incomingDir.absolutePath}")
        }
        pruneOldStagedFiles(incomingDir)

        val cr = context.contentResolver
        val rawType = intent.type?.trim()?.takeIf { it.isNotEmpty() && !it.endsWith("*") }
        val resolvedMime = rawType ?: try {
            cr.getType(uri)
        } catch (_: Throwable) {
            null
        }

        val queriedName = queryDisplayName(context, uri)
            ?: uri.lastPathSegment?.substringAfterLast('/')
            ?: "incoming_file"

        val tempPart = File(
            incomingDir,
            "stage_${System.currentTimeMillis()}_${System.nanoTime()}.part",
        )
        val header = ByteArray(4096)
        var headerLen = 0
        var copiedOk = false

        try {
            val scheme = uri.scheme?.lowercase(Locale.ROOT)
            if (scheme == "file") {
                val srcPath = uri.path ?: throw IOException("Empty file URI path")
                val srcFile = File(srcPath)
                FileInputStream(srcFile).use { input ->
                    FileOutputStream(tempPart).use { output ->
                        headerLen = copyCapturingHeader(input, output, header)
                        output.flush()
                        output.fd.sync()
                    }
                }
            } else {
                val stream = cr.openInputStream(uri)
                    ?: throw IOException("ContentResolver returned null InputStream for $uri")
                stream.use { input ->
                    FileOutputStream(tempPart).use { output ->
                        headerLen = copyCapturingHeader(input, output, header)
                        output.flush()
                        output.fd.sync()
                    }
                }
            }
            copiedOk = true
        } finally {
            if (!copiedOk && tempPart.exists()) {
                try {
                    tempPart.delete()
                } catch (_: Throwable) {
                }
            }
        }

        val normalizedName = ensureExtension(
            rawName = sanitizeFileName(queriedName),
            mimeType = resolvedMime,
            header = header,
            headerLen = headerLen,
        )
        val finalName = uniqueNameInDir(incomingDir, normalizedName)
        val finalFile = File(incomingDir, finalName)
        if (!tempPart.renameTo(finalFile)) {
            tempPart.copyTo(finalFile, overwrite = true)
            tempPart.delete()
        }

        return mapOf(
            "localPath" to finalFile.absolutePath,
            "displayName" to finalName,
            "mimeType" to resolvedMime,
            "originalUri" to uri.toString(),
            "source" to sourceTag,
        )
    }

    private fun extractViewUri(intent: Intent): Uri? {
        intent.data?.let { return it }
        val clip = intent.clipData
        if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0)?.uri?.let { return it }
        }
        return null
    }

    private fun extractSendUri(intent: Intent): Uri? {
        val streamUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
        if (streamUri != null) return streamUri

        val clip = intent.clipData
        if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0)?.uri?.let { return it }
        }
        return intent.data
    }

    private fun queryDisplayName(context: Context, uri: Uri): String? {
        if (uri.scheme?.lowercase(Locale.ROOT) == "file") {
            return uri.path?.let { File(it).name }?.takeIf { it.isNotBlank() }
        }
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0 && !cursor.isNull(idx)) {
                        cursor.getString(idx)?.takeIf { it.isNotBlank() }
                    } else {
                        null
                    }
                } else {
                    null
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun copyCapturingHeader(
        input: java.io.InputStream,
        output: FileOutputStream,
        header: ByteArray,
    ): Int {
        val buf = ByteArray(BUFFER_BYTES)
        var captured = 0
        while (true) {
            val read = input.read(buf)
            if (read <= 0) break
            output.write(buf, 0, read)
            if (captured < header.size) {
                val take = minOf(read, header.size - captured)
                System.arraycopy(buf, 0, header, captured, take)
                captured += take
            }
        }
        return captured
    }

    private fun ensureExtension(
        rawName: String,
        mimeType: String?,
        header: ByteArray,
        headerLen: Int,
    ): String {
        val dot = rawName.lastIndexOf('.')
        val existingExt = if (dot > 0 && dot < rawName.length - 1) {
            rawName.substring(dot + 1).lowercase(Locale.ROOT)
        } else {
            null
        }
        if (existingExt != null && existingExt != "bin" && existingExt != "tmp") {
            return rawName
        }

        val inferredExt = sniffExtension(header, headerLen)
            ?: extensionFromMime(mimeType)
            ?: return rawName

        val stem = if (existingExt != null) {
            rawName.substring(0, dot)
        } else {
            rawName
        }
        return "$stem.$inferredExt"
    }

    private fun sniffExtension(header: ByteArray, len: Int): String? {
        if (len >= 5 &&
            header[0] == 0x25.toByte() &&
            header[1] == 0x50.toByte() &&
            header[2] == 0x44.toByte() &&
            header[3] == 0x46.toByte() &&
            header[4] == 0x2D.toByte()
        ) {
            return "pdf"
        }
        if (len >= 30 &&
            header[0] == 0x50.toByte() &&
            header[1] == 0x4B.toByte() &&
            header[2] == 0x03.toByte() &&
            header[3] == 0x04.toByte()
        ) {
            val ascii = String(
                ByteArray(len) { idx ->
                    val b = header[idx].toInt() and 0xFF
                    if (b in 32..126) b.toByte() else 0x20.toByte()
                },
                Charsets.US_ASCII,
            )
            if (ascii.contains("word/")) return "docx"
        }
        return null
    }

    private fun extensionFromMime(mimeType: String?): String? {
        val mime = mimeType?.substringBefore(';')?.trim()?.lowercase(Locale.ROOT)
            ?.takeIf { it.isNotEmpty() } ?: return null
        return when (mime) {
            "application/pdf" -> "pdf"
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "docx"
            "text/markdown", "text/x-markdown" -> "md"
            "application/x-subrip", "text/srt" -> "srt"
            "text/vtt" -> "vtt"
            "text/plain" -> "txt"
            "audio/mpeg", "audio/mp3" -> "mp3"
            "audio/mp4", "audio/x-m4a", "audio/m4a" -> "m4a"
            "audio/wav", "audio/x-wav", "audio/wave" -> "wav"
            "audio/ogg", "application/ogg" -> "ogg"
            "audio/opus" -> "opus"
            "audio/flac", "audio/x-flac" -> "flac"
            "video/mp4" -> "mp4"
            "video/x-matroska" -> "mkv"
            "video/webm" -> "webm"
            "video/quicktime" -> "mov"
            else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        }
    }

    private fun sanitizeFileName(raw: String): String {
        var cleaned = raw.replace(Regex("[\\x00-\\x1F<>:\"/\\\\|?*]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
            .trimEnd('.', ' ')
        if (cleaned.isEmpty() || cleaned == ".") {
            cleaned = "incoming_file"
        }
        return cleaned
    }

    private fun uniqueNameInDir(dir: File, desired: String): String {
        if (!File(dir, desired).exists()) return desired
        val dot = desired.lastIndexOf('.')
        val hasExt = dot > 0 && dot < desired.length - 1
        val stem = if (hasExt) desired.substring(0, dot) else desired
        val ext = if (hasExt) desired.substring(dot) else ""
        for (i in 2 until 10000) {
            val candidate = "$stem ($i)$ext"
            if (!File(dir, candidate).exists()) return candidate
        }
        return "${stem}_${System.currentTimeMillis()}$ext"
    }

    private fun pruneOldStagedFiles(dir: File) {
        val files = dir.listFiles()?.filter { it.isFile }?.sortedByDescending { it.lastModified() }
            ?: return
        val cutoff = System.currentTimeMillis() - STALE_AGE_MS
        files.forEachIndexed { idx, file ->
            if (idx >= MAX_STAGED_FILES || file.lastModified() < cutoff) {
                try {
                    file.delete()
                } catch (_: Throwable) {
                }
            }
        }
    }
}
