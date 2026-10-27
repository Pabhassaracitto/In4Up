package com.in4up

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.security.MessageDigest

/**
 * Materializes one content URI at a time without using a display name as its
 * identity. Existing in4up_<name> files and their path-keyed user data are never
 * overwritten on an unverified match. Legacy ownership can only be explicitly
 * claimed by the user, and only if the old file is absent or byte-identical.
 */
internal class AudioContentCacheResolver(private val context: Context) {
    companion object {
        // Activities can overlap during rotation; serialize across instances.
        private val lock = Any()
    }

    private val preferences = context.getSharedPreferences(
        "in4up_audio_cache_owners_v1", Context.MODE_PRIVATE
    )

    fun resolve(contentUri: String, claimLegacy: Boolean = false): Map<String, Any?>? =
        synchronized(lock) {
            var temporary: File? = null
            try {
                val uri = Uri.parse(contentUri)
                if (uri.scheme != "content") return@synchronized null
                val sourceKey = sha256(contentUri.toByteArray(Charsets.UTF_8))
                val name = (try { displayName(uri) } catch (_: Exception) { null })?.replace(Regex("[/\\\\\\x00-\\x1f]"), "_")
                    ?.takeIf { it.isNotBlank() }
                val extension = name?.substringAfterLast('.', "")
                    ?.lowercase()?.takeIf { it.matches(Regex("[a-z0-9]{1,8}")) }
                val suffix = if (extension == null) ".bin" else ".$extension"
                val unique = File(context.cacheDir, "in4up_audio_${sourceKey.take(40)}$suffix")
                // If the display name is unknown there is no reliable legacy
                // path to offer; never guess a historical timestamped filename.
                val legacy = name?.let { File(context.cacheDir, "in4up_$it") }
                val ownerKey = legacy?.let {
                    "owner_" + sha256(it.absolutePath.toByteArray(Charsets.UTF_8))
                }
                val owner = ownerKey?.let { preferences.getString(it, null) }

                val staging = File.createTempFile("in4up_audio_", ".partial", context.cacheDir)
                temporary = staging
                val input = context.contentResolver.openInputStream(uri) ?: return@synchronized null
                input.use { source -> staging.outputStream().use { target -> source.copyTo(target) } }

                val legacyExists = legacy?.isFile == true
                val sameBytes = legacyExists && filesEqual(staging, legacy!!)
                val ownedBySource = owner != null && owner == sourceKey
                val canClaim = legacy != null && (owner == null || ownedBySource) &&
                    (!legacyExists || sameBytes)

                if (claimLegacy && !canClaim) {
                    return@synchronized mapOf(
                        "status" to "legacy_conflict",
                        "legacyPath" to legacy?.absolutePath,
                    )
                }

                // A previously associated URI may later resolve to different
                // bytes. Never replace an existing legacy file in that case;
                // keep its path-keyed data and open the URI-keyed copy instead.
                val useLegacy = claimLegacy || (ownedBySource && (!legacyExists || sameBytes))
                val destination = if (useLegacy) legacy!! else unique
                if (useLegacy && legacyExists && sameBytes) {
                    staging.delete()
                } else if (!staging.renameTo(destination)) {
                    throw IOException("Could not atomically materialize audio cache")
                }
                temporary = null

                if (claimLegacy && ownerKey != null &&
                    !preferences.edit().putString(ownerKey, sourceKey).commit()) {
                    throw IOException("Could not persist audio cache ownership")
                }

                mapOf(
                    "status" to "ok",
                    "path" to destination.absolutePath,
                    "legacyPath" to legacy?.absolutePath,
                    "legacyExists" to legacyExists,
                    "legacyMatches" to sameBytes,
                    "legacyClaimable" to (canClaim && !useLegacy),
                    "legacyOwned" to useLegacy,
                )
            } catch (error: Exception) {
                android.util.Log.w("In4UpAudioCache", "Could not resolve audio source", error)
                null
            } finally {
                temporary?.delete()
            }
        }

    private fun displayName(uri: Uri): String? {
        return context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) null
                else cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
            }
    }

    private fun filesEqual(first: File, second: File): Boolean {
        if (first.length() != second.length()) return false
        return digestFile(first).contentEquals(digestFile(second))
    }

    private fun digestFile(file: File): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest()
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
}
