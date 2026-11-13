package com.in4up.systemtts

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * PSRC-221 — engine Flutter NỀN + channel của "in4up làm giọng đọc hệ thống".
 *
 * Một tiến trình chỉ có MỘT runtime, dùng chung cho [In4UpTtsService] và các
 * activity `CHECK_TTS_DATA` / `GET_SAMPLE_TEXT` (đếm tham chiếu bằng
 * [acquire] / [release]).
 *
 * Vì sao đi qua engine Flutter chứ không gọi native thẳng: Piper của app chạy
 * bằng sherpa-onnx qua Dart FFI, VieNeu qua Dart FFI + worker isolate — không
 * có lớp JNI nào. Viết lại hai engine đó bằng JNI là "thay engine nội bộ"
 * (phiếu L8 cấm). Engine nền do service tự dựng nên KHÔNG cần app đang mở:
 * Android bind service ⇒ tiến trình được tạo ⇒ engine nền chạy entrypoint
 * `in4upSystemTtsMain` (cùng cách làm với ScreenTranslateService, ADR-0011).
 *
 * Luồng:
 *  - Mọi lời gọi [MethodChannel] chạy trên luồng CHÍNH (yêu cầu của Flutter).
 *  - `onSynthesizeText` chạy trên luồng tổng hợp của TextToSpeechService và
 *    CHỜ kết quả qua hàng đợi của [Session].
 *  - Các hàm hỏi ngôn ngữ có thể bị gọi trên luồng chính (client cùng tiến
 *    trình, ví dụ plugin flutter_tts của chính app) ⇒ [catalog] không bao giờ
 *    chờ khi đang ở luồng chính.
 */
object SystemTtsRuntime {
    private const val TAG = "In4UpSystemTts"

    // ── giao thức — khớp lib/core/platform/system_tts/system_tts_protocol.dart
    const val CHANNEL = "in4up/system_tts"
    const val DART_LIBRARY =
        "package:in4up/core/platform/system_tts/system_tts_entrypoint.dart"
    const val DART_ENTRYPOINT = "in4upSystemTtsMain"

    const val METHOD_READY = "ready"
    const val METHOD_AUDIO = "audio"
    const val METHOD_LIST_VOICES = "listVoices"
    const val METHOD_SYNTHESIZE = "synthesize"
    const val METHOD_CANCEL = "cancel"

    const val KEY_REQUEST_ID = "requestId"
    const val KEY_TEXT = "text"
    const val KEY_VOICE = "voice"
    const val KEY_LOCALE = "locale"
    const val KEY_RATE = "rate"
    const val KEY_PITCH = "pitch"
    const val KEY_SAMPLE_RATE = "sampleRate"
    const val KEY_PCM = "pcm"
    const val KEY_VOICES = "voices"
    const val KEY_STATUS = "status"
    const val KEY_MESSAGE = "message"

    const val STATUS_OK = "ok"
    const val STATUS_CANCELLED = "cancelled"
    const val STATUS_NO_VOICE = "noVoice"
    const val STATUS_FAILED = "failed"

    // Danh mục giọng của lần chạy trước, để trả lời Android NGAY khi service
    // vừa được bind (engine nền cần ~1 giây mới báo lại).
    private const val PREFS = "in4up_system_tts"
    private const val PREF_VOICES = "voices"

    /** Khoảng cách tối thiểu giữa hai lần yêu cầu Dart quét lại giọng. */
    private const val REFRESH_INTERVAL_MS = 3_000L

    /** Một sự kiện Dart gửi về cho yêu cầu đang đọc. */
    sealed class Event {
        class Audio(
            val sampleRate: Int,
            val pcm: ByteArray,
            private val reply: (Boolean) -> Unit,
        ) : Event() {
            private var answered = false

            /** Trả lời Dart đúng MỘT lần: `true` = đã ghi xong, gửi khối kế. */
            fun ack(accepted: Boolean) {
                synchronized(this) {
                    if (answered) return
                    answered = true
                }
                reply(accepted)
            }
        }

        class Done(val status: String, val message: String?) : Event()

        /** `onStop` — chỉ để đánh thức luồng tổng hợp đang chờ. */
        object Stopped : Event()
    }

    /** Một lượt `onSynthesizeText`. */
    class Session(val id: Int) {
        val events = LinkedBlockingQueue<Event>()

        @Volatile
        var closed = false
            private set

        /** Thêm sự kiện nếu lượt còn sống. Trả `false` khi đã đóng. */
        fun offer(event: Event): Boolean = synchronized(this) {
            if (closed) {
                false
            } else {
                events.put(event)
                true
            }
        }

