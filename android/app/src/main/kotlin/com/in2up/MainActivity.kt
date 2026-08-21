package com.in4up

import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — đăng ký MethodChannel "in4up/audiolib" cho Thư viện âm thanh (P1).
 *
 * Phương thức:
 *  - scanMediaStore(): quét MediaStore.Audio (Android) → trả List<Map>:
 *      { id, uri (content://media/external/audio/media/<id>), title, displayName,
 *        artist, durationMs, sizeBytes, dateAddedSec }
 *    Dùng content URI (không dùng DATA — bị chặn trên scoped storage API 29+);
 *    ExoPlayer/just_audio phát được content://.
 *
 * Runtime permission (READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE) do phía Dart
 * xử lý qua permission_handler (đã có sẵn trong dự án) — native chỉ query.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "in4up/audiolib"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMediaStore" -> result.success(scanMediaStore())
                    else -> result.notImplemented()
                }
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
