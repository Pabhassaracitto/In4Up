package com.in4up

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import com.in4up.screentranslate.ScreenTranslatePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

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
 *  - pickFolder(): mở SAF Picker (ACTION_OPEN_DOCUMENT_TREE) TRỰC TIẾP từ
 *    native → trả CONTENT:// tree URI THẬT + đã takePersistableUriPermission
 *    ngay trong onActivityResult. null = user hủy.
 *    ⚠️ KHÔNG dùng FilePicker.getDirectoryPath(): plugin này trả RAW FILE
 *    PATH (/storage/3033-3963/...) chứ không phải SAF URI → DocumentsContract
 *    .getTreeDocumentId throw "Invalid URI" và takePersistableUriPermission
 *    throw SecurityException → quét ra rỗng dù thư mục có file.
 *  - normalizeTreeUri(raw): chuẩn hoá về SAF tree URI — legacy raw path
 *    (/storage/emulated/0/... → primary:..., /storage/<uuid>/... → <uuid>:...)
 *    → content://com.android.externalstorage.documents/tree/<docId>.
 *    content:// sẵn → giữ nguyên. Không đổi được → null.
 *  - scanTree(treeUri): quét ĐỆ QUY một tree URI (SAF) → trả List<Map>:
 *      { uri (content URI document), name, sizeBytes, dateModifiedMs, ext }
 *    Tự normalize raw path legacy → SAF URI trước khi quét. Báo lỗi qua
 *    PlatformException: PERMISSION_LOST (mất quyền — cần chọn lại thư mục),
 *    BAD_URI (đường dẫn không hợp lệ) — KHÔNG nuốt lặng thành list rỗng
 *    (tránh UI tưởng nhầm "thư mục trống").
 *  - keepTreePermission(treeUri): giữ persistable permission (tự normalize
 *    raw path → grant thật của tree URI tương ứng mới persist được).
 *  - copyContentToCache(contentUri): giống audiolib (đọc file text/PDF).
 *
 * Runtime permission (READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE) do phía Dart
 * xử lý qua permission_handler (đã có sẵn) — native chỉ query/copy.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "in4up/audiolib"
    private val textChannelName = "in4up/textlib"
    private val dictionaryChannelName = "in4up/dictionary"

    // XLAT-SCR-002 — channel điều khiển "Dịch màn hình toàn hệ thống".
    // Service + capture + overlay nằm ở package screentranslate; activity này
    // chỉ là nơi đăng ký channel (createScreenCaptureIntent cần Activity nên
    // có activity trong suốt riêng — xem ScreenCaptureRequestActivity).
    private var screenTranslatePlugin: ScreenTranslatePlugin? = null

    // Request code riêng cho SAF folder picker (tránh đụng file_picker...).
    private val reqOpenTextTree = 0x2A11
    private val reqOpenDictionaryDocuments = 0x2A12
    private val maxDictionaryReadBytes = 64 * 1024

    // Result của MethodChannel đang chờ picker SAF (chỉ một picker modal tại
    // một thời điểm).
    private var pendingFolderPicker: MethodChannel.Result? = null
    private var pendingDictionaryDocumentsPicker: MethodChannel.Result? = null

    private data class OpenDictionaryDocument(
        val descriptor: AssetFileDescriptor,
        val startOffset: Long,
        val length: Long,
    )

    // PFD được giữ mở giữa các lệnh đọc offset; mỗi lệnh native seek/read có
    // synchronized trên handle để không làm lệch vị trí giữa các request.
    private val openDictionaryDocuments = ConcurrentHashMap<String, OpenDictionaryDocument>()

    // Định dạng đọc hỗ trợ bởi tab Thiết bị của Thư viện đọc.
    private val textExtensions = setOf(
        "txt", "lrc", "srt", "md", "markdown", "json", "docx", "pdf",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ScreenTranslatePlugin(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
            screenTranslatePlugin = it
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMediaStore" -> result.success(scanMediaStore())
                    "copyContentToCache" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri?.let { copyContentToCache(it) })
                    }
                    "readAudioDurationMs" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri?.let { readAudioDurationMs(it) })
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> launchFolderPicker(result)
                    "normalizeTreeUri" -> {
                        val treeUri = call.argument<String>("treeUri")
                        result.success(treeUri?.let { normalizeTreeUri(it) })
                    }
                    "scanTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        // Danh sách extension muốn quét (chữ thường, không kèm
                        // dấu chấm). null/rỗng → dùng bộ mặc định textExtensions
                        // (giữ tương thích với Thư viện đọc). Thư viện video
                        // truyền ["mp4","mkv",...,"srt","vtt",...] để quét cả
                        // video lẫn phụ đề trong cùng một lượt.
                        val exts = call.argument<List<String>>("extensions")
                            ?.mapNotNull { it?.toString()?.lowercase() }
                            ?.toSet()
                        if (treeUri.isNullOrBlank()) {
                            result.success(emptyList<Map<String, Any?>>())
                        } else {
                            try {
                                result.success(scanTextTree(treeUri, exts))
                            } catch (se: SecurityException) {
                                // Mất persistable permission (gỡ/cập nhật app,
                                // user thu hồi quyền) → phía Dart hiện lỗi +
                                // hướng user CHỌN LẠI thư mục.
                                result.error(
                                    "PERMISSION_LOST",
                                    "Mất quyền đọc thư mục: ${se.message}",
                                    null,
                                )
                            } catch (iae: IllegalArgumentException) {
                                result.error("BAD_URI", iae.message, null)
                            } catch (e: Exception) {
                                result.error("SCAN_FAILED", e.message, null)
                            }
                        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dictionaryChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> launchFolderPicker(result)
                    "pickDocuments" -> launchDictionaryDocumentsPicker(result)
                    "scanFolder" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val exts = call.argument<List<String>>("extensions")
                            ?.mapNotNull { it?.toString()?.lowercase() }
                            ?.toSet()
                        if (treeUri.isNullOrBlank()) {
                            result.success(emptyList<Map<String, Any?>>())
                        } else {
                            try {
                                result.success(scanTextTree(treeUri, exts))
                            } catch (se: SecurityException) {
                                result.error("PERMISSION_LOST", se.message, null)
                            } catch (iae: IllegalArgumentException) {
                                result.error("BAD_URI", iae.message, null)
                            } catch (e: Exception) {
                                result.error("SCAN_FAILED", e.message, null)
                            }
                        }
                    }
                    "isDocumentAccessible" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            Thread {
                                val accessible = isDocumentAccessible(uri)
                                runOnUiThread { result.success(accessible) }
                            }.start()
                        }
                    }
                    "openRandomAccess" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("BAD_URI", "Thiếu SAF document URI.", null)
                        } else {
                            Thread {
                                try {
                                    val opened = openDictionaryDocument(uri)
                                    runOnUiThread { result.success(opened) }
                                } catch (e: SecurityException) {
                                    runOnUiThread {
                                        result.error("PERMISSION_LOST", e.message, null)
                                    }
                                } catch (e: FileNotFoundException) {
                                    runOnUiThread {
                                        result.error("SOURCE_UNAVAILABLE", e.message, null)
                                    }
                                } catch (e: UnsupportedOperationException) {
                                    runOnUiThread {
                                        result.error("NOT_SEEKABLE", e.message, null)
                                    }
                                } catch (e: Exception) {
                                    runOnUiThread {
                                        result.error("SOURCE_UNAVAILABLE", e.message, null)
                                    }
                                }
                            }.start()
                        }
                    }
                    "readRandomAccess" -> {
                        val id = call.argument<String>("id")
                        val offset = call.argument<Number>("offset")?.toLong()
                        val count = call.argument<Number>("count")?.toInt()
                        if (id.isNullOrBlank() || offset == null || count == null) {
                            result.error("BAD_RANGE", "Thiếu tham số đọc file.", null)
                        } else {
                            Thread {
                                try {
                                    val bytes = readDictionaryRange(id, offset, count)
                                    runOnUiThread { result.success(bytes) }
                                } catch (e: SecurityException) {
                                    runOnUiThread {
                                        result.error("PERMISSION_LOST", e.message, null)
                                    }
                                } catch (e: FileNotFoundException) {
                                    runOnUiThread {
                                        result.error("SOURCE_UNAVAILABLE", e.message, null)
                                    }
                                } catch (e: UnsupportedOperationException) {
                                    runOnUiThread {
                                        result.error("NOT_SEEKABLE", e.message, null)
                                    }
                                } catch (e: Exception) {
                                    runOnUiThread {
                                        result.error("READ_FAILED", e.message, null)
                                    }
                                }
                            }.start()
                        }
                    }
                    "closeRandomAccess" -> {
                        val id = call.argument<String>("id")
                        if (id != null) closeDictionaryDocument(id)
                        result.success(null)
                    }
                    "copyDocumentToPath" -> {
                        val uri = call.argument<String>("uri")
                        val destination = call.argument<String>("destination")
                        if (uri.isNullOrBlank() || destination.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            // MDD files can be hundreds of MB. Keep the existing
                            // copy/import mode off Android's main thread.
                            Thread {
                                val copied = copyContentToPath(uri, destination)
                                runOnUiThread { result.success(copied) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ═══════════════════════════════════════════════════════════
    // in4up/textlib — SAF folder picker (ACTION_OPEN_DOCUMENT_TREE)
    // ═══════════════════════════════════════════════════════════

    private fun launchFolderPicker(result: MethodChannel.Result) {
        if (pendingFolderPicker != null || pendingDictionaryDocumentsPicker != null) {
            result.error("PICKER_BUSY", "SAF picker đang mở.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            // Cho phép truy cập cả thẻ SD/USB OTG trong DocumentsUI.
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        pendingFolderPicker = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, reqOpenTextTree)
        } catch (e: Exception) {
            pendingFolderPicker = null
            result.error("PICKER_UNAVAILABLE", e.message, null)
        }
    }

    private fun launchDictionaryDocumentsPicker(result: MethodChannel.Result) {
        if (pendingFolderPicker != null || pendingDictionaryDocumentsPicker != null) {
            result.error("PICKER_BUSY", "SAF picker đang mở.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        pendingDictionaryDocumentsPicker = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, reqOpenDictionaryDocuments)
        } catch (e: Exception) {
            pendingDictionaryDocumentsPicker = null
            result.error("PICKER_UNAVAILABLE", e.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            reqOpenTextTree -> handleFolderPickerResult(resultCode, data)
            reqOpenDictionaryDocuments -> handleDictionaryDocumentsResult(resultCode, data)
        }
    }

    private fun handleFolderPickerResult(resultCode: Int, data: Intent?) {
        val pending = pendingFolderPicker
        pendingFolderPicker = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(null)
            return
        }
        val uri = data.data
        if (uri == null) {
            pending.success(null)
            return
        }
        try {
            val readFlag = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (readFlag == 0) {
                pending.error("PERMISSION_PERSIST_FAILED", "SAF không cấp quyền đọc.", null)
                return
            }
            contentResolver.takePersistableUriPermission(uri, readFlag)
            pending.success(uri.toString())
        } catch (e: Exception) {
            pending.error("PERMISSION_PERSIST_FAILED", e.message, null)
        }
    }

    private fun handleDictionaryDocumentsResult(resultCode: Int, data: Intent?) {
        val pending = pendingDictionaryDocumentsPicker
        pendingDictionaryDocumentsPicker = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(null)
            return
        }

        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let(uris::add)
            }
        }
        if (uris.isEmpty()) data.data?.let(uris::add)
        if (uris.isEmpty()) {
            pending.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            val readFlag = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (readFlag == 0) {
                pending.error("PERMISSION_PERSIST_FAILED", "SAF không cấp quyền đọc.", null)
                return
            }
            val documents = uris.distinct().map { uri ->
                contentResolver.takePersistableUriPermission(uri, readFlag)
                val metadata = queryDocumentMetadata(uri)
                val name = metadata.first ?: uri.lastPathSegment ?: "dictionary.bin"
                val dot = name.lastIndexOf('.')
                val ext = if (dot >= 0 && dot < name.length - 1) {
                    name.substring(dot + 1).lowercase()
                } else {
                    ""
                }
                mapOf(
                    "uri" to uri.toString(),
                    "name" to name,
                    "relativePath" to name,
                    "sizeBytes" to metadata.second,
                    "ext" to ext,
                )
            }
            pending.success(documents)
        } catch (e: SecurityException) {
            pending.error("PERMISSION_PERSIST_FAILED", e.message, null)
        } catch (e: Exception) {
            pending.error("PICK_FAILED", e.message, null)
        }
    }

    private fun queryDocumentMetadata(uri: Uri): Pair<String?, Long> {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null to 0L
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                val name = if (nameIndex >= 0) cursor.getString(nameIndex) else null
                val size = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    cursor.getLong(sizeIndex)
                } else {
                    0L
                }
                name to size
            } ?: (null to 0L)
        } catch (_: Exception) {
            null to 0L
        }
    }

    // ═══════════════════════════════════════════════════════════
    // in4up/textlib — quét thư mục (SAF tree) cho Thư viện đọc
    // ═══════════════════════════════════════════════════════════

    /**
     * Chuẩn hoá về SAF tree URI (content://):
     * - content:// sẵn → giữ nguyên.
     * - Legacy raw path (/storage/... — do file_picker trả về lúc trước) →
     *   content://com.android.externalstorage.documents/tree/<docId>.
     * - file:///storage/... → xử lý như raw path.
     * - Không đổi được → null.
     */
    private fun normalizeTreeUri(raw: String): String? {
        val parsed = Uri.parse(raw)
        if (parsed.scheme == "content") return raw
        val path = (if (parsed.scheme == "file") parsed.path else raw)
            ?.trimEnd('/')
            .orEmpty()
        if (path.isEmpty()) return null
        val docId = docIdFromStoragePath(path) ?: return null
        return DocumentsContract.buildTreeDocumentUri(
            "com.android.externalstorage.documents",
            docId,
        ).toString()
    }

    /**
     * Raw storage path → SAF documentId:
     *   /storage/emulated/0/a/b, /sdcard/a/b        → "primary:a/b"
     *   /storage/emulated/<userId>/a/b              → "primary:a/b"
     *   /storage/<volume-uuid>/a/b (thẻ SD/USB OTG) → "<volume-uuid>:a/b"
     *     (vd /storage/3033-3963/2_DOI_SONG/... → "3033-3963:2_DOI_SONG/...")
     */
    private fun docIdFromStoragePath(path: String): String? {
        if (!path.startsWith("/")) return null
        // Alias của bộ nhớ trong chính.
        for (prefix in listOf(
            "/storage/emulated/0", "/sdcard", "/mnt/sdcard", "/storage/self/primary",
        )) {
            if (path == prefix) return "primary:"
            if (path.startsWith("$prefix/")) {
                return "primary:" + path.removePrefix("$prefix/")
            }
        }
        // Multi-user: /storage/emulated/<userId>/<rel>
        val emu = Regex("^/storage/emulated/\\d+(?:/(.*))?$").find(path)
        if (emu != null) return "primary:" + emu.groupValues[1]
        // Thẻ SD / USB OTG: /storage/<volume-uuid>/<rel>
        val vol = Regex("^/storage/([^/]+)(?:/(.*))?$").find(path)
        if (vol != null) return "${vol.groupValues[1]}:${vol.groupValues[2]}"
        return null
    }

    private fun keepTreePermission(treeUri: String): Boolean {
        return try {
            // Normalize TRƯỚC: raw path (/storage/...) không có grant nào →
            // SecurityException; phải persist trên SAF URI tương ứng (grant
            // từ picker — mới pick xong vẫn còn trong phiên → persist được).
            val normalized = normalizeTreeUri(treeUri) ?: treeUri
            contentResolver.takePersistableUriPermission(
                Uri.parse(normalized),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            true
        } catch (e: Exception) {
            // Không còn grant (đổi thiết bị/app reinstall từ lâu) — không
            // nghiêm trọng: scan sẽ báo PERMISSION_LOST, user chọn lại.
            e.printStackTrace()
            false
        }
    }

    private fun scanTextTree(
        treeUri: String,
        extensions: Set<String>? = null,
    ): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        // Bộ extension hiệu lực: caller truyền → dùng; không → textExtensions.
        val exts = if (extensions.isNullOrEmpty()) textExtensions else extensions
        val normalized = normalizeTreeUri(treeUri)
            ?: throw IllegalArgumentException(
                "Không phải SAF tree URI / đường dẫn hợp lệ: $treeUri",
            )
        val rootUri = Uri.parse(normalized)
        val rootDocId = try {
            DocumentsContract.getTreeDocumentId(rootUri)
        } catch (e: Exception) {
            // Tên thư mục chứa ký tự đặc biệt (vd dấu gạch chéo, dấu
            // tiếng Việt) → getTreeDocumentId có thể lỗi percent-encoding.
            // Fallback: lấy segment sau "/tree/" và DECODE an toàn
            // (giữ nguyên % lỗi thay vì throw).
            e.printStackTrace()
            val idx = normalized.lastIndexOf("/tree/")
            if (idx >= 0) safeDecodePercent(normalized.substring(idx + "/tree/".length)) else ""
        }
        if (rootDocId.isBlank()) return out
        try {
            scanTextFolder(rootUri, rootDocId, out, 0, exts, "")
        } catch (e: SecurityException) {
            // Mất quyền từ gốc (chưa quét được file nào) → ném lên để báo
            // PERMISSION_LOST. Mất quyền giữa chừng (thư mục con) → trả
            // phần đã quét được.
            if (out.isEmpty()) throw e
            e.printStackTrace()
        }
        return out
    }

    /// Decode percent-encoding AN TOÀN: giữ nguyên % lỗi (không throw).
    private fun safeDecodePercent(s: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c == '%' && i + 2 < s.length) {
                val hex = s.substring(i + 1, i + 3)
                val code = hex.toIntOrNull(16)
                if (code != null) {
                    sb.appendCodePoint(code)
                    i += 3
                    continue
                }
            }
            sb.append(c)
            i++
        }
        return sb.toString()
    }

    private fun scanTextFolder(
        treeUri: Uri,
        docId: String,
        out: MutableList<Map<String, Any?>>,
        depth: Int,
        extensions: Set<String> = textExtensions,
        relativeDir: String = "",
    ) {
        // Giới hạn: depth 12, 5000 file — đủ cho thư viện sách, tránh quét
        // hang trên tree khổng lồ.
        if (depth > 12 || out.size >= 5000) return
        val childUri = try {
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        } catch (e: Exception) {
            // docId chứa ký tự đặc biệt (vd dấu gạch chéo) → buildChild
            // DocumentsUriUsingTree có thể lỗi percent-encoding. Fallback:
            // encode docId thủ công an toàn (slash → %2F).
            e.printStackTrace()
            Uri.parse(treeUri.toString())
                .buildUpon()
                .appendPath("document")
                .appendPath(Uri.encode(docId))
                .build()
        }
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
                        scanTextFolder(
                            treeUri,
                            id,
                            out,
                            depth + 1,
                            extensions,
                            "$relativeDir$name/",
                        )
                        continue
                    }

                    val dot = name.lastIndexOf('.')
                    val ext = if (dot >= 0 && dot < name.length - 1) {
                        name.substring(dot + 1).lowercase()
                    } else {
                        ""
                    }
                    if (!extensions.contains(ext)) continue

                    val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                    out.add(
                        mapOf(
                            "uri" to docUri.toString(),
                            "name" to name,
                            "relativePath" to "$relativeDir$name",
                            "sizeBytes" to c.getLong(sizeCol),
                            "dateModifiedMs" to c.getLong(modCol),
                            "ext" to ext,
                        ),
                    )
                }
            }
        } catch (e: SecurityException) {
            // Mất quyền → KHÔNG nuốt (nuốt sẽ khiến UI tưởng nhầm "thư mục
            // trống"), ném lên scanTextTree xử lý.
            throw e
        } catch (e: Exception) {
            // Thư mục con không truy cập được (lỗi khác) — bỏ qua, tiếp tục.
            e.printStackTrace()
        }
    }

    private fun isDocumentAccessible(documentUri: String): Boolean {
        return try {
            val uri = Uri.parse(documentUri)
            if (uri.scheme != "content") return false
            contentResolver.openFileDescriptor(uri, "r")?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    /** Open and retain a seekable SAF PFD; Dart receives only an opaque id. */
    private fun openDictionaryDocument(documentUri: String): Map<String, Any> {
        val uri = Uri.parse(documentUri)
        if (uri.scheme != "content") {
            throw IllegalArgumentException("Không phải SAF document URI: $documentUri")
        }
        val descriptor = contentResolver.openAssetFileDescriptor(uri, "r")
            ?: throw FileNotFoundException("SAF document không mở được: $documentUri")
        val statSize = descriptor.parcelFileDescriptor.statSize
        val length = if (descriptor.length >= 0) {
            descriptor.length
        } else if (statSize >= descriptor.startOffset) {
            statSize - descriptor.startOffset
        } else {
            // Some document providers do not expose fstat size on the PFD but
            // do provide OpenableColumns.SIZE in their metadata cursor.
            queryDocumentMetadata(uri).second
        }
        if (length < 0) {
            descriptor.close()
            throw UnsupportedOperationException("Provider không cung cấp kích thước file.")
        }
        try {
            Os.lseek(
                descriptor.parcelFileDescriptor.fileDescriptor,
                descriptor.startOffset,
                OsConstants.SEEK_SET,
            )
        } catch (error: ErrnoException) {
            descriptor.close()
            if (error.errno == OsConstants.ESPIPE) {
                throw UnsupportedOperationException(
                    "Provider chỉ cấp stream, không hỗ trợ seek ngẫu nhiên.",
                    error,
                )
            }
            throw error
        }

        val id = UUID.randomUUID().toString()
        openDictionaryDocuments[id] = OpenDictionaryDocument(
            descriptor = descriptor,
            startOffset = descriptor.startOffset,
            length = length,
        )
        return mapOf("id" to id, "length" to length)
    }

    /** Read at most 64 KiB from a retained seekable document descriptor. */
    private fun readDictionaryRange(id: String, offset: Long, count: Int): ByteArray {
        val handle = openDictionaryDocuments[id]
            ?: throw FileNotFoundException("SAF reader handle is closed.")
        if (offset < 0 || offset > handle.length || count < 0 || count > maxDictionaryReadBytes) {
            throw IllegalArgumentException("Offset/count ngoài phạm vi hoặc vượt 64 KiB.")
        }
        val amount = minOf(count.toLong(), handle.length - offset).toInt()
        if (amount == 0) return byteArrayOf()

        synchronized(handle) {
            val fd = handle.descriptor.parcelFileDescriptor.fileDescriptor
            try {
                Os.lseek(fd, handle.startOffset + offset, OsConstants.SEEK_SET)
            } catch (error: ErrnoException) {
                if (error.errno == OsConstants.ESPIPE) {
                    throw UnsupportedOperationException(
                        "Provider không còn hỗ trợ seek ngẫu nhiên.",
                        error,
                    )
                }
                if (error.errno == OsConstants.EBADF || error.errno == OsConstants.ENOENT) {
                    throw FileNotFoundException(
                        error.message ?: "SAF source is no longer available.",
                    )
                }
                throw error
            }
            val bytes = ByteArray(amount)
            var read = 0
            while (read < amount) {
                val countRead = try {
                    Os.read(fd, bytes, read, amount - read)
                } catch (error: ErrnoException) {
                    if (error.errno == OsConstants.EBADF || error.errno == OsConstants.ENOENT) {
                        throw FileNotFoundException(
                            error.message ?: "SAF source is no longer available.",
                        )
                    }
                    throw error
                }
                if (countRead <= 0) break
                read += countRead
            }
            return if (read == amount) bytes else bytes.copyOf(read)
        }
    }

    private fun closeDictionaryDocument(id: String) {
        val handle = openDictionaryDocuments.remove(id) ?: return
        try {
            handle.descriptor.close()
        } catch (_: Exception) {
            // Best-effort close after app-side cancellation/provider removal.
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

    /**
     * Materialize one SAF document at an app-owned path.  MDX parsing needs a
     * seekable File and cannot operate on a content:// URI directly.  The
     * destination is always supplied by Dart under the app documents/cache
     * directory; a partial destination is removed on failure.
     */
    private fun copyContentToPath(contentUri: String, destination: String): Boolean {
        val outputFile = File(destination)
        return try {
            val input = contentResolver.openInputStream(Uri.parse(contentUri))
                ?: return false
            outputFile.parentFile?.mkdirs()
            FileOutputStream(outputFile).use { output ->
                input.use { inputStream ->
                    inputStream.copyTo(output)
                }
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                outputFile.delete()
            } catch (_: Exception) {
            }
            false
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

    /**
     * Thời lượng file audio (ms) — MediaMetadataRetriever, đọc được cả
     * content:// lẫn đường dẫn cục bộ.
     *
     * Dùng cho auto-TOC (Âm mục): khi waveform/ffmpeg không dùng được, app
     * vẫn chia đều mục lục theo thời lượng → không còn báo "không tạo được
     * mục lục". Lỗi / metadata trống → null (Dart tự xử lý tiếp).
     */
    private fun readAudioDurationMs(pathOrUri: String): Long? {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            if (pathOrUri.startsWith("content://") || pathOrUri.startsWith("file://")) {
                retriever.setDataSource(this, Uri.parse(pathOrUri))
            } else {
                val f = File(pathOrUri)
                if (!f.exists()) return null
                retriever.setDataSource(f.absolutePath)
            }
            val raw = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            raw?.toLongOrNull()?.takeIf { it > 0 }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {
            }
        }
    }

    override fun onDestroy() {
        screenTranslatePlugin?.detach()
        screenTranslatePlugin = null
        openDictionaryDocuments.keys.toList().forEach(::closeDictionaryDocument)
        super.onDestroy()
    }

    private fun scanMediaStore(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            // RELATIVE_PATH có từ API 29 (scoped storage) — dùng để nhóm theo
            // thư mục trong tab Nghe. Trên API cũ hơn cột không tồn tại → bọc
            // try/catch khi đọc chỉ số cột (không thêm vào projection để tránh
            // IllegalArgumentException toàn cursor).
            val hasRelPath = android.os.Build.VERSION.SDK_INT >= 29
            val projection = mutableListOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATE_ADDED,
            )
            if (hasRelPath) projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection.toTypedArray(),
                null,
                null,
                MediaStore.Audio.Media.DATE_ADDED + " DESC",
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val relCol = if (hasRelPath) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
                } else {
                    -1
                }

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val relPath = if (relCol >= 0) {
                        cursor.getString(relCol) ?: ""
                    } else {
                        ""
                    }
                    out.add(
                        mapOf(
                            "id" to id.toString(),
                            "uri" to "content://media/external/audio/media/$id",
                            "displayName" to (cursor.getString(nameCol) ?: ""),
                            "title" to (cursor.getString(titleCol) ?: ""),
                            "artist" to (cursor.getString(artistCol) ?: ""),
                            "album" to (cursor.getString(albumCol) ?: ""),
                            "durationMs" to cursor.getLong(durCol),
                            "sizeBytes" to cursor.getLong(sizeCol),
                            "dateAddedSec" to cursor.getLong(dateCol),
                            "relativePath" to relPath,
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
