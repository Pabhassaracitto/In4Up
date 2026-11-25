package com.in4up.cabin

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** UI-engine bridge. Every capture gets fresh consent and a bounded event queue. */
class CabinSystemAudioPlugin(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var busy = false
    private var generation = 0L

    fun attach(messenger: BinaryMessenger) {
        methods = MethodChannel(messenger, "in4up/cabin_system_audio").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(activity))
                    "requestOverlayPermission" -> {
                        try {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:${activity.packageName}")))
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                    "start" -> {
                        val showOverlay = call.argument<Boolean>("overlay") ?: false
                        if (busy || sink == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                            (showOverlay && !Settings.canDrawOverlays(activity))) {
                            result.success(false)
                        } else {
                            val id = CabinSystemAudioService.newRequest()
                            generation = id
                            busy = true
                            CabinSystemAudioService.listener = newListener(id)
                            try {
                                activity.startActivity(CabinCaptureRequestActivity.newIntent(activity, id, showOverlay))
                                result.success(true)
                            } catch (_: Exception) {
                                stop()
                                result.success(false)
                            }
                        }
                    }
                    "updateCaption" -> {
                        CabinSystemAudioService.updateCaption(call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "stop" -> { stop(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        events = EventChannel(messenger, "in4up/cabin_system_audio_events").also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    sink = eventSink
                    eventSink.success("ready")
                }
                override fun onCancel(arguments: Any?) { stop(); sink = null }
            })
        }
    }

    private fun newListener(id: Long): CabinSystemAudioService.Listener {
        val queued = AtomicInteger(0)
        val failed = AtomicBoolean(false)
        fun emitError(code: String) {
            if (!failed.compareAndSet(false, true)) return
            main.post {
                if (generation == id && busy) {
                    sink?.error(code, code, null)
                    stop()
                }
            }
        }
        return object : CabinSystemAudioService.Listener {
            override fun onStarted() {
                main.post { if (generation == id && busy) sink?.success("started") }
            }
            override fun onPcm(data: ByteArray) {
                if (failed.get()) return
                if (queued.incrementAndGet() > 30) {
                    queued.decrementAndGet()
                    emitError("event_overflow")
                    return
                }
                main.post {
                    queued.decrementAndGet()
                    if (generation == id && busy && !failed.get()) sink?.success(data)
                }
            }
            override fun onError(code: String) = emitError(code)
            override fun onStopped() {
                main.post {
                    if (generation == id && busy && !failed.get()) stop()
                }
            }
        }
    }

    private fun stop() {
        // Invalidate a still-visible consent dialog; a late result must never
        // start a capture that the user already cancelled.
        CabinSystemAudioService.cancelRequest()
        generation = 0
        busy = false
        CabinSystemAudioService.listener = null
        try { activity.stopService(Intent(activity, CabinSystemAudioService::class.java)) }
        catch (_: Exception) {}
        sink?.endOfStream()
        sink = null
    }

    fun detach() {
        stop()
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
    }
}
