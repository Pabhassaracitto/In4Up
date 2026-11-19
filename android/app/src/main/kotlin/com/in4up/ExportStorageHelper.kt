package com.in4up

import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Process
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.Locale

// PSRC-204 / ADR-0029 — Ghi tep xuat cong khai tren Android qua MediaStore.Downloads
// (API >= 29), thu muc Downloads truyen thong (API <= 28) hoac SAF DocumentTree,
// kem kiem tra quyen con song, dat ten khong ghi de "(2)" va mo thu muc chua.
// Chi phu thuoc android.jar de co the bien dich doc lap bang kotlinc.
object ExportStorageHelper {

    private const val DEFAULT_SUBFOLDER = "In4Up"
    private const val BUFFER_BYTES = 64 * 1024

    fun legacyDownloadsRoot(): String {
        @Suppress("DEPRECATION")
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        return dir?.absolutePath ?: "/storage/emulated/0/Download"
    }

    fun isTreeWritable(context: Context, treeUriString: String): Boolean {
        if (treeUriString.isBlank()) return false
        val treeUri = try {
            Uri.parse(treeUriString)
        } catch (_: Throwable) {
            return false
        }

        val cr = context.contentResolver
        val hasPersistedWrite = cr.persistedUriPermissions.any { perm ->
            perm.uri == treeUri && perm.isWritePermission
        }
        val hasSessionWrite = context.checkUriPermission(
            treeUri,
            Process.myPid(),
            Process.myUid(),
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPersistedWrite && !hasSessionWrite) {
            return false
        }

        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            cr.query(
                docUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_FLAGS,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return false
                val flagsIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_FLAGS)
                if (flagsIdx < 0 || cursor.isNull(flagsIdx)) return true
                val flags = cursor.getInt(flagsIdx)
                (flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE) != 0
            } ?: false
        } catch (_: Throwable) {
            false
        }
    }

    fun queryTreeDisplayName(context: Context, treeUri: Uri): String? {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            context.contentResolver.query(
                docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (idx >= 0 && !cursor.isNull(idx)) cursor.getString(idx) else null
                } else {
                    null
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    fun saveToDownloads(
        context: Context,
        sourceFile: File,
        desiredFileName: String,
        mimeType: String,
        subFolder: String = DEFAULT_SUBFOLDER,
    ): Map<String, Any?> {
        if (!sourceFile.exists() || !sourceFile.isFile) {
            throw IOException("Source file missing: ${sourceFile.absolutePath}")
        }
        val cleanFolder = subFolder.trim().ifEmpty { DEFAULT_SUBFOLDER }
        val cleanDesired = sanitizeFileName(desiredFileName)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToMediaStoreDownloadsQ(
                context = context,
                sourceFile = sourceFile,
                desiredFileName = cleanDesired,
                mimeType = mimeType,
                subFolder = cleanFolder,
            )
        } else {
            saveToLegacyDownloadsDir(
                context = context,
                sourceFile = sourceFile,
                desiredFileName = cleanDesired,
                mimeType = mimeType,
                subFolder = cleanFolder,
            )
        }
    }

    private fun saveToMediaStoreDownloadsQ(
        context: Context,
        sourceFile: File,
        desiredFileName: String,
        mimeType: String,
        subFolder: String,
    ): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return saveToLegacyDownloadsDir(context, sourceFile, desiredFileName, mimeType, subFolder)
        }
        val cr = context.contentResolver
        val relativeWithSlash = "${Environment.DIRECTORY_DOWNLOADS}/$subFolder/"
        val relativeNoSlash = "${Environment.DIRECTORY_DOWNLOADS}/$subFolder"

        val existingLower = HashSet<String>()
        try {
            cr.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ? OR ${MediaStore.MediaColumns.RELATIVE_PATH} = ?",
                arrayOf(relativeWithSlash, relativeNoSlash),
                null,
            )?.use { cursor ->
                val idx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    if (idx >= 0 && !cursor.isNull(idx)) {
                        existingLower.add(cursor.getString(idx).lowercase(Locale.ROOT))
                    }
                }
            }
        } catch (_: Throwable) {
            // Neu ROM chan query thi MediaStore van tu tranh ghi de khi insert.
        }

        @Suppress("DEPRECATION")
        val publicDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            subFolder,
        )
        val uniqueName = uniqueDisplayName(desiredFileName) { candidate ->
            existingLower.contains(candidate.lowercase(Locale.ROOT)) ||
                File(publicDir, candidate).exists()
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType.ifBlank { "application/octet-stream" })
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativeWithSlash)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val itemUri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("MediaStore.Downloads insert returned null")

        var published = false
        try {
            val pfd = cr.openFileDescriptor(itemUri, "w")
                ?: throw IOException("Cannot open file descriptor for $itemUri")
            pfd.use { descriptor ->
                FileInputStream(sourceFile).use { input ->
                    FileOutputStream(descriptor.fileDescriptor).use { output ->
                        copyStream(input, output)
                        output.flush()
                        descriptor.fileDescriptor.sync()
                    }
                }
            }

            val publishValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            cr.update(itemUri, publishValues, null, null)
            published = true
        } finally {
            if (!published) {
                try {
                    cr.delete(itemUri, null, null)
                } catch (_: Throwable) {
                }
            }
        }

        val actualName = queryMediaDisplayName(cr, itemUri) ?: uniqueName
        val candidateFile = File(publicDir, actualName)
        val readableLocalPath = if (candidateFile.exists() && candidateFile.canRead()) {
            candidateFile.absolutePath
        } else {
            null
        }

        return mapOf(
            "uri" to itemUri.toString(),
            "fileName" to actualName,
            "displayPath" to "Download/$subFolder/$actualName",
            "localPath" to readableLocalPath,
        )
    }

    private fun saveToLegacyDownloadsDir(
        context: Context,
        sourceFile: File,
        desiredFileName: String,
        mimeType: String,
        subFolder: String,
    ): Map<String, Any?> {
        @Suppress("DEPRECATION")
        val downloadsRoot = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        ) ?: throw IOException("Downloads directory unavailable")
        val targetDir = File(downloadsRoot, subFolder)
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw IOException("Cannot create directory ${targetDir.absolutePath}")
        }

        val uniqueName = uniqueDisplayName(desiredFileName) { candidate ->
            File(targetDir, candidate).exists()
        }
        val finalFile = File(targetDir, uniqueName)
        val partFile = File(targetDir, "$uniqueName.part")

        var completed = false
        try {
            if (partFile.exists()) {
                partFile.delete()
            }
            FileInputStream(sourceFile).use { input ->
                FileOutputStream(partFile).use { output ->
                    copyStream(input, output)
                    output.flush()
                    output.fd.sync()
                }
            }
            if (!partFile.renameTo(finalFile)) {
                throw IOException("Atomic rename failed for ${finalFile.absolutePath}")
            }
            completed = true
        } finally {
            if (!completed && partFile.exists()) {
                try {
                    partFile.delete()
                } catch (_: Throwable) {
                }
            }
        }

        try {
            MediaScannerConnection.scanFile(
                context,
                arrayOf(finalFile.absolutePath),
                arrayOf(mimeType),
                null,
            )
        } catch (_: Throwable) {
        }

        return mapOf(
            "uri" to Uri.fromFile(finalFile).toString(),
            "fileName" to uniqueName,
            "displayPath" to "Download/$subFolder/$uniqueName",
            "localPath" to finalFile.absolutePath,
        )
    }

    fun saveToSafTree(
        context: Context,
        sourceFile: File,
        treeUriString: String,
        desiredFileName: String,
        mimeType: String,
    ): Map<String, Any?> {
        if (!sourceFile.exists() || !sourceFile.isFile) {
            throw IOException("Source file missing: ${sourceFile.absolutePath}")
        }
        val treeUri = Uri.parse(treeUriString)
        val cr = context.contentResolver
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocId)

        val existingLower = HashSet<String>()
        try {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
            cr.query(
                childrenUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                val idx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    if (idx >= 0 && !cursor.isNull(idx)) {
                        existingLower.add(cursor.getString(idx).lowercase(Locale.ROOT))
                    }
                }
            }
        } catch (_: Throwable) {
        }

        val cleanDesired = sanitizeFileName(desiredFileName)
        val uniqueName = uniqueDisplayName(cleanDesired) { candidate ->
            existingLower.contains(candidate.lowercase(Locale.ROOT))
        }
        val createMime = safeCreateDocumentMime(uniqueName, mimeType)

        val createdUri = DocumentsContract.createDocument(
            cr,
            parentDocUri,
            createMime,
            uniqueName,
        ) ?: throw IOException("DocumentsContract.createDocument returned null for $treeUri")

        var completed = false
        try {
            val pfd = cr.openFileDescriptor(createdUri, "w")
                ?: throw IOException("Cannot open SAF descriptor for $createdUri")
            pfd.use { descriptor ->
                FileInputStream(sourceFile).use { input ->
                    FileOutputStream(descriptor.fileDescriptor).use { output ->
                        copyStream(input, output)
                        output.flush()
                        descriptor.fileDescriptor.sync()
                    }
                }
            }
            completed = true
        } finally {
            if (!completed) {
                try {
                    DocumentsContract.deleteDocument(cr, createdUri)
                } catch (_: Throwable) {
                }
            }
        }

        val actualName = querySafDisplayName(cr, createdUri) ?: uniqueName
        val folderLabel = formatTreeLabel(treeUri, queryTreeDisplayName(context, treeUri))

        return mapOf(
            "uri" to createdUri.toString(),
            "fileName" to actualName,
            "displayPath" to "$folderLabel/$actualName",
            "localPath" to null,
        )
    }

    fun openExportFolder(
        activity: Activity,
        kind: String,
        location: String,
        fileUri: String?,
    ): Boolean {
        val candidates = ArrayList<Intent>()

        if (kind == "androidSafTree" && location.isNotBlank()) {
            try {
                val treeUri = Uri.parse(location)
                val docId = DocumentsContract.getTreeDocumentId(treeUri)
                val dirUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                candidates.add(
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(dirUri, DocumentsContract.Document.MIME_TYPE_DIR)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    },
                )
            } catch (_: Throwable) {
            }
        } else {
            val docAuthority = "com.android.externalstorage.documents"
            for (docId in listOf("primary:Download/$DEFAULT_SUBFOLDER", "primary:Download")) {
                try {
                    val dirUri = DocumentsContract.buildDocumentUri(docAuthority, docId)
                    candidates.add(
                        Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(dirUri, DocumentsContract.Document.MIME_TYPE_DIR)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        },
                    )
                } catch (_: Throwable) {
                }
            }
        }

        candidates.add(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS))

        if (!fileUri.isNullOrBlank()) {
            try {
                val parsed = Uri.parse(fileUri)
                candidates.add(
                    Intent(Intent.ACTION_VIEW).apply {
                        data = parsed
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    },
                )
            } catch (_: Throwable) {
            }
        }

        for (intent in candidates) {
            try {
                activity.startActivity(intent)
                return true
            } catch (_: Throwable) {
            }
        }
        return false
    }

    private fun safeCreateDocumentMime(fileName: String, requestedMime: String): String {
        val dot = fileName.lastIndexOf('.')
        if (dot <= 0 || dot >= fileName.length - 1) {
            return requestedMime.ifBlank { "application/octet-stream" }
        }
        val ext = fileName.substring(dot + 1).lowercase(Locale.ROOT)
        val mappedExt = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(requestedMime)
            ?.lowercase(Locale.ROOT)
        if (mappedExt == ext) {
            return requestedMime
        }
        val mimeFromExt = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        if (mimeFromExt != null &&
            MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeFromExt)?.lowercase(Locale.ROOT) == ext
        ) {
            return mimeFromExt
        }
        // Voi duoi nhu .lrc, .opus, .md: dung octet-stream de ExternalStorageProvider
        // giu nguyen ten file ma khong tu noi them .txt hay .ogg.
        return "application/octet-stream"
    }

    private fun queryMediaDisplayName(
        cr: android.content.ContentResolver,
        uri: Uri,
    ): String? {
        return try {
            cr.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (idx >= 0 && !c.isNull(idx)) c.getString(idx) else null
                } else {
                    null
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun querySafDisplayName(
        cr: android.content.ContentResolver,
        uri: Uri,
    ): String? {
        return try {
            cr.query(
                uri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (idx >= 0 && !c.isNull(idx)) c.getString(idx) else null
                } else {
                    null
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun formatTreeLabel(treeUri: Uri, fallbackName: String?): String {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            when {
                docId.startsWith("primary:") -> {
                    val rel = docId.removePrefix("primary:").trim()
                    if (rel.isEmpty()) "Bộ nhớ trong" else rel
                }
                docId.startsWith("home:") -> {
                    val rel = docId.removePrefix("home:").trim()
                    if (rel.isEmpty()) "Documents" else "Documents/$rel"
                }
                docId.contains(':') -> {
                    val idx = docId.indexOf(':')
                    val vol = docId.substring(0, idx)
                    val rel = docId.substring(idx + 1).trim()
                    if (rel.isEmpty()) vol else "$vol/$rel"
                }
                else -> fallbackName?.takeIf { it.isNotBlank() } ?: docId
            }
        } catch (_: Throwable) {
            fallbackName?.takeIf { it.isNotBlank() } ?: treeUri.toString()
        }
    }

    private fun sanitizeFileName(raw: String): String {
        var cleaned = raw.replace(Regex("[\\x00-\\x1F<>:\"/\\\\|?*]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
            .trimEnd('.', ' ')
        if (cleaned.isEmpty() || cleaned == ".") {
            cleaned = "in4up_export"
        }
        return cleaned
    }

    private fun uniqueDisplayName(
        desired: String,
        exists: (String) -> Boolean,
    ): String {
        if (!exists(desired)) return desired
        val dot = desired.lastIndexOf('.')
        val hasExt = dot > 0 && dot < desired.length - 1
        val stem = if (hasExt) desired.substring(0, dot) else desired
        val ext = if (hasExt) desired.substring(dot) else ""
        for (i in 2 until 10000) {
            val candidate = "$stem ($i)$ext"
            if (!exists(candidate)) return candidate
        }
        return "${stem}_${System.currentTimeMillis()}$ext"
    }

    private fun copyStream(input: FileInputStream, output: FileOutputStream) {
        val buf = ByteArray(BUFFER_BYTES)
        while (true) {
            val read = input.read(buf)
            if (read <= 0) break
            output.write(buf, 0, read)
        }
    }
}
