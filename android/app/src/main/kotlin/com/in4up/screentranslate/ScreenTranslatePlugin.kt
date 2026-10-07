package com.in4up.screentranslate

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * XLAT-SCR-002 / XLAT-SCR-003 — channel ĐIỀU KHIỂN "in4up/screentranslate".
 *
 * Chạy trong engine UI (đăng ký từ [com.in4up.MainActivity]). Chỉ làm 4 việc:
 * kiểm tra/khai quyền overlay, bật/tắt [ScreenTranslateService], đổi ngôn ngữ
 * đích, và trả TRẠNG THÁI QUYỀN để Dart quyết định bong bóng có sẵn sàng hay
 * đang ở trạng thái "cần thiết lập". Toàn bộ phần chụp/vẽ nằm trong service;
 * phần OCR + dịch nằm ở Dart (ADR-0011: chụp + vẽ ở native, hiểu chữ + dịch
 * ở Dart).
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
            ScreenTranslateService.hasOverlayPermission(context)
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

            /**
             * Trạng thái QUYỀN đầy đủ — Dart dùng để hiện đúng hướng dẫn thay
             * vì để user bấm bong bóng rồi không thấy gì (XLAT-SCR-003).
             */
            "status" -> result.success(statusMap())

            /**
             * Xin consent MediaProjection NGAY — chỉ gọi khi app đang ở
             * foreground (màn hình Cài đặt). Đây là đường CHÍNH: không vướng
             * chặn "background activity start" của Android 10+.
             */
            "requestConsent" -> result.success(requestConsentFromActivity())

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
                // App vẫn còn ở foreground tại thời điểm này ⇒ mở activity xin
                // consent được HỢP PHÁP (không bị Android 10+ chặn). Bong bóng
                // vì thế đã "sẵn sàng" ngay từ lần bấm đầu tiên; đường dự
                // phòng (PendingIntent từ bong bóng) chỉ dùng khi consent bị
                // thu hồi giữa phiên.
                if (!ScreenTranslateService.captureConsented) {
                    requestConsentFromActivity()
                }
                result.success(true)
            }

            "stop" -> {
                val intent = Intent(activity, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_STOP
                }
                try {
                    activity.startService(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                result.success(true)
            }

            "setTargetLanguage" -> {
                val target = call.argument<String>("targetLanguage") ?: "VI"
                val intent = Intent(activity, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_SET_TARGET
                    putExtra(ScreenTranslateService.EXTRA_TARGET_LANGUAGE, target)
                }
                try {
                    activity.startService(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Map trạng thái gửi sang Dart. Khoá phải KHỚP với
     * `ScreenTranslateNativeStatus.fromMap` (có test khoá tên).
     */
    private fun statusMap(): Map<String, Any?> = mapOf(
        "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M),
        "overlayGranted" to hasOverlayPermission(activity),
        "running" to ScreenTranslateService.isRunning,
        "captureConsented" to ScreenTranslateService.captureConsented,
        "consentDenied" to ScreenTranslateService.consentDenied,
        "notificationsEnabled" to notificationsEnabled(),
        // Chỉ hiện cảnh báo "bị chặn" trên các mức API có chặn thật.
        "blockedBySystem" to (
            !ScreenTranslateService.captureConsented &&
                ScreenTranslateService.lastBlockReason == "consent_blocked"
            ),
        "blockReason" to ScreenTranslateService.lastBlockReason,
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    /**
     * Android 13+ ẩn notification nếu chưa cấp POST_NOTIFICATIONS ⇒ service
     * vẫn chạy mà user KHÔNG thấy gì cả (một dạng "im lặng"). Dart dùng cờ
     * này để xin quyền trước khi bật.
     */
    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val manager = activity.getSystemService(NotificationManager::class.java)
        return manager?.areNotificationsEnabled() ?: true
    }

    private fun requestConsentFromActivity(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            activity.startActivity(ScreenCaptureRequestActivity.newIntent(activity))
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
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
