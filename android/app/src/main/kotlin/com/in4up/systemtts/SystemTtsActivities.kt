package com.in4up.systemtts

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import com.in4up.MainActivity

/**
 * PSRC-221 — ba activity mà màn "Chuyển văn bản thành giọng nói" của Android
 * gọi vào engine đang chọn. Không có giao diện, không có chuỗi hiển thị.
 *
 * Vì sao BẮT BUỘC có `CHECK_TTS_DATA`: Cài đặt Android chỉ bật nút "Nghe thử"
 * và danh sách ngôn ngữ sau khi engine trả danh sách giọng qua activity này.
 * Thiếu nó, in4up vẫn hiện trong danh sách engine nhưng không nghe thử được.
 */
class CheckVoiceDataActivity : Activity() {

    companion object {
        /** Engine nền khởi động nguội cần ~1 giây; chờ tối đa chừng này. */
        private const val WAIT_MS = 6_000L
    }

    private var answered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SystemTtsRuntime.acquire(this)
        SystemTtsRuntime.whenVoicesReported(WAIT_MS) { catalog -> answer(catalog) }
    }

    private fun answer(catalog: SystemTtsVoiceCatalog) {
        if (answered || isFinishing) return
        answered = true
        val available = ArrayList<String>()
        for (voice in catalog.voices) {
            val name = voice.checkDataName()
            if (name.isNotEmpty() && !available.contains(name)) available.add(name)
        }
        val data = Intent()
        data.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, available)
        data.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_UNAVAILABLE_VOICES, ArrayList())
        setResult(
            if (available.isEmpty()) {
                TextToSpeech.Engine.CHECK_VOICE_DATA_FAIL
            } else {
                TextToSpeech.Engine.CHECK_VOICE_DATA_PASS
            },
            data,
        )
        finish()
    }

    override fun onDestroy() {
        answered = true
        SystemTtsRuntime.release()
        super.onDestroy()
    }
}

/**
 * `GET_SAMPLE_TEXT` — câu mà Cài đặt Android đọc khi bấm "Nghe thử".
 *
 * Đây là NỘI DUNG để đọc bằng giọng của ngôn ngữ đó, không phải chrome UI.
 * Ngôn ngữ chưa có câu mẫu ⇒ trả LANG_NOT_SUPPORTED để Cài đặt dùng câu mặc
 * định của hệ thống (tốt hơn đọc câu tiếng Anh bằng giọng ngôn ngữ khác).
 */
class GetSampleTextActivity : Activity() {

    companion object {
        private val SAMPLES = mapOf(
            "en" to "This is an example of speech synthesis from In4Up.",
            "vi" to "Đây là ví dụ về giọng đọc của In4Up.",
            "de" to "Dies ist ein Beispiel für die Sprachausgabe von In4Up.",
            "fr" to "Voici un exemple de synthèse vocale d'In4Up.",
            "es" to "Este es un ejemplo de síntesis de voz de In4Up.",
            "zh" to "这是 In4Up 语音合成的示例。",
            "ja" to "これは In4Up の音声合成の例です。",
            "hi" to "यह In4Up की वाक् संश्लेषण का एक उदाहरण है।",
        )

        // Android gửi mã ISO-639-2 ba chữ; bảng trên dùng mã hai chữ.
        private val ISO3_TO_ISO2 = mapOf(
            "eng" to "en",
            "vie" to "vi",
            "deu" to "de",
            "ger" to "de",
            "fra" to "fr",
            "fre" to "fr",
            "spa" to "es",
            "zho" to "zh",
            "chi" to "zh",
            "jpn" to "ja",
            "hin" to "hi",
        )

        fun sampleFor(language: String?): String? {
            val code = language?.trim()?.lowercase().orEmpty()
            if (code.isEmpty()) return null
            return SAMPLES[ISO3_TO_ISO2[code] ?: code]
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val sample = sampleFor(intent?.getStringExtra("language"))
        if (sample == null) {
            setResult(TextToSpeech.LANG_NOT_SUPPORTED, Intent())
        } else {
            val data = Intent()
            data.putExtra(TextToSpeech.Engine.EXTRA_SAMPLE_TEXT, sample)
            setResult(TextToSpeech.LANG_AVAILABLE, data)
        }
        finish()
    }
}

/**
 * `INSTALL_TTS_DATA` — "Cài đặt dữ liệu giọng nói" trong Cài đặt Android.
 * Giọng của in4up được import TRONG app, nên chỉ việc mở app.
 */
class InstallVoiceDataActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            // Không mở được app thì cũng không được làm sập Cài đặt.
        }
        finish()
    }
}
