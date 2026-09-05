package com.in4up

import android.content.ContentResolver
import android.content.Intent
import android.content.ContentUris
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * MainActivity — đăng ký MethodChannel cho các thư viện thiết bị.
 *
 * "in4up/audiolib" (Thư viện âm thanh, P1):
 *  - scanMediaStore(): quét MediaStore.Audio (Android) → trả List<Map>:
 *      { id, uri (content://media/external/audio/media/<id>), title, displayName,
 *        artist, durationMs, sizeBytes, dateAddedSec }
 *    Dùng content URI (không dùng DATA — bị chặn trên scoped storage API 29+).
 *  - copyContentToCache(contentUri): copy content:// sang cache dir → trả path
 *    (VAD/waveform/ffmpeg dùng File-based, không đọc được content://).
 *
 * "in4up/textlib" (Thư viện đọc — quét thư mục trên máy):
 *  - scanTree(treeUri): quét TÙY DU YỆC một tree URI (SAF,
 *    ACTION_OPEN_DOCUMENT_TREE) → trả List<Map>:
 *      { uri (content URI document), name, sizeBytes, dateModifiedMs, ext }
 *    Chỉ lấy file có extension thuộc danh sách định dạng đọc
 *    (txt/lrc/srt/md/markdown/json/docx/pdf). Không cần quyền đặc biệt —
 *    quyền do user cấp khi chọn thư mục (persistable URI permission).
 *  - keepTreePermission(treeUri): giữ persistable permission sau khi user
 *    chọn thư mục (an toàn kể cả khi plugin file_picker chưa tự giữ).
 *  - copyContentToCache(contentUri): giống audiolib (đọc file text/PDF).
 *
 * Runtime permission (READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE) do phía Dart
 * xử lý qua permission_handler (đã có sẵn) — native chỉ query/copy.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "in4up/audiolib"
    private val textChannelName = "in4up/textlib"

    // Định dạng đọc hỗ trợ bởi tab Thiết bị của Thư viện đọc.
    private val textExtensions = setOf(
        "txt", "lrc", "srt", "md", "markdown", "json", "docx", "pdf",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMediaStore" -> result.success(scanMediaStore())
                    "copyContentToCache" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri?.let { copyContentToCache(it) })
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        result.success(
                            treeUri?.let { scanTextTree(it) }
                                ?: emptyList<Map<String, Any?>>(),
                        )
                    }
                    "keepTreePermission" -> {
                        val treeUri = call.argument<String>("treeUri")
                        result.success(treeUri?.let { keepTreePermission(it) } ?: false)
                    }
                    "copyContentToCache" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri?.let { copyContentToCache(it) })
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ═══════════════════════════════════════════════════════════
    // in4up/textlib — quét thư mục (SAF tree) cho Thư viện đọc
    // ═══════════════════════════════════════════════════════════

    private fun keepTreePermission(treeUri: String): Boolean {
        return try {
            val uri = Uri.parse(treeUri)
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            true
        } catch (e: Exception) {
            // Đã có quyền / URI không persistable — không nghiêm trọng.
            e.printStackTrace()
            false
        }
    }

    private fun scanTextTree(treeUri: String): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            val rootUri = Uri.parse(treeUri)
            val rootDocId = DocumentsContract.getTreeDocumentId(rootUri)
            scanTextFolder(rootUri, rootDocId, out, 0)
        } catch (e: Exception) {
            // Trả danh sách đã có (có thể rỗng) — không crash app.
            e.printStackTrace()
        }
        return out
    }

    private fun scanTextFolder(
        treeUri: Uri,
        docId: String,
        out: MutableList<Map<String, Any?>>,
        depth: Int,
    ) {
        // Giới hạn: depth 12, 5000 file — đủ cho thư viện sách, tránh quét
        // hang trên tree khổng lồ.
        if (depth > 12 || out.size >= 5000) return
        val childUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        try {
            contentResolver.query(childUri, projection, null, null, null)?.use { c ->
                val idCol = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val sizeCol = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
                val modCol = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                val mimeCol = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)

                while (c.moveToNext() && out.size < 5000) {
                    val id = c.getString(idCol)
                    val name = c.getString(nameCol) ?: ""
                    val mime = c.getString(mimeCol) ?: ""

                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        scanTextFolder(treeUri, id, out, depth + 1)
                        continue
                    }

                    val dot = name.lastIndexOf('.')
                    val ext = if (dot >= 0 && dot < name.length - 1) {
                        name.substring(dot + 1).lowercase()
                    } else {
                        ""
                    }
                    if (!textExtensions.contains(ext)) continue

                    val docUri = ContentUris.withAppendedId(
                        DocumentsContract.buildDocumentUriUsingTree(treeUri, id),
                    )
                    out.add(
                        mapOf(
                            "uri" to docUri.toString(),
                            "name" to name,
                            "sizeBytes" to c.getLong(sizeCol),
                            "dateModifiedMs" to c.getLong(modCol),
                            "ext" to ext,
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            // Thư mục con không truy cập được — bỏ qua, tiếp tục.
            e.printStackTrace()
        }
    }

    private fun copyContentToCache(contentUri: String): String? {
        return try {
            val resolver: ContentResolver = contentResolver
            val uri = Uri.parse(contentUri)
            val input = resolver.openInputStream(uri) ?: return null

            // Tên file tạm: giữ extension nếu lấy được từ OpenableColumns.
            val name = queryDisplayName(resolver, uri) ?: "audio_${System.currentTimeMillis()}.bin"
            val outFile = File(cacheDir, "in4up_$name")
            FileOutputStream(outFile).use { output ->
                input.use { inputStream ->
                    inputStream.copyTo(output)
                }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun queryDisplayName(resolver: ContentResolver, uri: Uri): String? {
        return try {
            val cols = arrayOf(MediaStore.Audio.Media.DISPLAY_NAME)
            resolver.query(uri, cols, null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun scanMediaStore(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATE_ADDED,
            )
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                MediaStore.Audio.Media.DATE_ADDED + " DESC",
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    out.add(
                        mapOf(
                            "id" to id.toString(),
                            "uri" to "content://media/external/audio/media/$id",
                            "displayName" to (cursor.getString(nameCol) ?: ""),
                            "title" to (cursor.getString(titleCol) ?: ""),
                            "artist" to (cursor.getString(artistCol) ?: ""),
                            "durationMs" to cursor.getLong(durCol),
                            "sizeBytes" to cursor.getLong(sizeCol),
                            "dateAddedSec" to cursor.getLong(dateCol),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            // Trả danh sách đã có (có thể rỗng) — không crash app.
            e.printStackTrace()
        }
        return out
    }
}
