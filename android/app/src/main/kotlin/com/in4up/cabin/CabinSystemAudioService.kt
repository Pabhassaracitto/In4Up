package com.in4up.cabin

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs
import com.in4up.R

/**
 * Foreground playback capture. The caller installs a per-session listener
 * before requesting consent and invalidates it when the engine detaches.
 * PCM and errors may arrive on different threads: a Flutter bridge MUST post
 * events to the main thread. The service never persists projection tokens.
 */
class CabinSystemAudioService : Service() {
    interface Listener {
        fun onStarted()
        fun onPcm(data: ByteArray)
        fun onError(code: String)
        fun onStopped()
    }

    companion object {
        const val ACTION_START = "com.in4up.cabin.START"
        const val ACTION_STOP = "com.in4up.cabin.STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"
        const val EXTRA_REQUEST_ID = "requestId"
        const val EXTRA_OVERLAY = "overlay"
        private const val CHANNEL = "in4up_cabin_audio"
        private const val NOTIFICATION = 0x6C12
        @Volatile var listener: Listener? = null
        @Volatile private var requestId = 0L
        @Volatile private var runningService: CabinSystemAudioService? = null

        @Synchronized fun newRequest(): Long { requestId += 1; return requestId }
        @Synchronized fun cancelRequest() { requestId += 1 }
        fun isCurrent(id: Long): Boolean = requestId == id
        fun updateCaption(text: String) {
            val service = runningService ?: return
            service.main.post { service.setCaption(text) }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    @Volatile private var stopping = false
    @Volatile private var record: AudioRecord? = null
    private var projection: MediaProjection? = null
    private var worker: Thread? = null
    private var active = false
    private var ownerListener: Listener? = null
    private var overlay: TextView? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var expanded = true
    private var caption = ""
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            if (!stopping) fail("projection_stopped")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START || active) return START_NOT_STICKY
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            fail("unsupported")
            return START_NOT_STICKY
        }
        @Suppress("DEPRECATION")
        val data = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val id = intent.getLongExtra(EXTRA_REQUEST_ID, -1)
        if (!isCurrent(id)) { stopSelf(); return START_NOT_STICKY }
        if (data == null || resultCode != Activity.RESULT_OK || listener == null ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            fail("permission_or_consent")
            return START_NOT_STICKY
        }
        ownerListener = listener
        try {
            // Android 14 requires a user-granted token before starting the
            // mediaProjection FGS, and that FGS before getMediaProjection.
            startCaptureForeground()
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val p = manager.getMediaProjection(resultCode, data)
                ?: throw IllegalStateException("MediaProjection unavailable")
            projection = p
            p.registerCallback(projectionCallback, main)
            val config = AudioPlaybackCaptureConfiguration.Builder(p)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
            val format = AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
            val minimum = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT)
            if (minimum <= 0) throw IllegalStateException("AudioRecord unsupported")
            val recorder = AudioRecord.Builder().setAudioFormat(format)
                .setBufferSizeInBytes(maxOf(minimum, 6400))
                .setAudioPlaybackCaptureConfig(config).build()
            record = recorder
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                throw IllegalStateException("AudioRecord initialization failed")
            }
            recorder.startRecording()
            if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                throw IllegalStateException("AudioRecord did not start")
            }
            if (intent.getBooleanExtra(EXTRA_OVERLAY, false)) showOverlay()
            active = true
            runningService = this
            ownerListener?.onStarted()
            worker = Thread({ readLoop(recorder) }, "cabin-playback-capture").also { it.start() }
        } catch (_: Exception) {
            fail("capture_failed")
        }
        return START_NOT_STICKY
    }

    private fun readLoop(recorder: AudioRecord) {
        val buffer = ByteArray(3200)
        try {
            while (!stopping) {
                val count = recorder.read(buffer, 0, buffer.size)
                if (count < 0) {
                    if (!stopping) main.post { fail("read_failed") }
                    return
                }
                if (count > 0) {
                    val target = ownerListener
                    if (target == null || listener !== target) {
                        main.post { stopSelf() }
                        return
                    }
                    target.onPcm(buffer.copyOf(count))
                }
            }
        } catch (_: Exception) {
            if (!stopping) main.post { fail("read_failed") }
        }
    }

    private fun fail(code: String) {
        if (stopping) return
        (ownerListener ?: listener)?.onError(code)
        stopSelf()
    }

    private fun startCaptureForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(CHANNEL,
            getString(R.string.cabin_audio_channel), NotificationManager.IMPORTANCE_LOW))
        val stop = PendingIntent.getService(this, NOTIFICATION,
            Intent(this, CabinSystemAudioService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(getString(R.string.cabin_audio_notification_title))
            .setContentText(getString(R.string.cabin_audio_notification_body))
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, getString(R.string.cabin_audio_stop), stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION, notification)
        }
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) throw SecurityException("Overlay permission denied")
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        val view = TextView(this).apply {
            text = "In4Up"
            setTextColor(Color.WHITE)
            textSize = 15f
            maxLines = 5
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.rgb(30, 37, 65))
                cornerRadius = dp(16).toFloat()
                setStroke(dp(1), Color.rgb(0, 230, 118))
            }
        }
        val params = WindowManager.LayoutParams(
            dp(260), WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START; x = dp(20); y = dp(160) }
        var startX = 0
        var startY = 0
        var downX = 0f
        var downY = 0f
        var moved = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x; startY = params.y
                    downX = event.rawX; downY = event.rawY; moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX; val dy = event.rawY - downY
                    if (abs(dx) + abs(dy) > dp(8)) moved = true
                    if (moved) {
                        params.x = startX + dx.toInt(); params.y = startY + dy.toInt()
                        try { wm.updateViewLayout(view, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        expanded = !expanded
                        params.width = dp(if (expanded) 260 else 60)
                        setCaption(caption)
                        try { wm.updateViewLayout(view, params) } catch (_: Exception) {}
                    }
                    true
                }
                else -> false
            }
        }
        wm.addView(view, params)
        overlay = view
        overlayParams = params
    }

    private fun setCaption(value: String) {
        caption = value
        overlay?.text = if (!expanded || value.isBlank()) "In4Up" else value
    }

    override fun onDestroy() {
        stopping = true
        if (runningService === this) runningService = null
        overlay?.let {
            try { (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(it) }
            catch (_: Exception) {}
        }
        overlay = null
        overlayParams = null
        try { record?.stop() } catch (_: Exception) {}
        try { worker?.join(1000) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
        try { record?.release() } catch (_: Exception) {}
        record = null
        projection?.unregisterCallback(projectionCallback)
        projection?.stop()
        projection = null
        active = false
        ownerListener?.onStopped()
        ownerListener = null
        super.onDestroy()
    }
}