        /**
         * Đóng lượt và từ chối mọi khối âm thanh còn nằm trong hàng đợi —
         * nếu không Dart sẽ chờ lời xác nhận mãi.
         */
        fun close() {
            val pending = ArrayList<Event>()
            synchronized(this) {
                closed = true
                events.drainTo(pending)
            }
            for (event in pending) {
                if (event is Event.Audio) event.ack(false)
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val requestIds = AtomicInteger(0)

    private var appContext: Context? = null
    private var users = 0
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var lastRefreshAt = 0L
    private val voiceListeners = ArrayList<(SystemTtsVoiceCatalog) -> Unit>()

    @Volatile
    private var readyLatch = CountDownLatch(1)

    @Volatile
    private var startFailed = false

    @Volatile
    private var cached: SystemTtsVoiceCatalog? = null

    /** Dart đã báo danh mục giọng trong vòng đời engine hiện tại chưa. */
    @Volatile
    private var reported = false

    @Volatile
    private var current: Session? = null

    // ───────────────────────── vòng đời ───────────────────────────────

    /** Gọi trên luồng chính (onCreate của service/activity). */
    fun acquire(context: Context) {
        val app = context.applicationContext
        appContext = app
        if (cached == null) cached = loadCache(app)
        users++
        startEngine(app)
    }

    /** Gọi trên luồng chính (onDestroy của service/activity). */
    fun release() {
        users--
        if (users > 0) return
        users = 0
        destroyEngine()
    }

    private fun startEngine(app: Context) {
        if (engine != null) return
        startFailed = false
        reported = false
        readyLatch = CountDownLatch(1)
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationComplete(app, null)

            val group = FlutterEngineGroup(app)
            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                DART_LIBRARY,
                DART_ENTRYPOINT,
            )
            val created = group.createAndRunEngine(app, entrypoint)
            val ch = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
            ch.setMethodCallHandler { call, result -> onDartCall(call, result) }
            engine = created
            channel = ch
        } catch (e: Throwable) {
            // Không ném ra ngoài: service vẫn phải sống để trả lỗi tử tế cho
            // app gọi thay vì làm sập tiến trình.
            Log.e(TAG, "không dựng được engine Flutter nền", e)
            startFailed = true
            readyLatch.countDown()
        }
    }

    private fun destroyEngine() {
        current?.close()
        current = null
        channel?.setMethodCallHandler(null)
        channel = null
        try {
            engine?.destroy()
        } catch (e: Throwable) {
            Log.w(TAG, "destroy engine lỗi", e)
        }
        engine = null
        reported = false
    }

    // ───────────────────────── Dart → native ──────────────────────────

    private fun onDartCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_READY -> {
                updateCatalog(SystemTtsVoiceCatalog.fromChannel(call.argument<Any>(KEY_VOICES)))
                readyLatch.countDown()
                result.success(null)
            }

            METHOD_AUDIO -> {
                val id = call.argument<Int>(KEY_REQUEST_ID)
                val rate = call.argument<Int>(KEY_SAMPLE_RATE) ?: 0
                val pcm = call.argument<ByteArray>(KEY_PCM)
                val session = current
                if (session == null || session.id != id || pcm == null || rate <= 0) {
                    result.success(false)
                    return
                }
                val event = Event.Audio(rate, pcm) { accepted ->
                    mainHandler.post { result.success(accepted) }
                }
                if (!session.offer(event)) event.ack(false)
            }

