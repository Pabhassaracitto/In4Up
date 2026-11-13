package com.in4up.systemtts

import android.media.AudioFormat
import android.os.Looper
import android.speech.tts.SynthesisCallback
import android.speech.tts.SynthesisRequest
import android.speech.tts.TextToSpeech
import android.speech.tts.TextToSpeechService
import android.speech.tts.Voice
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * PSRC-221 — in4up là một engine "Chuyển văn bản thành giọng nói" của Android.
 *
 * Android tìm engine bằng intent `android.intent.action.TTS_SERVICE`
 * (AndroidManifest) + metadata `android.speech.tts` (res/xml/tts_engine.xml).
 * Khi người dùng chọn In4Up trong Cài đặt, hoặc một app khác gọi
 * `TextToSpeech(context, listener, "com.in4up")`, hệ thống bind service này.
 *
 * Âm thanh do các engine OFFLINE sẵn có của app tạo (Piper, VieNeu) trong một
 * engine Flutter nền — xem [SystemTtsRuntime]. Service này chỉ:
 *  - trả lời Android "có đọc được ngôn ngữ X không / có những giọng nào"
 *    từ danh mục do Dart báo ([SystemTtsVoiceCatalog]);
 *  - chuyển một yêu cầu đọc sang Dart rồi ghi PCM nhận về cho Android.
 *
 * Chưa có giọng offline nào trên máy ⇒ mọi ngôn ngữ trả LANG_NOT_SUPPORTED
 * (đúng sự thật) — người dùng cần import giọng Piper trong app trước.
 */
class In4UpTtsService : TextToSpeechService() {

    companion object {
        private const val TAG = "In4UpSystemTts"

        /** Chờ engine nền báo danh mục giọng lần đầu (không ở luồng chính). */
        private const val CATALOG_WAIT_MS = 4_000L

        /** Chờ worker Dart sẵn sàng trước khi đọc (engine nền khởi động nguội). */
        private const val READY_WAIT_MS = 20_000L

        /**
         * Chờ MỘT sự kiện (khối âm thanh kế tiếp hoặc kết thúc). Lần đầu gồm
         * cả thời gian nạp model (Piper vài giây, VieNeu ~170 MB lâu hơn).
         */
        private const val EVENT_WAIT_SECONDS = 180L

        /** Tần số khai với Android khi câu không có gì để đọc. */
        private const val SILENT_SAMPLE_RATE = 16_000
    }

    @Volatile
    private var currentLanguage = arrayOf("eng", "USA", "")

    override fun onCreate() {
        // TRƯỚC super.onCreate(): lớp cha gọi onLoadLanguage ngay trong đó.
        SystemTtsRuntime.acquire(this)
        super.onCreate()
    }

    override fun onDestroy() {
        super.onDestroy()
        SystemTtsRuntime.release()
    }

    private fun catalog(): SystemTtsVoiceCatalog = SystemTtsRuntime.catalog(CATALOG_WAIT_MS)

    // ───────────────────────── ngôn ngữ & giọng ───────────────────────

    override fun onIsLanguageAvailable(lang: String?, country: String?, variant: String?): Int =
        catalog().availability(lang, country)

    override fun onGetLanguage(): Array<String> = currentLanguage

    override fun onLoadLanguage(lang: String?, country: String?, variant: String?): Int {
        val result = catalog().availability(lang, country)
        if (result >= TextToSpeech.LANG_AVAILABLE && lang != null) {
            currentLanguage = arrayOf(
                lang,
                if (result >= TextToSpeech.LANG_COUNTRY_AVAILABLE) country.orEmpty() else "",
                "",
            )
        }
        // Người dùng có thể vừa import giọng mới trong app.
        SystemTtsRuntime.refreshVoicesAsync()
        return result
    }

    override fun onGetVoices(): List<Voice> {
        SystemTtsRuntime.refreshVoicesAsync()
        return catalog().voices.map { info ->
            Voice(
                info.name,
                info.locale,
                Voice.QUALITY_NORMAL,
                Voice.LATENCY_NORMAL,
                false, // offline — phiếu L8: chưa đăng ký giọng cần mạng
                HashSet<String>(),
            )
        }
    }

    override fun onIsValidVoiceName(voiceName: String?): Int =
        if (catalog().byName(voiceName) != null) TextToSpeech.SUCCESS else TextToSpeech.ERROR

