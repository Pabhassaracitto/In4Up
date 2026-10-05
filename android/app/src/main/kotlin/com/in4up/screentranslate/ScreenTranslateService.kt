package com.in4up.screentranslate

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
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
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
 * XLAT-SCR-002 / ADR-0011 — "Dịch màn hình toàn hệ thống" (Android).
 *
 * Foreground service giữ:
 *  1. **Bong bóng** (TYPE_APPLICATION_OVERLAY) kéo được, bấm = chụp 1 lần.
 *  2. **MediaProjection + ImageReader** → một frame RGBA_8888.
 *  3. **Engine Flutter NỀN** (FlutterEngineGroup, entrypoint
 *     `screenTranslateMain`) để OCR + dịch bằng đúng OcrService /
 *     TranslationService của app — KHÔNG viết engine dịch thứ hai.
 *  4. **Overlay bản dịch** ([TranslationOverlayView]) vẽ đè theo bbox.
 *
 * Luật đã chốt, đừng "tối ưu" ngược:
 *  - Mỗi lần bấm = MỘT lần chụp. Không vòng lặp capture (P1) → không đốt pin.
 *  - Android 14+: consent MediaProjection xin lại mỗi phiên; không lưu
 *    `resultData` để tái dùng.
 *  - FGS đổi type: bật bong bóng = `specialUse`; có consent rồi mới nâng lên
 *    `mediaProjection` (Android 14 chặn type mediaProjection khi chưa có token).
 *  - Tắt = dừng projection + gỡ overlay + huỷ notification + destroy engine.
 *
 * ⚠️ Phần này CHƯA chạy trên thiết bị trong sandbox (không có Flutter SDK /
 * Android SDK) — chờ nghiệm thu máy thật theo mục 5 của card.
 */
class ScreenTranslateService : Service() {