            else -> result.notImplemented()
        }
    }

    private fun updateCatalog(catalog: SystemTtsVoiceCatalog) {
        cached = catalog
        reported = true
        try {
            appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                ?.edit()?.putString(PREF_VOICES, catalog.toJson())?.apply()
        } catch (e: Exception) {
            Log.w(TAG, "không lưu được danh mục giọng", e)
        }
        val listeners = ArrayList(voiceListeners)
        voiceListeners.clear()
        for (listener in listeners) listener(catalog)
    }

    private fun loadCache(app: Context): SystemTtsVoiceCatalog = try {
        SystemTtsVoiceCatalog.fromJson(
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(PREF_VOICES, null),
        )
    } catch (e: Exception) {
        SystemTtsVoiceCatalog.EMPTY
    }

    // ───────────────────────── danh mục giọng ─────────────────────────

    /**
     * Danh mục giọng hiện biết.
     *
     * Chỉ CHỜ engine nền (tối đa [waitMs]) khi: chưa có gì để trả (cache
     * rỗng), Dart chưa báo lần nào, và KHÔNG ở luồng chính — chờ ở luồng
     * chính là tự khoá vì chính luồng đó nhận tin từ Dart.
     */
    fun catalog(waitMs: Long = 0L): SystemTtsVoiceCatalog {
        val known = cached ?: SystemTtsVoiceCatalog.EMPTY
        if (!known.isEmpty() || reported || waitMs <= 0L) return known
        if (Looper.myLooper() == Looper.getMainLooper()) return known
        try {
            readyLatch.await(waitMs, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return cached ?: SystemTtsVoiceCatalog.EMPTY
    }

    /**
     * Gọi [listener] (trên luồng chính) khi đã có danh mục do Dart báo trong
     * vòng đời engine này, hoặc sau [timeoutMs] với thứ đang có.
     * Gọi từ luồng chính.
     */
    fun whenVoicesReported(timeoutMs: Long, listener: (SystemTtsVoiceCatalog) -> Unit) {
        if (reported || startFailed) {
            listener(cached ?: SystemTtsVoiceCatalog.EMPTY)
            return
        }
        var fired = false
        val once: (SystemTtsVoiceCatalog) -> Unit = { catalog ->
            if (!fired) {
                fired = true
                listener(catalog)
            }
        }
        voiceListeners.add(once)
        mainHandler.postDelayed({
            voiceListeners.remove(once)
            once(cached ?: SystemTtsVoiceCatalog.EMPTY)
        }, timeoutMs)
    }

    /**
     * Nhờ Dart quét lại giọng (người dùng có thể vừa import model). Không
     * chặn; có giãn cách để các lời hỏi dồn dập của Android không thành bão.
     */
    fun refreshVoicesAsync() {
        mainHandler.post {
            val ch = channel ?: return@post
            if (!reported) return@post
            val now = android.os.SystemClock.elapsedRealtime()
            if (now - lastRefreshAt < REFRESH_INTERVAL_MS) return@post
            lastRefreshAt = now
            ch.invokeMethod(METHOD_LIST_VOICES, null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    updateCatalog(SystemTtsVoiceCatalog.fromChannel(result))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "listVoices lỗi: $code $message")
                }

                override fun notImplemented() {
                    Log.w(TAG, "listVoices: Dart chưa gắn handler")
                }
            })
        }
    }

    // ───────────────────────── tổng hợp ───────────────────────────────

    /** Chờ worker Dart sẵn sàng. KHÔNG gọi trên luồng chính. */
    fun awaitReady(timeoutMs: Long): Boolean {
        if (startFailed) return false
        val ok = try {
            readyLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        return ok && !startFailed
    }

    /** Bắt đầu một lượt đọc; sự kiện về qua [Session.events]. */
    fun beginSynthesis(
        text: String,
        voice: SystemTtsVoiceInfo,
        rate: Double,
        pitch: Double,
    ): Session {
        val session = Session(requestIds.incrementAndGet())
        current?.close()
        current = session
        val args = HashMap<String, Any?>()
        args[KEY_REQUEST_ID] = session.id
        args[KEY_TEXT] = text
        args[KEY_VOICE] = voice.name
        args[KEY_LOCALE] = voice.tag
        args[KEY_RATE] = rate
        args[KEY_PITCH] = pitch
        mainHandler.post {
            val ch = channel
            if (ch == null) {
                session.offer(Event.Done(STATUS_FAILED, "engine stopped"))
                return@post
            }
            ch.invokeMethod(METHOD_SYNTHESIZE, args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val map = result as? Map<*, *>
                    session.offer(
                        Event.Done(
                            map?.get(KEY_STATUS) as? String ?: STATUS_FAILED,
                            map?.get(KEY_MESSAGE) as? String,
                        ),
                    )
                }

                override fun error(code: String, message: String?, details: Any?) {
                    session.offer(Event.Done(STATUS_FAILED, "$code: $message"))
                }

                override fun notImplemented() {
                    session.offer(Event.Done(STATUS_FAILED, "worker not attached"))
                }
            })
        }
        return session
    }

    /** Kết thúc lượt (xong, lỗi, hoặc bị dừng). Gọi được từ mọi luồng. */
    fun endSynthesis(session: Session, cancelDart: Boolean) {
        session.close()
        if (current === session) current = null
        if (cancelDart) sendCancel(session.id)
    }

    /** `onStop` của service: dừng lượt đang đọc, đánh thức luồng tổng hợp. */
    fun stopCurrent() {
        val session = current ?: return
        sendCancel(session.id)
        session.offer(Event.Stopped)
    }

    private fun sendCancel(id: Int) {
        mainHandler.post {
            val args = HashMap<String, Any?>()
            args[KEY_REQUEST_ID] = id
            channel?.invokeMethod(METHOD_CANCEL, args)
        }
    }
}
