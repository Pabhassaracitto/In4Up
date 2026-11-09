package com.in4up.screentranslate

import android.animation.ValueAnimator
import android.app.Activity
import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.Toast
import com.in4up.R
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max

/**
 * XLAT-SCR-002 / XLAT-SCR-003 / ADR-0011 — "Dịch màn hình toàn hệ thống" (Android).
 *
 * Foreground service giữ:
 *  1. **Bong bóng** (TYPE_APPLICATION_OVERLAY) kéo được, bấm = chụp 1 lần.
 *  2. **MediaProjection + ImageReader** — tạo MỘT lần sau khi có consent, giữ
 *     ấm cho cả phiên (xem [startWarmDisplay] vì sao).
 *  3. **Engine Flutter NỀN** (FlutterEngineGroup, entrypoint
 *     `screenTranslateMain`) để OCR + dịch bằng đúng OcrService /
 *     TranslationService của app — KHÔNG viết engine dịch thứ hai.
 *  4. **Overlay bản dịch** ([TranslationOverlayView]) vẽ đè theo bbox.
 *
 * Luật đã chốt, đừng "tối ưu" ngược:
 *  - Mỗi lần bấm = MỘT lần chụp (Dart chỉ đọc 1 frame). KHÔNG vòng lặp capture.
 *  - **Android 10+ cấm `startActivity` từ nền.** Mọi activity (xin consent,
 *    mở Cài đặt overlay) PHẢI đi qua [PendingIntent] kèm
 *    `ActivityOptions.setPendingIntentBackgroundActivityStartMode(
 *    MODE_BACKGROUND_ACTIVITY_START_ALLOWED)` (API 34+) — xem
 *    [backgroundActivityOptions]. Dù vậy hệ thống vẫn CÓ THỂ chặn (màn hình
 *    khoá, ROM siết) ⇒ có watchdog [consentWatchdog] và luôn có thông báo.
 *  - **Luật "không bao giờ im lặng":** mọi nhánh thất bại của
 *    [onBubbleTapped] phải gọi [tellUser] (rung + toast + notification).
 *  - Android 14+: consent MediaProjection xin lại mỗi phiên; một token dùng
 *    MỘT lần, một [MediaProjection] chỉ được `createVirtualDisplay` MỘT lần
 *    (gọi lần hai ⇒ SecurityException). Không lưu token để tái dùng.
 *  - Thứ tự bắt buộc trên Android 14: `createScreenCaptureIntent` (consent) →
 *    `startForeground(type=mediaProjection)` → `getMediaProjection` →
 *    `createVirtualDisplay`. Sai thứ tự = SecurityException/service bị giết.
 *  - Tắt = dừng projection + gỡ overlay + huỷ notification + destroy engine.
 *
 * ⚠️ Phần này CHƯA chạy trên thiết bị trong sandbox (không có Flutter SDK /
 * Android SDK, không có máy thật) — chờ nghiệm thu máy thật theo mục 5 của
 * card XLAT-SCR-003.
 */
class ScreenTranslateService : Service() {

    companion object {
        const val ACTION_START = "com.in4up.screentranslate.START"
        const val ACTION_STOP = "com.in4up.screentranslate.STOP"
        const val ACTION_CONSENT_RESULT = "com.in4up.screentranslate.CONSENT"
        const val ACTION_SET_TARGET = "com.in4up.screentranslate.SET_TARGET"

        /**
         * XLAT-SCR-005 — đổi chế độ "bấm bong bóng = kéo chọn vùng" khi
         * service đang chạy (công tắc trong thẻ cài đặt đổi là có hiệu lực
         * ngay, không cần tắt/bật bong bóng).
         */
        const val ACTION_SET_CAPTURE_MODE =
            "com.in4up.screentranslate.SET_CAPTURE_MODE"

        /**
         * [ScreenCaptureRequestActivity] báo "ta ĐÃ lên foreground thật"
         * (chống chặn background activity start bị nuốt im lặng).
         */
        const val ACTION_CONSENT_UI_SHOWN = "com.in4up.screentranslate.CONSENT_UI"

        /** Yêu cầu mở đúng màn hình Cài đặt quyền overlay. */
        const val ACTION_OPEN_OVERLAY_SETTINGS =
            "com.in4up.screentranslate.OPEN_OVERLAY_SETTINGS"

        const val EXTRA_TARGET_LANGUAGE = "targetLanguage"

        /**
         * Ngôn ngữ NGUỒN ('AUTO' = engine tự nhận diện). Owner 24/10: trước
         * đây chỉ đổi được đích vì service chỉ nhận `targetLanguage`.
         */
        const val EXTRA_SOURCE_LANGUAGE = "sourceLanguage"

        /** Bấm bong bóng ⇒ mở khung kéo chọn vùng (thay vì chụp cả màn hình). */
        const val EXTRA_SELECT_REGION = "selectRegion"

        const val EXTRA_LOCALE = "locale"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"

        private const val CHANNEL_ID = "in4up_screen_translate"
        private const val CHANNEL_ALERT_ID = "in4up_screen_translate_alert"
        private const val NOTIFICATION_ID = 0x5C22

        /** Thông báo cần thao tác (heads-up) — id riêng vì không đổi kênh được. */
        private const val NOTIFICATION_ALERT_ID = 0x5C23

        private const val REQ_OVERLAY = 0x5C25
        private const val REQ_STOP = 0x5C26

        /** Chờ activity xin consent lên foreground trước khi kết luận "bị chặn". */
        private const val CONSENT_UI_TIMEOUT_MS = 2500L

        /** Ảnh đầu tiên sau khi tạo VirtualDisplay chưa kịp có ⇒ thử lại một nhịp. */
        private const val FIRST_FRAME_RETRY_MS = 350L

        /**
         * Chờ một nhịp SAU khi gỡ khung kéo chọn rồi mới chụp.
         *
         * Không chờ thì ảnh chụp sẽ dính chính lớp phủ tối + viền xanh của
         * khung chọn (WindowManager gỡ view không đồng nghĩa frame đã được
         * tổng hợp lại). 180ms đủ trên máy phổ thông, vẫn dưới ngưỡng người
         * dùng cảm thấy chậm.
         */
        private const val REGION_CLEAR_DELAY_MS = 180L

        /** Giữ trạng thái ✓/! trên bong bóng bao lâu trước khi về trạng thái sẵn sàng. */
        private const val BUBBLE_RESULT_HOLD_MS = 1400L

        /** Cạnh dài nhất của ảnh chụp — OCR không cần full 1440p. */
        private const val MAX_CAPTURE_EDGE = 1920

        /** Dart entrypoint của engine nền. */
        private const val DART_LIBRARY =
            "package:in4up/features/screen_translate/screen_translate_entrypoint.dart"
        private const val DART_ENTRYPOINT = "screenTranslateMain"

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Đã có consent + projection hợp lệ cho phiên hiện tại chưa. */
        @Volatile
        var captureConsented: Boolean = false
            private set

        /** Lần xin consent GẦN NHẤT bị user từ chối. */
        @Volatile
        var consentDenied: Boolean = false
            private set

        /**
         * Lý do bong bóng vừa KHÔNG làm được việc (`overlay`, `consent_blocked`,
         * `consent_denied`, `capture_error`…). UI đọc để nói đúng bước tiếp theo.
         */
        @Volatile
        var lastBlockReason: String = ""
            private set

        /** Quyền overlay (SYSTEM_ALERT_WINDOW) — user có thể thu hồi bất kỳ lúc nào. */
        fun hasOverlayPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Settings.canDrawOverlays(context)

        internal fun markConsented() {
            captureConsented = true
            consentDenied = false
        }

        internal fun markConsentDenied() {
            captureConsented = false
            consentDenied = true
        }

        internal fun markConsentLost() {
            captureConsented = false
        }

        internal fun setBlockReason(reason: String) {
            lastBlockReason = reason
        }

        internal fun resetSessionFlags() {
            isRunning = false
            captureConsented = false
            consentDenied = false
            lastBlockReason = ""
        }
    }

