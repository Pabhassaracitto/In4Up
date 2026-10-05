package com.in4up.screentranslate

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * XLAT-SCR-002 — channel ĐIỀU KHIỂN "in4up/screentranslate".
 *
 * Chạy trong engine UI (đăng ký từ [com.in4up.MainActivity]). Chỉ làm 3 việc:
 * kiểm tra/khai quyền overlay, bật/tắt [ScreenTranslateService], đổi ngôn ngữ
 * đích. Toàn bộ phần chụp/vẽ nằm trong service; phần OCR + dịch nằm ở Dart
 * (ADR-0011: chụp + vẽ ở native, hiểu chữ + dịch ở Dart).
 *
 * Không có method nào chạm model hay mạng — luật vàng "không tải model ngoài
 * thao tác user" không liên quan ở tầng này, nhưng cũng không được phá.
 */
class ScreenTranslatePlugin(
    private val activity: Activity,
) {
    companion object {
        const val CHANNEL = "in4up/screentranslate"

        /** API 23+ mới có SYSTEM_ALERT_WINDOW kiểu "Settings bật tay". */
        fun hasOverlayPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Settings.canDrawOverlays(context)
    }

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> onMethodCall(call, result) }
        channel = ch
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(
                // MediaProjection có từ API 21, overlay bubble cần API 23 để
                // xin quyền qua Settings; minSdk của app là 24 nên luôn đủ.
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M,
            )

            "hasOverlayPermission" -> result.success(hasOverlayPermission(activity))

            "requestOverlayPermission" -> result.success(openOverlaySettings())

            "isRunning" -> result.success(ScreenTranslateService.isRunning)

            "start" -> {
                if (!hasOverlayPermission(activity)) {
                    // KHÔNG tự mở Settings ở đây: Dart phải hiện giải thích
                    // trước (vì sao cần quyền) rồi mới gọi request.
                    result.success(false)
                    return
                }
                val target = call.argument<String>("targetLanguage") ?: "VI"
                val locale = call.argument<String>("locale") ?: "vi"
                val intent = Intent(activity, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_START
                    putExtra(ScreenTranslateService.EXTRA_TARGET_LANGUAGE, target)
                    putExtra(ScreenTranslateService.EXTRA_LOCALE, locale)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(true)
            }

            "stop" -> {
                val intent = Intent(activity, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_STOP
                }
                activity.startService(intent)
                result.success(true)
            }

            "setTargetLanguage" -> {
                val target = call.argument<String>("targetLanguage") ?: "VI"
                val intent = Intent(activity, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_SET_TARGET
                    putExtra(ScreenTranslateService.EXTRA_TARGET_LANGUAGE, target)
                }
                activity.startService(intent)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun openOverlaySettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            // Một số ROM Trung Quốc chặn deep-link này → Dart hướng dẫn tay.
            e.printStackTrace()
            false
        }
    }
}