    override fun onLoadVoice(voiceName: String?): Int {
        val voice = catalog().byName(voiceName) ?: return TextToSpeech.ERROR
        currentLanguage = arrayOf(voice.iso3Language, voice.iso3Country, "")
        return TextToSpeech.SUCCESS
    }

    override fun onGetDefaultVoiceNameFor(
        lang: String?,
        country: String?,
        variant: String?,
    ): String? = catalog().pick(lang, country)?.name

    // ───────────────────────── đọc ─────────────────────────────────────

    override fun onStop() {
        SystemTtsRuntime.stopCurrent()
    }

    override fun onSynthesizeText(request: SynthesisRequest?, callback: SynthesisCallback?) {
        if (request == null || callback == null) return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            // Không bao giờ xảy ra với TextToSpeechService chuẩn (có luồng
            // tổng hợp riêng); chặn để không tự khoá luồng nhận tin từ Dart.
            callback.error(TextToSpeech.ERROR_SERVICE)
            return
        }

        val text = request.charSequenceText?.toString().orEmpty()
        val known = catalog()
        val voice = known.byName(request.voiceName)
            ?: known.pick(request.language, request.country)
        if (voice == null) {
            Log.w(TAG, "không có giọng offline cho ${request.language}-${request.country}")
            callback.error(TextToSpeech.ERROR_NOT_INSTALLED_YET)
            return
        }
        if (!SystemTtsRuntime.awaitReady(READY_WAIT_MS)) {
            Log.e(TAG, "engine Flutter nền chưa sẵn sàng")
            callback.error(TextToSpeech.ERROR_SERVICE)
            return
        }

        val session = SystemTtsRuntime.beginSynthesis(
            text = text,
            voice = voice,
            rate = request.speechRate / 100.0,
            pitch = request.pitch / 100.0,
        )
        var started = false
        var cancelDart = true
        try {
            while (true) {
                val event = session.events.poll(EVENT_WAIT_SECONDS, TimeUnit.SECONDS)
                if (event == null) {
                    Log.e(TAG, "quá hạn chờ âm thanh từ worker Dart")
                    callback.error(TextToSpeech.ERROR_SYNTHESIS)
                    return
                }
                when (event) {
                    is SystemTtsRuntime.Event.Stopped -> return

                    is SystemTtsRuntime.Event.Audio -> {
                        if (!started) {
                            callback.start(event.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1)
                            started = true
                        }
                        val written = writePcm(callback, event.pcm)
                        event.ack(written)
                        if (!written) return
                    }

                    is SystemTtsRuntime.Event.Done -> {
                        cancelDart = false
                        when (event.status) {
                            SystemTtsRuntime.STATUS_OK -> {
                                if (!started) {
                                    // Câu chỉ có dấu câu/khoảng trắng: vẫn phải
                                    // báo "xong" để app gọi không chờ mãi.
                                    callback.start(
                                        SILENT_SAMPLE_RATE,
                                        AudioFormat.ENCODING_PCM_16BIT,
                                        1,
                                    )
                                }
                                callback.done()
                            }

                            SystemTtsRuntime.STATUS_CANCELLED -> Unit

                            SystemTtsRuntime.STATUS_NO_VOICE -> {
                                Log.w(TAG, "worker: ${event.message}")
                                callback.error(TextToSpeech.ERROR_NOT_INSTALLED_YET)
                            }

                            else -> {
                                Log.e(TAG, "worker: ${event.status} ${event.message}")
                                callback.error(TextToSpeech.ERROR_SYNTHESIS)
                            }
                        }
                        return
                    }
                }
            }
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            SystemTtsRuntime.endSynthesis(session, cancelDart)
        }
    }

    /**
     * Ghi PCM theo từng phần không vượt `maxBufferSize` (Android từ chối
     * khối lớn hơn). Trả `false` khi Android đã dừng yêu cầu.
     */
    private fun writePcm(callback: SynthesisCallback, pcm: ByteArray): Boolean {
        val max = callback.maxBufferSize.coerceAtLeast(2) and 1.inv() // chẵn: không cắt đôi mẫu 16-bit
        var offset = 0
        while (offset < pcm.size) {
            val length = minOf(max, pcm.size - offset)
            if (callback.audioAvailable(pcm, offset, length) != TextToSpeech.SUCCESS) {
                return false
            }
            offset += length
        }
        return true
    }
}