    /** Hành động phục hồi gắn vào notification khi bong bóng bị chặn. */
    private enum class Recovery { NONE, CONSENT, OVERLAY_SETTINGS }

    /**
     * Trạng thái HIỂN THỊ của bong bóng (XLAT-SCR-005).
     *
     * Vì sao cần: owner báo "bấm bong bóng mà không biết đã bấm trúng chưa,
     * phải bấm thêm". Vòng tròn 52dp đổi màu + nhấp nháy + chấm "…" là phản
     * hồi tức thì, không phụ thuộc thông báo hệ thống (có máy tắt thông báo).
     */
    private enum class BubbleState { READY, SETUP, WORKING, DONE, ERROR }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var windowManager: WindowManager? = null
    private var bubbleView: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var overlayView: TranslationOverlayView? = null

    // ── Phản hồi khi bấm bong bóng (XLAT-SCR-005) ────────────────────
    private var bubbleState: BubbleState = BubbleState.SETUP
    private var bubblePulse: ValueAnimator? = null

    /** Nhãn nhỏ ngay dưới bong bóng: "Đang nhận dạng chữ…", "Đang dịch 3/12…". */
    private var statusChip: TextView? = null
    private var statusChipParams: WindowManager.LayoutParams? = null

    /** Khung kéo chọn vùng đang hiển thị (null = không ở chế độ chọn vùng). */
    private var regionView: RegionSelectView? = null

    /** Vùng người dùng vừa chọn (pixel MÀN HÌNH) — dùng cho ĐÚNG một lượt chụp. */
    private var pendingRegion: Rect? = null

    private var engine: FlutterEngine? = null
    private var workerChannel: MethodChannel? = null
    private var workerReady = false

    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null

    /** Hình học đã dùng khi tạo VirtualDisplay — giữ để gửi kèm mỗi frame. */
    private var captureMetrics: DisplayMetrics? = null
    private var captureWidth = 0
    private var captureHeight = 0

    private var targetLanguage: String = "VI"

    /** 'AUTO' = engine tự nhận diện; hoặc mã như 'EN'/'JA' (XLAT-SCR-005). */
    private var sourceLanguage: String = "AUTO"

    /** Bấm bong bóng ⇒ mở khung kéo chọn vùng thay vì dịch cả màn hình. */
    private var selectRegionMode: Boolean = false

    private var localeCode: String = "vi"
    private var capturing = false
    private var pendingCaptureAfterConsent = false

    /** Sau khi có consent thì mở luôn khung kéo chọn vùng (giữ lâu bong bóng). */
    private var pendingRegionSelectAfterConsent = false
    private var isStopping = false
    private var awaitingConsentUi = false
    private var pendingRecovery: Recovery = Recovery.NONE

    private val consentWatchdog = Runnable {
        // Chạy mà activity chưa bao giờ onResume ⇒ Android đã nuốt lệnh mở
        // activity (background activity start). Nói cho user biết cách đi tiếp.
        if (awaitingConsentUi) onConsentBlocked()
    }

    /**
     * Cờ "đang gỡ/gắn lại bong bóng CHỦ ĐỘNG".
     *
     * IN4-17 (log 18/10): `showOverlay()` gỡ bong bóng rồi gắn lại (để bong
     * bóng nằm trên overlay) ⇒ `removeView` bắn `onViewDetachedFromWindow` ⇒
     * listener cứ coi là "quyền overlay bị thu hồi" ⇒ `onOverlayRevoked()` ⇒
     * dừng MediaProjection, gỡ overlay, FFmpeg/TTS rớt — **overlay vừa hiện
     * lại bị dọn**. Cờ này cho biết detach là do app tự làm.
     */
    @Volatile
    private var bubbleReordering = false

    private val overlayDetachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(v: View) = Unit

