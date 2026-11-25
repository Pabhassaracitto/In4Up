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
import com.in4up.R

/**
 * Foreground playback capture, not wired to Flutter yet. A caller must install
 * a listener before requesting consent and clear it when the engine detaches.
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
        private const val CHANNEL = "in4up_cabin_audio"
        private const val NOTIFICATION = 0x6C12
        @Volatile var listener: Listener? = null
    }

    private val main = Handler(Looper.getMainLooper())
    @Volatile private var stopping = false
    @Volatile private var record: AudioRecord? = null
    private var projection: MediaProjection? = null
    private var worker: Thread? = null
    private var active = false
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
        if (data == null || resultCode != Activity.RESULT_OK || listener == null ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            fail("permission_or_consent")
            return START_NOT_STICKY
        }
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
            active = true
            listener?.onStarted()
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
                    val target = listener
                    if (target == null) {
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
        listener?.onError(code)
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

    override fun onDestroy() {
        stopping = true
        try { record?.stop() } catch (_: Exception) {}
        try { worker?.join(1000) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
        try { record?.release() } catch (_: Exception) {}
        record = null
        projection?.unregisterCallback(projectionCallback)
        projection?.stop()
        projection = null
        active = false
        listener?.onStopped()
        super.onDestroy()
    }
}
