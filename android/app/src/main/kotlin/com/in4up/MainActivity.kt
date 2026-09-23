package com.in4up

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.media.MediaMetadataRetriever
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
 * "in4up/videolib" (Thư viện video — quét video trên máy, giống audiolib):
 *  - scanMediaStore(): quét MediaStore.Video (Android) → trả List<Map>:
 *      { id, uri (content://media/external/video/media/<id>), title,
 *        displayName, durationMs, sizeBytes, dateAddedSec, width, height }
 *    Dùng content URI (DATA bị chặn trên scoped storage API 29+).
 *    width/height có thể = 0 trên một số thiết bị (cột deprecated).
 *  - copyContentToCache(contentUri): copy content:// sang cache dir → path
 *    (video_player/ExoPlayer cần File path ổn định).
 *
 * Runtime permission (READ_MEDIA_AUDIO / READ_MEDIA_VIDEO / READ_EXTERNAL_STORAGE)
 * do phía Dart xử lý qua permission_handler (đã có sẵn) — native chỉ query/copy.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "in4up/audiolib"
    private val videoChannelName = "in4up/videolib"
    private val textChannelName = "in4up/textlib"

    // Request code riêng cho SAF folder picker (tránh đụng file_picker...).
    private val reqOpenTextTree = 0x2A11

    // Result của MethodChannel đang chờ user chọn thư mục (1 picker tại 1
    // thời điểm — SAF Picker là modal hệ thống).
    private var pendingFolderPicker: MethodChannel.Result? = null

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
                    "readAudioDurationMs" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri?.let { readAudioDurationMs(it) })
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, videoChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMediaStore" -> result.success(scanVideoMediaStore())
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
                    "pickFolder" -> launchFolderPicker(result)
                    "normalizeTreeUri" -> {
                        val treeUri = call.argument<String>("treeUri")
                        result.success(treeUri?.let { normalizeTreeUri(it) })
                    }
                    "scanTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri.isNullOrBlank()) {
                            result.success(emptyList<Map<String, Any?>>())
                        } else {
                            try {
                                result.success(scanTextTree(treeUri))
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
    }

    // ═══════════════════════════════════════════════════════════
    // in4up/textlib — SAF folder picker (ACTION_OPEN_DOCUMENT_TREE)
    // ═══════════════════════════════════════════════════════════

    private fun launchFolderPicker(result: MethodChannel.Result) {
        if (pendingFolderPicker != null) {
            result.error("PICKER_BUSY", "Folder picker đang mở.", null)
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

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqOpenTextTree) return
        val pending = pendingFolderPicker
        pendingFolderPicker = null
        if (pending == null) return
        val uri = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null) {
            // Persist quyền đọc NGAY TẠI ĐÂY (grant từ SAF Picker chỉ tồn
            // tại trong phiên nếu không persist) → lần mở app sau vẫn quét
            // được, không cần chọn lại thư mục.
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
            pending.success(uri.toString())
        } else {
            pending.success(null) // user hủy
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

    private fun scanTextTree(treeUri: String): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
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
            scanTextFolder(rootUri, rootDocId, out, 0)
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

                    val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
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
        } catch (e: SecurityException) {
            // Mất quyền → KHÔNG nuốt (nuốt sẽ khiến UI tưởng nhầm "thư mục
            // trống"), ném lên scanTextTree xử lý.
            throw e
        } catch (e: Exception) {
            // Thư mục con không truy cập được (lỗi khác) — bỏ qua, tiếp tục.
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

    // ═══════════════════════════════════════════════════════════
    // in4up/videolib — quét MediaStore.Video cho Thư viện video
    // ═══════════════════════════════════════════════════════════

    private fun scanVideoMediaStore(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            val projection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.TITLE,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.DATE_ADDED,
                @Suppress("DEPRECATION") MediaStore.Video.Media.WIDTH,
                @Suppress("DEPRECATION") MediaStore.Video.Media.HEIGHT,
            )
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                MediaStore.Video.Media.DATE_ADDED + " DESC",
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val nameCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
                val durCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                val dateCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
                // Cột WIDTH/HEIGHT deprecated: trên một số thiết bị không có
                // ⇒ lấy index âm thì trả 0 thay vì crash.
                val widthCol =
                    cursor.getColumnIndex(@Suppress("DEPRECATION") MediaStore.Video.Media.WIDTH)
                val heightCol =
                    cursor.getColumnIndex(@Suppress("DEPRECATION") MediaStore.Video.Media.HEIGHT)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val duration = cursor.getLong(durCol)
                    // Bỏ file 0 byte / không có thời lượng (file rác trong DCIM).
                    if (duration <= 0L && cursor.getLong(sizeCol) <= 0L) continue
                    out.add(
                        mapOf(
                            "id" to id.toString(),
                            "uri" to "content://media/external/video/media/$id",
                            "displayName" to (cursor.getString(nameCol) ?: ""),
                            "title" to (cursor.getString(titleCol) ?: ""),
                            "durationMs" to duration,
                            "sizeBytes" to cursor.getLong(sizeCol),
                            "dateAddedSec" to cursor.getLong(dateCol),
                            "width" to if (widthCol >= 0) cursor.getInt(widthCol) else 0,
                            "height" to if (heightCol >= 0) cursor.getInt(heightCol) else 0,
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