        override fun onViewDetachedFromWindow(v: View) {
            // (1) App tự gỡ để gắn lại ⇒ KHÔNG phải thu hồi quyền.
            if (bubbleReordering) {
                android.util.Log.i("In4upScr", "bubble detach: do app gỡ để gắn lại — bỏ qua")
                return
            }
            // (2) Còn quyền overlay? ⇒ hệ thống gỡ view vì lý do khác
            //     (vd app bị gọi removeBubble khi dừng) ⇒ KHÔNG kết luận
            //     "thu hồi quyền", chỉ cần dựng lại bong bóng.
            if (hasOverlayPermission(this@ScreenTranslateService)) {
                android.util.Log.w(
                    "In4upScr",
                    "bubble detach nhưng quyền overlay VẪN còn — không coi là thu hồi",
                )
                // View đã bị gỡ khỏi cửa sổ ⇒ phải xoá tham chiếu để
                // showBubble() dựng lại được (nó return sớm nếu bubbleView != null).
                bubbleView = null
                bubbleParams = null
                mainHandler.post { restoreBubbleIfNeeded() }
                return
            }
            // (3) Mất quyền thật ⇒ mới teardown.
            if (isRunning && !isStopping) {
                android.util.Log.w("In4upScr", "bubble detach + mất quyền overlay ⇒ teardown phiên")
                mainHandler.post { onOverlayRevoked() }
            }
        }
    }

    /** Dựng lại bong bóng nếu bị gỡ nhưng phiên vẫn sống. */
    private fun restoreBubbleIfNeeded() {
        if (!isRunning || isStopping) return
        if (bubbleView != null) return
        try {
            showBubble()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // User bấm "Dừng chia sẻ" ở thanh thông báo hệ thống.
            mainHandler.post {
                releaseProjection()
                hideOverlay()
                setBlockReason("capture_lost")
                tellUser(getString(R.string.screen_translate_capture_lost))
                refreshBubbleLook()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopEverything()
                return START_NOT_STICKY
            }

            ACTION_SET_TARGET -> {
                intent.getStringExtra(EXTRA_TARGET_LANGUAGE)?.let { targetLanguage = it }
                intent.getStringExtra(EXTRA_SOURCE_LANGUAGE)?.let { sourceLanguage = it }
                return START_STICKY
            }

            ACTION_SET_CAPTURE_MODE -> {
                selectRegionMode = intent.getBooleanExtra(EXTRA_SELECT_REGION, false)
                if (!selectRegionMode) endRegionSelect()
                refreshBubbleLook()
                return START_STICKY
            }

            ACTION_CONSENT_RESULT -> {
                handleConsent(intent)
                return START_STICKY
            }

            ACTION_CONSENT_UI_SHOWN -> {
                // Activity xin consent đã lên foreground thật ⇒ huỷ watchdog.
                awaitingConsentUi = false
                mainHandler.removeCallbacks(consentWatchdog)
                return START_STICKY
            }

            ACTION_OPEN_OVERLAY_SETTINGS -> {
                openOverlaySettings()
                return START_STICKY
            }

            else -> {
                intent?.getStringExtra(EXTRA_TARGET_LANGUAGE)?.let { targetLanguage = it }
                intent?.getStringExtra(EXTRA_SOURCE_LANGUAGE)?.let { sourceLanguage = it }
                intent?.getStringExtra(EXTRA_LOCALE)?.let { localeCode = it }
                // Dùng safe-call + giá trị mặc định thay vì smart-cast: service
                // có thể được hệ thống khởi lại với intent null.
                if (intent?.hasExtra(EXTRA_SELECT_REGION) == true) {
                    selectRegionMode =
                        intent?.getBooleanExtra(EXTRA_SELECT_REGION, false) ?: false
                }
                startBubbleSession()
                return START_STICKY
            }
        }
    }

    // ───────────────────────── vòng đời phiên ─────────────────────────

    private fun startBubbleSession() {
        if (isRunning) {
            updateNotification(notificationStatusText())
            return
        }
        if (!hasOverlayPermission(this)) {
            // Không vẽ được gì cả ⇒ đừng giả vờ sống: nói rõ rồi dừng.
            setBlockReason("overlay")
            isStopping = true
            reportOverlayMissing()
            stopSelf()
            return
        }
        isStopping = false
        createNotificationChannel()
        createAlertChannel()
        startForegroundCompat(mediaProjectionType = false)
        isRunning = true
        showBubble()
        ensureEngine()
        updateNotification(notificationStatusText())
    }

    private fun stopEverything() {
        isStopping = true
        isRunning = false
        mainHandler.removeCallbacks(consentWatchdog)
        awaitingConsentUi = false
        releaseProjection()
        hideOverlay()
        endRegionSelect()
        hideStatusChip()
        stopBubblePulse()
        removeBubble()
        destroyEngine()
        resetSessionFlags()
        cancelAlert()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        isStopping = true
        isRunning = false
        mainHandler.removeCallbacks(consentWatchdog)
        releaseProjection()
        hideOverlay()
        endRegionSelect()
        hideStatusChip()
        stopBubblePulse()
        removeBubble()
        destroyEngine()
        super.onDestroy()
    }

    // ───────────────────────── engine Flutter nền ─────────────────────

    private fun ensureEngine() {
        if (engine != null) return
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            val group = FlutterEngineGroup(applicationContext)
            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                DART_LIBRARY,
                DART_ENTRYPOINT,
            )
            val created = group.createAndRunEngine(applicationContext, entrypoint)
            engine = created
            val channel = MethodChannel(
                created.dartExecutor.binaryMessenger,
                "in4up/screentranslate/worker",
            )
            channel.setMethodCallHandler { call, result -> onWorkerCall(call, result) }
            workerChannel = channel
        } catch (e: Exception) {
            e.printStackTrace()
            setBlockReason("engine")
            tellUser(getString(R.string.screen_translate_error))
        }
    }

    private fun destroyEngine() {
        workerChannel?.setMethodCallHandler(null)
        workerChannel = null
        workerReady = false
        try {
            engine?.destroy()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        engine = null
    }

    private fun onWorkerCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "workerReady" -> {
                workerReady = true
                result.success(null)
            }

            "reportProgress" -> {
                val stage = call.argument<String>("stage").orEmpty()
                if (stage.isNotEmpty()) {
                    updateNotification(stage)
                    // Chỉ đổi nhãn khi đang chạy — tránh nhãn cũ bám lại sau
                    // khi đã có kết quả.
                    if (bubbleState == BubbleState.WORKING) showStatusChip(stage)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ───────────────────────── bong bóng ──────────────────────────────

    private fun showBubble() {
        if (bubbleView != null) return
        if (!hasOverlayPermission(this)) {
            onOverlayRevoked()
            return
        }
        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        windowManager = wm

        val size = dp(52)
        val bubble = TextView(this).apply {
            text = getString(R.string.screen_translate_bubble_label)
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(235, 20, 110, 160))
                setStroke(dp(2), Color.argb(200, 255, 255, 255))
            }
        }

        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(160)
        }

        bubble.setOnTouchListener(
            BubbleTouchListener(
                wm,
                params,
                onTap = { onBubbleTapped() },
                onLongPress = { onBubbleLongPressed() },
            ),
        )
        bubble.addOnAttachStateChangeListener(overlayDetachListener)

        try {
            wm.addView(bubble, params)
            bubbleView = bubble
            bubbleParams = params
            refreshBubbleLook()
        } catch (e: Exception) {
            // Mất quyền overlay giữa chừng (user thu hồi trong Settings) hoặc
            // ROM chặn. KHÔNG nuốt im lặng.
            e.printStackTrace()
            onOverlayRevoked()
        }
    }

    private fun removeBubble() {
        hideStatusChip()
        val view = bubbleView ?: return
        try {
            view.removeOnAttachStateChangeListener(overlayDetachListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        bubbleView = null
        bubbleParams = null
    }

    /** Bong bóng xanh = sẵn sàng; cam + ⚙ = "cần thiết lập" (chưa có consent). */
    private fun refreshBubbleLook() {
        val ready = captureConsented && projection != null
        setBubbleState(if (ready) BubbleState.READY else BubbleState.SETUP)
    }

    /**
     * Đổi trạng thái bong bóng — PHẢN HỒI TỨC THÌ cho cú bấm (XLAT-SCR-005).
     *
     * Màu + nhãn + nhấp nháy khi đang chạy; ✓ xanh khi xong; ! đỏ khi lỗi.
     * Không phụ thuộc notification (Android 13+ có thể chưa cấp
     * POST_NOTIFICATIONS ⇒ người dùng không thấy gì — đó chính là triệu chứng
     * owner báo).
     */
    private fun setBubbleState(state: BubbleState, holdMs: Long = 0L) {
        bubbleState = state
        mainHandler.removeCallbacks(resetBubbleRunnable)
        val bubble = bubbleView
        if (bubble != null) {
            bubble.text = when (state) {
                BubbleState.READY -> getString(R.string.screen_translate_bubble_label)
                BubbleState.SETUP -> getString(R.string.screen_translate_bubble_setup_label)
                BubbleState.WORKING -> getString(R.string.screen_translate_bubble_working_label)
                BubbleState.DONE -> getString(R.string.screen_translate_bubble_done_label)
                BubbleState.ERROR -> getString(R.string.screen_translate_bubble_error_label)
            }
            bubble.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(bubbleColor(state))
                setStroke(dp(2), Color.argb(200, 255, 255, 255))
            }
            if (state == BubbleState.WORKING) {
                startBubblePulse(bubble)
            } else {
                stopBubblePulse(bubble)
            }
        }
        if (holdMs > 0L) {
            mainHandler.postDelayed(resetBubbleRunnable, holdMs)
        }
    }

    /** Sau khi hiện ✓/! một nhịp thì trở lại trạng thái theo quyền hiện tại. */
    private val resetBubbleRunnable = Runnable { refreshBubbleLook() }

    private fun bubbleColor(state: BubbleState): Int = when (state) {
        BubbleState.READY -> Color.argb(235, 20, 110, 160)
        BubbleState.SETUP -> Color.argb(235, 190, 120, 20)
        BubbleState.WORKING -> Color.argb(235, 112, 66, 200)
        BubbleState.DONE -> Color.argb(235, 22, 140, 92)
        BubbleState.ERROR -> Color.argb(235, 180, 44, 44)
    }

    private fun startBubblePulse(view: View) {
        stopBubblePulse(view)
        try {
            val animator = ValueAnimator.ofFloat(1f, 0.45f).apply {
                duration = 420L
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                addUpdateListener { view.alpha = it.animatedValue as Float }
            }
            bubblePulse = animator
            animator.start()
        } catch (e: Exception) {
            // Nhấp nháy là trang trí — hỏng animation không được làm hỏng lượt dịch.
            e.printStackTrace()
            view.alpha = 1f
        }
    }

    private fun stopBubblePulse(view: View? = bubbleView) {
        try {
            bubblePulse?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        bubblePulse = null
        view?.alpha = 1f
    }

    // ── Nhãn trạng thái dưới bong bóng ────────────────────────────────

    /**
     * Hiện/ cập nhật nhãn nhỏ ngay dưới bong bóng ("Đang nhận dạng chữ…",
     * "Đang dịch 3/12 khối chữ…").
     *
     * Dùng window overlay riêng thay vì canvas của bong bóng: bong bóng chỉ
     * 52dp, nhồi chữ vào đó sẽ không đọc được. Nhãn KHÔNG nhận chạm
     * (`FLAG_NOT_TOUCHABLE`) nên không cản app bên dưới.
     */
    private fun showStatusChip(text: String) {
        if (text.isEmpty()) return
        if (!hasOverlayPermission(this)) return
        val wm = windowManager ?: return
        val chip = statusChip ?: TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 12.5f
            maxLines = 3
            setPadding(dp(12), dp(7), dp(12), dp(7))
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(Color.argb(228, 16, 20, 32))
                setStroke(dp(1), Color.argb(170, 41, 182, 246))
            }
        }
        val params = statusChipParams ?: WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        chip.text = text
        val bubble = bubbleParams
        if (bubble != null) {
            params.x = max(0, bubble.x)
            params.y = bubble.y + dp(58)
        } else {
            params.x = dp(12)
            params.y = dp(220)
        }
        if (statusChip == null) {
            try {
                wm.addView(chip, params)
                statusChip = chip
                statusChipParams = params
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else {
            try {
                wm.updateViewLayout(chip, params)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun hideStatusChip() {
        val chip = statusChip ?: return
        statusChip = null
        statusChipParams = null
        try {
            windowManager?.removeView(chip)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // ── Kéo chọn vùng (XLAT-SCR-005) ──────────────────────────────────

    /**
     * Mở lớp phủ kéo chọn vùng.
     *
     * An toàn: view mới chỉ vẽ hình chữ nhật (không giữ ảnh); service gỡ nó
     * TRƯỚC khi chụp; mọi ngoại lệ đều quay về trạng thái bong bóng sẵn sàng
     * + thông báo, KHÔNG im lặng và KHÔNG để view mắc kẹt trên màn hình.
     */
    private fun beginRegionSelect() {
        if (regionView != null) return
        if (!hasOverlayPermission(this)) {
            onOverlayRevoked()
            return
        }
        val wm = windowManager ?: return
        if (overlayView != null) hideOverlay()
        setBubbleState(BubbleState.WORKING)
        showStatusChip(getString(R.string.screen_translate_region_selecting))
        val view = RegionSelectView(
            this,
            getString(R.string.screen_translate_region_hint),
            onRegionSelected = { rect -> onRegionChosen(rect) },
            onCancelled = { tooSmall ->
                mainHandler.post {
                    endRegionSelect()
                    hideStatusChip()
                    refreshBubbleLook()
                    tellUser(
                        getString(
                            if (tooSmall) {
                                R.string.screen_translate_region_too_small
                            } else {
                                R.string.screen_translate_region_cancelled
                            },
                        ),
                        haptic = false,
                    )
                }
            },
        )
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            wm.addView(view, params)
            regionView = view
        } catch (e: Exception) {
            // ROM chặn overlay hoặc mất quyền giữa chừng.
            e.printStackTrace()
            hideStatusChip()
            refreshBubbleLook()
            onOverlayRevoked()
        }
    }

    private fun endRegionSelect() {
        val view = regionView ?: return
        regionView = null
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Người dùng đã kéo xong: gỡ khung → chờ frame tổng hợp lại → chụp.
     *
     * Thà chậm 180ms còn hơn ảnh chụp dính lớp phủ tối (bản dịch sẽ sai vị trí
     * hoặc OCR ra rác).
     */
    private fun onRegionChosen(region: Rect) {
        mainHandler.post {
            if (capturing) {
                endRegionSelect()
                hideStatusChip()
                refreshBubbleLook()
                tellUser(getString(R.string.screen_translate_busy), haptic = false)
                return@post
            }
            endRegionSelect()
            pendingRegion = Rect(region)
            setBubbleState(BubbleState.WORKING)
            showStatusChip(getString(R.string.screen_translate_region_capturing))
            mainHandler.postDelayed({ captureOnce() }, REGION_CLEAR_DELAY_MS)
        }
    }

    /** Mọi nhánh của hàm này PHẢI có phản hồi nhìn thấy được. */
    private fun onBubbleTapped() {
        vibrate()
        if (!hasOverlayPermission(this)) {
            setBlockReason("overlay")
            openOverlaySettings()
            return
        }
        // Đang kéo chọn vùng ⇒ chạm bong bóng = HUỶ (không bao giờ im lặng).
        if (regionView != null) {
            endRegionSelect()
            hideStatusChip()
            refreshBubbleLook()
            tellUser(
                getString(R.string.screen_translate_region_cancelled),
                haptic = false,
            )
            return
        }
        if (overlayView != null) {
            hideOverlay()
            tellUser(getString(R.string.screen_translate_hidden), haptic = false)
            return
        }
        if (capturing) {
            // Đang dịch: nói cho user biết thay vì im lặng bỏ qua.
            tellUser(getString(R.string.screen_translate_busy), haptic = false)
            return
        }
        if (projection == null || imageReader == null) {
            pendingCaptureAfterConsent = true
            pendingRegionSelectAfterConsent = selectRegionMode
            requestConsent()
            return
        }
        if (selectRegionMode) {
            // Cấu hình "mỗi lần bấm: kéo chọn vùng".
            beginRegionSelect()
            return
        }
        captureOnce()
    }

    /**
     * Giữ lâu bong bóng ⇒ LUÔN mở chế độ kéo chọn vùng, bất kể công tắc trong
     * Cài đặt. Đây là đường tắt cho người dùng thỉnh thoảng mới cần dịch một
     * khung (không phải bật/tắt cấu hình).
     */
    private fun onBubbleLongPressed() {
        vibrate()
        if (!hasOverlayPermission(this)) {
            setBlockReason("overlay")
            openOverlaySettings()
            return
        }
        if (regionView != null) {
            endRegionSelect()
            hideStatusChip()
            refreshBubbleLook()
            tellUser(
                getString(R.string.screen_translate_region_cancelled),
                haptic = false,
            )
            return
        }
        if (capturing) {
            tellUser(getString(R.string.screen_translate_busy), haptic = false)
            return
        }
        if (projection == null || imageReader == null) {
            pendingCaptureAfterConsent = true
            pendingRegionSelectAfterConsent = true
            requestConsent()
            return
        }
        beginRegionSelect()
    }

    private class BubbleTouchListener(
        private val wm: WindowManager,
        private val params: WindowManager.LayoutParams,
        private val onTap: () -> Unit,
        private val onLongPress: () -> Unit,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var moved = false
        private var longPressFired = false

        /**
         * Giữ bong bóng [LONG_PRESS_MS] ⇒ mở khung kéo chọn vùng.
         *
         * Dùng `postDelayed` trên chính view (không phải Handler tĩnh) để khi
         * bong bóng bị gỡ, callback tự không còn cơ hội chạy sai ngữ cảnh.
         */
        private val longPress = Runnable {
            if (!moved && !longPressFired) {
                longPressFired = true
                onLongPress()
            }
        }

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    longPressFired = false
                    view.postDelayed(longPress, LONG_PRESS_MS)
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (abs(dx) > 12 || abs(dy) > 12) {
                        // Đã kéo ⇒ không phải giữ lâu, huỷ hẹn giờ.
                        if (!moved) view.removeCallbacks(longPress)
                        moved = true
                    }
                    params.x = startX + dx.toInt()
                    params.y = startY + dy.toInt()
                    try {
                        wm.updateViewLayout(view, params)
                    } catch (e: Exception) {
                        // Bong bóng có thể đã bị hệ thống gỡ (đổi user/ROM).
                        e.printStackTrace()
                    }
                    return true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    view.removeCallbacks(longPress)
                    if (!moved && !longPressFired) {
                        view.performClick()
                        onTap()
                    }
                    return true
                }
            }
            return false
        }

        companion object {
            /** Thời gian giữ để mở chế độ kéo chọn vùng (ms). */
            const val LONG_PRESS_MS = 450L
        }
    }

    // ──────────────────── đường xin consent (Android 10+) ─────────────

    /**
     * `ActivityOptions` cho phép [PendingIntent] mở activity dù app đang nền.
     *
     * Android 10+ CHẶN `Context.startActivity` từ nền (chỉ còn một dòng log
     * `ActivityTaskManager: Background activity start ...` rồi im lặng). Đường
     * được hệ thống cho phép là gửi một [PendingIntent]; từ API 34 phải OPT IN
     * bằng MODE_BACKGROUND_ACTIVITY_START_ALLOWED khi TẠO pending intent.
     */
    private fun backgroundActivityOptions(): Bundle? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ActivityOptions.makeBasic()
                .setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
                )
                .toBundle()
        } else {
            null
        }

    private fun consentPendingIntent(): PendingIntent =
        ScreenCaptureRequestActivity.newPendingIntent(this)

    private fun requestConsent() {
        if (!hasOverlayPermission(this)) {
            setBlockReason("overlay")
            openOverlaySettings()
            return
        }
        awaitingConsentUi = true
        pendingRecovery = Recovery.CONSENT
        updateNotification(getString(R.string.screen_translate_consent))
        try {
            consentPendingIntent().send()
        } catch (e: Exception) {
            // PendingIntent.CanceledException và bạn bè — không được im lặng.
            e.printStackTrace()
            onConsentBlocked()
            return
        }
        mainHandler.removeCallbacks(consentWatchdog)
        mainHandler.postDelayed(consentWatchdog, CONSENT_UI_TIMEOUT_MS)
    }

    /** Android đã nuốt lệnh mở màn hình xin quyền ⇒ chỉ đường khác cho user. */
    private fun onConsentBlocked() {
        awaitingConsentUi = false
        pendingCaptureAfterConsent = false
        pendingRegionSelectAfterConsent = false
        setBlockReason("consent_blocked")
        pendingRecovery = Recovery.CONSENT
        tellUser(getString(R.string.screen_translate_consent_blocked), alert = true)
    }

    private fun onOverlayRevoked() {
        if (isStopping) return
        // Bong bóng không vẽ được nữa ⇒ không có lý do giữ service sống.
        // Dừng TRƯỚC rồi mới báo: stopEverything huỷ thông báo đang hiển thị,
        // báo sau cùng thì hướng dẫn mới còn lại trên màn hình.
        stopEverything()
        // Đặt lý do SAU stopEverything (hàm đó gọi resetSessionFlags()).
        setBlockReason("overlay")
        reportOverlayMissing()
    }

    /**
     * PendingIntent mở activity TỪ NỀN (opt-in background-activity-start).
     *
     * IN4-17: Android 14+ **bắt buộc** PendingIntent phải MUTABLE khi dùng
     * `MODE_BACKGROUND_ACTIVITY_START_ALLOWED` — nếu kèm FLAG_IMMUTABLE thì
     * framework ném `IllegalArgumentException:
     * pendingIntentBackgroundActivityStartMode must not be set when creating a
     * PendingIntent` (log 18/10 còn hiện ở nhánh settings/recovery).
     *
     * Dùng MỘT helper cho MỌI nhánh (consent + mở Cài đặt overlay) để không
     * lặp lại pattern lỗi. Intent ở đây là nội bộ (không extra từ ngoài).
     */
    private fun backgroundActivityPendingIntent(
        requestCode: Int,
        intent: Intent,
    ): PendingIntent = PendingIntent.getActivity(
        this,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        backgroundActivityOptions(),
    )

    private fun launchOverlaySettingsActivity() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        try {
            backgroundActivityPendingIntent(REQ_OVERLAY, intent).send()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /** Service CÒN sống: thông báo thường + heads-up + toast + rung. */
    private fun openOverlaySettings() {
        pendingRecovery = Recovery.OVERLAY_SETTINGS
        launchOverlaySettingsActivity()
        tellUser(getString(R.string.screen_translate_overlay_revoked), alert = true)
    }

    /**
     * Service SẮP/KHÔNG chạy: không có notification thường để cập nhật ⇒
     * chỉ toast + rung + thông báo heads-up (đường thoát duy nhất cho user).
     *
     * Nhiều ROM Trung Quốc chặn deep-link Cài đặt nên LUÔN kèm lời hướng dẫn.
     */
    private fun reportOverlayMissing() {
        pendingRecovery = Recovery.OVERLAY_SETTINGS
        createAlertChannel()
        launchOverlaySettingsActivity()
        val text = getString(R.string.screen_translate_overlay_revoked)
        toast(text)
        vibrate()
        postAlert(text)
    }

    private fun handleConsent(intent: Intent) {
        awaitingConsentUi = false
        mainHandler.removeCallbacks(consentWatchdog)

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        if (resultCode != Activity.RESULT_OK || data == null) {
            // Từ chối / hủy: bubble vẫn sống (không crash), nói rõ cách thử lại.
            markConsentDenied()
            pendingCaptureAfterConsent = false
            pendingRegionSelectAfterConsent = false
            setBlockReason("consent_denied")
            pendingRecovery = Recovery.CONSENT
            refreshBubbleLook()
            tellUser(getString(R.string.screen_translate_consent_denied), alert = true)
            return
        }

        // Thứ tự BẮT BUỘC trên Android 14: startForeground(type=mediaProjection)
        // → getMediaProjection → createVirtualDisplay.
        val ok = ensureProjection(resultCode, data)
        refreshBubbleLook()
        if (!ok) {
            markConsentLost()
            pendingCaptureAfterConsent = false
            setBlockReason("capture_error")
            pendingRecovery = Recovery.CONSENT
            tellUser(getString(R.string.screen_translate_consent_retry), alert = true)
            return
        }

        pendingRecovery = Recovery.NONE
        if (pendingCaptureAfterConsent) {
            pendingCaptureAfterConsent = false
            if (pendingRegionSelectAfterConsent) {
                pendingRegionSelectAfterConsent = false
                beginRegionSelect()
            } else {
                captureOnce()
            }
        } else {
            updateNotification(notificationStatusText())
        }
    }

    // ───────────────────────── chụp màn hình ──────────────────────────

    /**
     * Tạo MediaProjection + VirtualDisplay MỘT LẦN cho cả phiên.
     *
     * Vì sao giữ ấm thay vì tạo/gỡ sau mỗi lần bấm: Android 14 ném
     * SecurityException nếu gọi `createVirtualDisplay` quá một lần trên cùng
     * một MediaProjection instance, và một token consent chỉ dùng được một lần.
     * Giữ một phiên chụp cho cả thời gian bật bong bóng ⇒ mỗi lần bấm chỉ việc
     * đọc frame mới nhất (cũng nhanh hơn, dễ đạt mốc ≤3s).
     */
    private fun ensureProjection(resultCode: Int, data: Intent): Boolean {
        releaseProjection()
        startForegroundCompat(mediaProjectionType = true)

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as? MediaProjectionManager
        if (manager == null) {
            logW("MediaProjectionManager không có trên máy này")
            return false
        }
        val proj = try {
            manager.getMediaProjection(resultCode, data)
        } catch (se: SecurityException) {
            // Sai thứ tự FGS / token đã dùng ⇒ Android 14 chặn.
            se.printStackTrace()
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
        if (proj == null) return false

        projection = proj
        proj.registerCallback(projectionCallback, mainHandler)
        markConsented()
        return startWarmDisplay(proj)
    }

    private fun startWarmDisplay(proj: MediaProjection): Boolean {
        val metrics = screenMetrics()
        val scale = captureScale(metrics.widthPixels, metrics.heightPixels)
        val width = max(1, (metrics.widthPixels * scale).toInt())
        val height = max(1, (metrics.heightPixels * scale).toInt())

        val reader = try {
            ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
        if (reader == null) {
            teardownProjectionOnly()
            return false
        }

        val vd = try {
            proj.createVirtualDisplay(
                "in4up-screen-translate",
                width,
                height,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                mainHandler,
            )
        } catch (se: SecurityException) {
            se.printStackTrace()
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
        if (vd == null) {
            try {
                reader.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
            teardownProjectionOnly()
            return false
        }

        imageReader = reader
        virtualDisplay = vd
        captureWidth = width
        captureHeight = height
        captureMetrics = metrics
        return true
    }

    private fun captureOnce() {
        if (capturing) return
        val reader = imageReader
        if (projection == null || reader == null) {
            // Phiên chụp đã mất (Android 14 thu hồi, user dừng chia sẻ) ⇒ xin lại.
            pendingCaptureAfterConsent = true
            requestConsent()
            return
        }
        capturing = true
        // Phản hồi TỨC THÌ (XLAT-SCR-005): bong bóng tím nhấp nháy + nhãn
        // "Đang nhận dạng chữ…" ngay dưới bong bóng. Owner báo trước đây bấm
        // xong không biết đã bấm trúng chưa nên phải bấm thêm.
        setBubbleState(BubbleState.WORKING)
        showStatusChip(getString(R.string.screen_translate_working))
        updateNotification(getString(R.string.screen_translate_working))

        val image = acquire(reader)
        if (image == null) {
            // VirtualDisplay vừa tạo chưa kịp có frame ⇒ thử lại MỘT lần.
            mainHandler.postDelayed(
                {
                    val retry = acquire(reader)
                    if (retry == null) {
                        capturing = false
                        // Bỏ vùng chọn đã dùng: không được để nó áp nhầm cho
                        // lượt chụp SAU (người dùng đã thấy lỗi).
                        pendingRegion = null
                        setBlockReason("capture_error")
                        val message = getString(R.string.screen_translate_error)
                        reportFailureToBubble(message)
                        tellUser(message)
                    } else {
                        deliverImage(retry)
                    }
                },
                FIRST_FRAME_RETRY_MS,
            )
            return
        }
        deliverImage(image)
    }

    private fun acquire(reader: ImageReader): Image? =
        try {
            reader.acquireLatestImage()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }

    private fun deliverImage(image: Image) {
        var rowStride = 0
        var bytes: ByteArray? = null
        try {
            val plane = image.planes[0]
            val buffer = plane.buffer
            // Đọc rowStride NGAY: `image.close()` chạy trước khi ta dùng lại
            // plane — chạm vào plane sau đó là dùng bộ nhớ đã trả.
            rowStride = plane.rowStride
            val out = ByteArray(buffer.remaining())
            buffer.get(out)
            bytes = out
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            try {
                image.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        val payload = bytes
        val metrics = captureMetrics
        if (payload == null || metrics == null) {
            capturing = false
            pendingRegion = null
            setBlockReason("capture_error")
            val message = getString(R.string.screen_translate_error)
            reportFailureToBubble(message)
            tellUser(message)
            return
        }
        sendFrameToDart(
            bytes = payload,
            width = captureWidth,
            height = captureHeight,
            rowStride = rowStride,
            screenWidth = metrics.widthPixels,
            screenHeight = metrics.heightPixels,
            density = metrics.density,
        )
    }

    private fun teardownProjectionOnly() {
        markConsentLost()
        try {
            virtualDisplay?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        virtualDisplay = null
        try {
            imageReader?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        imageReader = null
        captureMetrics = null
    }

    private fun releaseProjection() {
        teardownProjectionOnly()
        try {
            projection?.unregisterCallback(projectionCallback)
            projection?.stop()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        projection = null
        capturing = false
    }

    private fun captureScale(width: Int, height: Int): Float {
        val longest = max(width, height)
        if (longest <= MAX_CAPTURE_EDGE) return 1f
        return MAX_CAPTURE_EDGE.toFloat() / longest.toFloat()
    }

    @Suppress("DEPRECATION")
    private fun screenMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        val wm = windowManager ?: getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            val config = resources.displayMetrics
            metrics.widthPixels = bounds.width()
            metrics.heightPixels = bounds.height()
            metrics.density = config.density
            metrics.densityDpi = config.densityDpi
        } else {
            wm.defaultDisplay.getRealMetrics(metrics)
        }
        return metrics
    }

    // ───────────────────────── cầu sang Dart ──────────────────────────

    private fun sendFrameToDart(
        bytes: ByteArray,
        width: Int,
        height: Int,
        rowStride: Int,
        screenWidth: Int,
        screenHeight: Int,
        density: Float,
    ) {
        val channel = workerChannel
        if (channel == null) {
            capturing = false
            setBlockReason("engine")
            val message = getString(R.string.screen_translate_error)
            reportFailureToBubble(message)
            tellUser(message)
            return
        }
        val args = mutableMapOf<String, Any>(
            "pixels" to bytes,
            "width" to width,
            "height" to height,
            "rowStride" to rowStride,
            // ImageReader RGBA_8888: byte đi R,G,B,A → Dart hoán R/B thành
            // BGRA mà InputImage.fromBitmap khai báo.
            "alreadyBgra" to false,
            "screenWidth" to screenWidth,
            "screenHeight" to screenHeight,
            "devicePixelRatio" to density,
            "targetLanguage" to targetLanguage,
            // XLAT-SCR-005: ngôn ngữ NGUỒN + vùng kéo chọn (nếu có).
            "sourceLanguage" to sourceLanguage,
            "locale" to localeCode,
        )
        // Vùng chọn chỉ dùng cho ĐÚNG một lượt chụp — không để dính sang lượt
        // sau (người dùng bấm lần nữa mà vẫn bị cắt theo vùng cũ).
        val region = pendingRegion
        pendingRegion = null
        if (region != null && !region.isEmpty()) {
            args["regionLeft"] = region.left
            args["regionTop"] = region.top
            args["regionRight"] = region.right
            args["regionBottom"] = region.bottom
        }
        channel.invokeMethod(
            "onFrame",
            args,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    capturing = false
                    handleResult(result as? Map<*, *>)
                }

                override fun error(code: String, message: String?, details: Any?) {
                    capturing = false
                    setBlockReason("capture_error")
                    val text = message ?: getString(R.string.screen_translate_error)
                    reportFailureToBubble(text)
                    tellUser(text)
                }

                override fun notImplemented() {
                    capturing = false
                    setBlockReason("engine")
                    val message = getString(R.string.screen_translate_error)
                    reportFailureToBubble(message)
                    tellUser(message)
                }
            },
        )
    }

    private fun handleResult(result: Map<*, *>?) {
        if (result == null) {
            setBlockReason("capture_error")
            val message = getString(R.string.screen_translate_error)
            reportFailureToBubble(message)
            tellUser(message)
            return
        }
        val status = result["status"] as? String ?: "error"
        val message = result["message"] as? String ?: ""
        if (status != "ok") {
            // noText / missingModel / error / skipped: nói rõ thay vì im lặng.
            val text = message.ifEmpty { getString(R.string.screen_translate_idle) }
            reportFailureToBubble(text)
            tellUser(
                text,
                alert = status == "missingModel",
                haptic = false,
            )
            return
        }
        // Thành công: ✓ xanh trên bong bóng + nhãn biến mất.
        hideStatusChip()
        setBubbleState(BubbleState.DONE, BUBBLE_RESULT_HOLD_MS)

        val raw = result["blocks"] as? List<*> ?: emptyList<Any>()
        val blocks = raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            TranslationOverlayView.TranslatedBlock(
                left = (map["left"] as? Number)?.toInt() ?: return@mapNotNull null,
                top = (map["top"] as? Number)?.toInt() ?: return@mapNotNull null,
                right = (map["right"] as? Number)?.toInt() ?: return@mapNotNull null,
                bottom = (map["bottom"] as? Number)?.toInt() ?: return@mapNotNull null,
                original = map["original"] as? String ?: "",
                translation = map["translation"] as? String ?: "",
                textSizeSp = (map["textSizeSp"] as? Number)?.toFloat() ?: 14f,
            )
        }
        showOverlay(blocks)
        val engineName = result["engine"] as? String ?: ""
        updateNotification(
            if (engineName.isEmpty()) {
                getString(R.string.screen_translate_done)
            } else {
                getString(R.string.screen_translate_done_engine, engineName)
            },
        )
    }

    // ───────────────────────── overlay bản dịch ───────────────────────

    private fun showOverlay(blocks: List<TranslationOverlayView.TranslatedBlock>) {
        if (blocks.isEmpty()) {
            hideOverlay()
            return
        }
        if (!hasOverlayPermission(this)) {
            onOverlayRevoked()
            return
        }
        val wm = windowManager ?: return
        var view = overlayView
        if (view == null) {
            view = TranslationOverlayView(this)
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                overlayWindowType(),
                // KHÔNG nhận chạm: user vẫn cuộn/bấm được app bên dưới; muốn
                // tắt bản dịch thì bấm bong bóng (bong bóng nằm trên overlay).
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }
            try {
                wm.addView(view, params)
            } catch (e: Exception) {
                e.printStackTrace()
                onOverlayRevoked()
                return
            }
            overlayView = view
            // Bong bóng phải nằm TRÊN overlay: gỡ ra thêm lại để lên trên cùng.
            // IN4-17: đặt cờ `bubbleReordering` để detach do ta tự gây ra KHÔNG
            // bị hiểu nhầm là "quyền overlay bị thu hồi" (trước đó việc này
            // làm dừng cả phiên: overlay hiện xong bị dọn ngay).
            bubbleView?.let { bubble ->
                bubbleParams?.let { params2 ->
                    try {
                        bubbleReordering = true
                        wm.removeView(bubble)
                        wm.addView(bubble, params2)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    } finally {
                        bubbleReordering = false
                    }
                }
            }
        }
        view.setBlocks(blocks)
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        overlayView = null
    }

    private fun overlayWindowType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    // ─────────────────── phản hồi cho người dùng ──────────────────────

    /**
     * PHẢI gọi ở mọi nhánh thất bại: rung nhẹ + toast + notification.
     *
     * Toast được ưu tiên vì Android 13+ có thể CHƯA cấp POST_NOTIFICATIONS
     * (khi đó notification bị ẩn mà không ai báo) — toast chữ thuần vẫn hiện
     * được từ nền trên Android 11+ (chỉ toast custom bị chặn).
     */
    /**
     * Lỗi hiển thị NGAY TRÊN BONG BÓNG + nhãn: "!" đỏ trong 1.4s rồi trở lại
     * trạng thái sẵn sàng. Toast/notification vẫn do [tellUser] lo — ba kênh
     * phản hồi vì máy có thể tắt thông báo hoặc che toast.
     */
    private fun reportFailureToBubble(message: String) {
        setBubbleState(BubbleState.ERROR, BUBBLE_RESULT_HOLD_MS)
        showStatusChip(message)
        mainHandler.postDelayed({
            // Không ẩn nhãn của lượt MỚI vừa bắt đầu.
            if (bubbleState != BubbleState.WORKING) hideStatusChip()
        }, BUBBLE_RESULT_HOLD_MS)
    }

    private fun tellUser(text: String, alert: Boolean = false, haptic: Boolean = true) {
        updateNotification(text)
        toast(text)
        if (haptic) vibrate()
        if (alert) postAlert(text)
    }

    private fun toast(text: String) {
        mainHandler.post {
            try {
                Toast.makeText(applicationContext, text, Toast.LENGTH_LONG).show()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        try {
            val vibrator: Vibrator? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(VibratorManager::class.java)?.defaultVibrator
                } else {
                    getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(
                    VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE),
                )
            } else {
                vibrator?.vibrate(45)
            }
        } catch (e: Exception) {
            // Rung là trang trí — thiếu thì thôi, không được làm hỏng luồng.
            e.printStackTrace()
        }
    }

    private fun notificationStatusText(): String =
        if (captureConsented && projection != null) {
            getString(R.string.screen_translate_idle)
        } else if (consentDenied) {
            getString(R.string.screen_translate_consent_denied)
        } else {
            getString(R.string.screen_translate_idle_consent)
        }

    // ───────────────────────── notification ───────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.screen_translate_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * Kênh riêng cho trường hợp "cần user thao tác mới tiếp tục được".
     *
     * IMPORTANCE_HIGH ⇒ hiện heads-up; user bấm vào thông báo là hệ thống GỬI
     * pending intent (được miễn chặn background activity start) ⇒ mở được
     * activity xin consent dù app đang nền. Đây là đường dự phòng khi
     * [consentPendingIntent] bị hệ thống nuốt.
     */
    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ALERT_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ALERT_ID,
            getString(R.string.screen_translate_alert_channel),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setShowBadge(false)
            setSound(null, null)
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val stopIntent = Intent(this, ScreenTranslateService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            REQ_STOP,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        // Bấm vào thông báo thường cũng phải "làm được việc": khi user bấm,
        // HỆ THỐNG là bên gửi pending intent ⇒ được miễn chặn background
        // activity start (đường thoát chắc chắn nhất khi bong bóng bị chặn).
        // IN4-17: TẠO pending intent phải được bọc try/catch — nếu lỗi (vd
        // sai flag API 34+), notification vẫn phải hiện, KHÔNG được để
        // exception thoát ra giết service ngay giữa nhánh báo lỗi cho user.
        val recovery = safeRecoveryPendingIntent()
        if (recovery != null) builder.setContentIntent(recovery)
        return builder
            .setContentTitle(getString(R.string.screen_translate_title))
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    // null Icon: overload (Icon?, CharSequence, PendingIntent)
                    // — ép kiểu tường minh để Kotlin không phân vân với
                    // overload (int, CharSequence, PendingIntent) đã deprecated.
                    null as android.graphics.drawable.Icon?,
                    getString(R.string.screen_translate_stop),
                    stopPending,
                ).build(),
            )
            .build()
    }

    /**
     * Tạo PendingIntent "recovery" an toàn (IN4-17): mọi lỗi tạo PendingIntent
     * đều bị nuốt kèm log + blockReason — KHÔNG bao giờ thoát ra ngoài làm
     * chết service (log 18/10: chính helper này gây FATAL EXCEPTION ở cả 3
     * nhánh notification/alert/handleConsent).
     */
    private fun safeRecoveryPendingIntent(): PendingIntent? =
        try {
            when (pendingRecovery) {
                Recovery.CONSENT -> consentPendingIntent()
                Recovery.OVERLAY_SETTINGS -> overlaySettingsPendingIntent()
                Recovery.NONE -> null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            setBlockReason("pending_intent_error")
            null
        }

    /** Thông báo heads-up có thể bấm — đường thoát khi không mở được activity. */
    private fun postAlert(text: String) {
        val content = safeRecoveryPendingIntent()
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ALERT_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle(getString(R.string.screen_translate_title))
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setAutoCancel(true)
        if (content != null) builder.setContentIntent(content)
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.notify(NOTIFICATION_ALERT_ID, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun cancelAlert() {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.cancel(NOTIFICATION_ALERT_ID)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun overlaySettingsPendingIntent(): PendingIntent =
        backgroundActivityPendingIntent(
            REQ_OVERLAY,
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )

    private fun startForegroundCompat(mediaProjectionType: Boolean) {
        val notification = buildNotification(notificationStatusText())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = if (mediaProjectionType) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
            if (type == 0) {
                startForeground(NOTIFICATION_ID, notification)
            } else {
                startForeground(NOTIFICATION_ID, notification, type)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun logW(message: String) {
        android.util.Log.w("In4UpScreenTranslate", message)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