    companion object {
        const val ACTION_START = "com.in4up.screentranslate.START"
        const val ACTION_STOP = "com.in4up.screentranslate.STOP"
        const val ACTION_CONSENT_RESULT = "com.in4up.screentranslate.CONSENT"
        const val ACTION_SET_TARGET = "com.in4up.screentranslate.SET_TARGET"

        const val EXTRA_TARGET_LANGUAGE = "targetLanguage"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"

        private const val CHANNEL_ID = "in4up_screen_translate"
        private const val NOTIFICATION_ID = 0x5C22

        /** Cạnh dài nhất của ảnh chụp — OCR không cần full 1440p. */
        private const val MAX_CAPTURE_EDGE = 1920

        /** Dart entrypoint của engine nền. */
        private const val DART_LIBRARY =
            "package:in4up/features/screen_translate/screen_translate_entrypoint.dart"
        private const val DART_ENTRYPOINT = "screenTranslateMain"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var windowManager: WindowManager? = null
    private var bubbleView: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var overlayView: TranslationOverlayView? = null

    private var engine: FlutterEngine? = null
    private var workerChannel: MethodChannel? = null
    private var workerReady = false

    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null

    private var targetLanguage: String = "VI"
    private var localeCode: String = "vi"
    private var capturing = false
    private var pendingCaptureAfterConsent = false

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // User bấm "Dừng chia sẻ" ở thanh thông báo hệ thống.
            mainHandler.post {
                releaseProjection()
                hideOverlay()
                updateNotification(getString(R.string.screen_translate_idle))
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
                return START_STICKY
            }

            ACTION_CONSENT_RESULT -> {
                handleConsent(intent)
                return START_STICKY
            }

            else -> {
                intent?.getStringExtra(EXTRA_TARGET_LANGUAGE)?.let { targetLanguage = it }
                intent?.getStringExtra(EXTRA_LOCALE)?.let { localeCode = it }
                startBubbleSession()
                return START_STICKY
            }
        }
    }

    // ───────────────────────── vòng đời phiên ─────────────────────────

    private fun startBubbleSession() {
        if (isRunning) {
            updateNotification(getString(R.string.screen_translate_idle))
            return
        }
        createNotificationChannel()
        startForegroundCompat(mediaProjectionType = false)
        isRunning = true
        showBubble()
        ensureEngine()
    }

    private fun stopEverything() {
        isRunning = false
        releaseProjection()
        hideOverlay()
        removeBubble()
        destroyEngine()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        releaseProjection()
        hideOverlay()
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
            updateNotification(getString(R.string.screen_translate_error))
        }
    }

    private fun destroyEngine() {
        workerChannel?.setMethodCallHandler(null)
        workerChannel = null
        workerReady = false
        engine?.destroy()
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
                if (stage.isNotEmpty()) updateNotification(stage)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ───────────────────────── bong bóng ──────────────────────────────

    private fun showBubble() {
        if (bubbleView != null) return
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

        bubble.setOnTouchListener(BubbleTouchListener(wm, params) { onBubbleTapped() })

        try {
            wm.addView(bubble, params)
            bubbleView = bubble
            bubbleParams = params
        } catch (e: Exception) {
            // Mất quyền overlay giữa chừng (user thu hồi trong Settings).
            e.printStackTrace()
            stopEverything()
        }
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        bubbleView = null
        bubbleParams = null
    }

    /** Bấm bong bóng: đang hiện bản dịch ⇒ tắt; chưa ⇒ chụp một lần. */
    private fun onBubbleTapped() {
        if (overlayView != null) {
            hideOverlay()
            return
        }
        if (capturing) return
        if (projection == null) {
            pendingCaptureAfterConsent = true
            requestConsent()
            return
        }
        captureOnce()
    }

    private class BubbleTouchListener(
        private val wm: WindowManager,
        private val params: WindowManager.LayoutParams,
        private val onTap: () -> Unit,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var moved = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (abs(dx) > 12 || abs(dy) > 12) moved = true
                    params.x = startX + dx.toInt()
                    params.y = startY + dy.toInt()
                    try {
                        wm.updateViewLayout(view, params)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    return true
                }

                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        view.performClick()
                        onTap()
                    }
                    return true
                }
            }
            return false
        }
    }

    // ───────────────────────── chụp màn hình ──────────────────────────

    private fun requestConsent() {
        updateNotification(getString(R.string.screen_translate_consent))
        try {
            startActivity(ScreenCaptureRequestActivity.newIntent(this))
        } catch (e: Exception) {
            e.printStackTrace()
            updateNotification(getString(R.string.screen_translate_error))
        }
    }

    private fun handleConsent(intent: Intent) {
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        if (resultCode != android.app.Activity.RESULT_OK || data == null) {
            pendingCaptureAfterConsent = false
            updateNotification(getString(R.string.screen_translate_idle))
            return
        }

        // Android 14: PHẢI đang ở FGS type mediaProjection trước khi lấy
        // projection, nếu không getMediaProjection ném SecurityException.
        startForegroundCompat(mediaProjectionType = true)

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as? MediaProjectionManager
        projection = try {
            manager?.getMediaProjection(resultCode, data)?.also {
                it.registerCallback(projectionCallback, mainHandler)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
        if (projection == null) {
            updateNotification(getString(R.string.screen_translate_error))
            return
        }
        if (pendingCaptureAfterConsent) {
            pendingCaptureAfterConsent = false
            captureOnce()
        }
    }

    private fun captureOnce() {
        val proj = projection ?: return
        if (capturing) return
        capturing = true
        updateNotification(getString(R.string.screen_translate_working))

        val metrics = screenMetrics()
        val screenWidth = metrics.widthPixels
        val screenHeight = metrics.heightPixels
        val scale = captureScale(screenWidth, screenHeight)
        val captureWidth = max(1, (screenWidth * scale).toInt())
        val captureHeight = max(1, (screenHeight * scale).toInt())

        val reader = ImageReader.newInstance(
            captureWidth,
            captureHeight,
            PixelFormat.RGBA_8888,
            2,
        )
        imageReader = reader

        var delivered = false
        reader.setOnImageAvailableListener({ r ->
            if (delivered) return@setOnImageAvailableListener
            val image = try {
                r.acquireLatestImage()
            } catch (e: Exception) {
                e.printStackTrace()
                null
            } ?: return@setOnImageAvailableListener
            delivered = true
            try {
                val plane = image.planes[0]
                val buffer = plane.buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                // Đọc rowStride NGAY: `image.close()` ở finally chạy TRƯỚC
                // runnable dưới đây, chạm vào plane sau đó là dùng bộ nhớ đã
                // trả (cùng bài học "dùng pixels sau dispose" của PDF export).
                val rowStride = plane.rowStride
                mainHandler.post {
                    teardownCapture()
                    sendFrameToDart(
                        bytes = bytes,
                        width = captureWidth,
                        height = captureHeight,
                        rowStride = rowStride,
                        screenWidth = screenWidth,
                        screenHeight = screenHeight,
                        density = metrics.density,
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
                mainHandler.post {
                    teardownCapture()
                    capturing = false
                    updateNotification(getString(R.string.screen_translate_error))
                }
            } finally {
                try {
                    image.close()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }, mainHandler)

        virtualDisplay = try {
            proj.createVirtualDisplay(
                "in4up-screen-translate",
                captureWidth,
                captureHeight,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                mainHandler,
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }

        if (virtualDisplay == null) {
            teardownCapture()
            capturing = false
            updateNotification(getString(R.string.screen_translate_error))
        }
    }

    /** Gỡ VirtualDisplay + ImageReader NGAY sau khi lấy được 1 frame. */
    private fun teardownCapture() {
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
    }

    private fun releaseProjection() {
        teardownCapture()
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
            updateNotification(getString(R.string.screen_translate_error))
            return
        }
        val args = mapOf(
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
            "locale" to localeCode,
        )
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
                    updateNotification(message ?: getString(R.string.screen_translate_error))
                }

                override fun notImplemented() {
                    capturing = false
                    updateNotification(getString(R.string.screen_translate_error))
                }
            },
        )
    }

    private fun handleResult(result: Map<*, *>?) {
        if (result == null) {
            updateNotification(getString(R.string.screen_translate_error))
            return
        }
        val status = result["status"] as? String ?: "error"
        val message = result["message"] as? String ?: ""
        if (status != "ok") {
            // noText / missingModel / error / skipped: nói rõ trong
            // notification thay vì im lặng (luật "đừng im lặng").
            updateNotification(
                message.ifEmpty { getString(R.string.screen_translate_idle) },
            )
            return
        }

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
                return
            }
            overlayView = view
            // Bong bóng phải nằm TRÊN overlay: gỡ ra thêm lại để lên trên cùng.
            bubbleView?.let { bubble ->
                bubbleParams?.let { params2 ->
                    try {
                        wm.removeView(bubble)
                        wm.addView(bubble, params2)
                    } catch (e: Exception) {
                        e.printStackTrace()
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

    private fun buildNotification(text: String): Notification {
        val stopIntent = Intent(this, ScreenTranslateService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
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

    private fun startForegroundCompat(mediaProjectionType: Boolean) {
        val notification = buildNotification(getString(R.string.screen_translate_idle))
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

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
