package com.in4up.systemtts

import android.speech.tts.TextToSpeech
import java.util.Locale
import java.util.MissingResourceException
import org.json.JSONArray
import org.json.JSONObject

/**
 * PSRC-221 — một giọng mà worker Dart báo lên.
 *
 * [name] là tên duy nhất (`piper/vi_VN-vais1000-medium`), [tag] là BCP-47
 * (`vi-VN`). Android hỏi engine bằng mã ISO-639-2/ISO-3166 ba chữ
 * (`vie` / `VNM`) nên mã ba chữ được tính sẵn một lần ở đây.
 */
class SystemTtsVoiceInfo(val name: String, val tag: String) {
    val locale: Locale = Locale.forLanguageTag(tag)

    val iso3Language: String = try {
        locale.isO3Language
    } catch (e: MissingResourceException) {
        locale.language
    }

    val iso3Country: String = try {
        locale.isO3Country
    } catch (e: MissingResourceException) {
        locale.country
    }

    fun matchesLanguage(lang: String?): Boolean {
        if (lang.isNullOrBlank()) return false
        return lang.equals(iso3Language, ignoreCase = true) ||
            lang.equals(locale.language, ignoreCase = true)
    }

    fun matchesCountry(country: String?): Boolean {
        if (country.isNullOrBlank()) return false
        return country.equals(iso3Country, ignoreCase = true) ||
            country.equals(locale.country, ignoreCase = true)
    }

    /** Dạng `vie-VNM` mà `ACTION_CHECK_TTS_DATA` phải trả. */
    fun checkDataName(): String =
        if (iso3Country.isEmpty()) iso3Language else "$iso3Language-$iso3Country"
}

/**
 * Danh mục giọng bất biến. Thứ tự do Dart quyết định: giọng đứng trước là
 * giọng mặc định của ngôn ngữ đó.
 */
class SystemTtsVoiceCatalog(val voices: List<SystemTtsVoiceInfo>) {

    fun isEmpty(): Boolean = voices.isEmpty()

    fun byName(name: String?): SystemTtsVoiceInfo? {
        if (name.isNullOrEmpty()) return null
        return voices.firstOrNull { it.name == name }
    }

    /** Giá trị trả cho `onIsLanguageAvailable` / `onLoadLanguage`. */
    fun availability(lang: String?, country: String?): Int {
        var best = TextToSpeech.LANG_NOT_SUPPORTED
        for (voice in voices) {
            if (!voice.matchesLanguage(lang)) continue
            if (voice.matchesCountry(country)) return TextToSpeech.LANG_COUNTRY_AVAILABLE
            best = TextToSpeech.LANG_AVAILABLE
        }
        return best
    }

    /** Giọng cho một ngôn ngữ: đúng cả vùng trước, rồi tới cùng ngôn ngữ. */
    fun pick(lang: String?, country: String?): SystemTtsVoiceInfo? =
        voices.firstOrNull { it.matchesLanguage(lang) && it.matchesCountry(country) }
            ?: voices.firstOrNull { it.matchesLanguage(lang) }

    fun toJson(): String {
        val array = JSONArray()
        for (voice in voices) {
            array.put(JSONObject().put(KEY_NAME, voice.name).put(KEY_LOCALE, voice.tag))
        }
        return array.toString()
    }

    companion object {
        // Khoá payload — khớp `SystemTtsProtocol` (Dart).
        const val KEY_NAME = "name"
        const val KEY_LOCALE = "locale"

        val EMPTY = SystemTtsVoiceCatalog(emptyList())

        /** Từ payload MethodChannel (`List<Map>`). Phần tử hỏng bị bỏ qua. */
        fun fromChannel(raw: Any?): SystemTtsVoiceCatalog {
            val list = raw as? List<*> ?: return EMPTY
            val out = ArrayList<SystemTtsVoiceInfo>()
            for (item in list) {
                val map = item as? Map<*, *> ?: continue
                add(out, map[KEY_NAME] as? String, map[KEY_LOCALE] as? String)
            }
            return SystemTtsVoiceCatalog(out)
        }

        fun fromJson(json: String?): SystemTtsVoiceCatalog {
            if (json.isNullOrEmpty()) return EMPTY
            return try {
                val array = JSONArray(json)
                val out = ArrayList<SystemTtsVoiceInfo>()
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    add(out, obj.optString(KEY_NAME), obj.optString(KEY_LOCALE))
                }
                SystemTtsVoiceCatalog(out)
            } catch (e: Exception) {
                EMPTY
            }
        }

        private fun add(out: MutableList<SystemTtsVoiceInfo>, name: String?, tag: String?) {
            if (name.isNullOrEmpty() || tag.isNullOrEmpty()) return
            val info = try {
                SystemTtsVoiceInfo(name, tag)
            } catch (e: Exception) {
                return
            }
            if (info.locale.language.isEmpty()) return
            out.add(info)
        }
    }
}
