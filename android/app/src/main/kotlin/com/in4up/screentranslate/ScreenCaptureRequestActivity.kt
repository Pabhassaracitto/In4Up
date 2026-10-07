package com.in4up.screentranslate

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle

/**
 * XLAT-SCR-002 / XLAT-SCR-003 — activity TRONG SUỐT chỉ để xin consent
 * MediaProjection.
 *
 * Vì sao cần: `MediaProjectionManager.createScreenCaptureIntent()` phải được
 * `startActivityForResult` từ một Activity — service không làm được. Bong bóng
 * nằm ngoài app nên khi user bấm, ta mở activity này (không giao diện, không
 * animation) để hệ thống hiện hộp thoại "Bắt đầu ghi/truyền màn hình?".
 *
 * ⚠️ Android 10+ CHẶN `Context.startActivity` từ nền (chỉ một dòng log
 * `ActivityTaskManager: Background activity start ...` rồi im lặng) — đó là
 * nguyên nhân "chạm bong bóng không có gì xảy ra" (XLAT-SCR-003). Vì vậy
 * activity này CHỈ được mở bằng [newPendingIntent] (PendingIntent có opt-in
 * `MODE_BACKGROUND_ACTIVITY_START_ALLOWED`) hoặc từ `MainActivity` khi app còn
 * ở foreground. Đừng đổi lại thành `context.startActivity(intent)`.
 *
 * Android 14+ (API 34): consent có hiệu lực cho MỘT phiên projection. Tắt
 * bong bóng rồi bật lại ⇒ hệ thống hỏi lại — đúng tiêu chí nghiệm thu #5.
 * KHÔNG lưu lại `resultData` để tái dùng cho phiên sau (bị chặn và sai luật).
 */
class ScreenCaptureRequestActivity : Activity() {

    companion object {
        private const val REQUEST_CODE = 0x5C21

        fun newIntent(context: Context): Intent =
            Intent(context, ScreenCaptureRequestActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
            }

        /**
         * PendingIntent mở activity này TỪ NỀN.
         *
         * API 34+ bắt OPT IN: truyền `ActivityOptions` với
         * `MODE_BACKGROUND_ACTIVITY_START_ALLOWED` LÚC TẠO pending intent
         * (truyền lúc `send()` cũng được nhưng tạo sẵn gọn hơn và đúng với
         * khuyến nghị của tài liệu Android 14).
         */
        fun newPendingIntent(context: Context): android.app.PendingIntent {
            val options =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    android.app.ActivityOptions.makeBasic()
                        .setPendingIntentBackgroundActivityStartMode(
                            android.app.ActivityOptions
                                .MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
                        )
                        .toBundle()
                } else {
                    null
                }
            return android.app.PendingIntent.getActivity(
                context,
                REQUEST_CODE,
                newIntent(context),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
                options,
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Báo cho service biết activity ĐÃ lên foreground thật — nếu không có
        // tín hiệu này, watchdog của service kết luận "Android đã chặn mở
        // activity" và hiện hướng dẫn thay vì im lặng.
        signalConsentUiShown()

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as? MediaProjectionManager
        if (manager == null) {
            deliver(RESULT_CANCELED, null)
            return
        }
        try {
            startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CODE)
        } catch (e: Exception) {
            e.printStackTrace()
            deliver(RESULT_CANCELED, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CODE) return
        deliver(resultCode, data)
    }

    private fun signalConsentUiShown() {
        val intent = Intent(this, ScreenTranslateService::class.java).apply {
            action = ScreenTranslateService.ACTION_CONSENT_UI_SHOWN
        }
        try {
            startService(intent)
        } catch (e: IllegalStateException) {
            // Chặn "background service start" (Android 8+) — activity vừa bật
            // lên nên hiếm khi xảy ra, nhưng nếu có thì vẫn phải gửi được tin.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                }
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun deliver(resultCode: Int, data: Intent?) {
        val intent = Intent(this, ScreenTranslateService::class.java).apply {
            action = ScreenTranslateService.ACTION_CONSENT_RESULT
            putExtra(ScreenTranslateService.EXTRA_RESULT_CODE, resultCode)
            if (data != null) {
                putExtra(ScreenTranslateService.EXTRA_RESULT_DATA, data)
            }
        }
        // Service đang chạy foreground rồi nên startService là đủ; dùng
        // startForegroundService ở đây sẽ đòi startForeground lần nữa trong
        // 5 giây — không cần thiết.
        try {
            startService(intent)
        } catch (e: IllegalStateException) {
            // Chặn background service start: ưu tiên gửi được kết quả bằng
            // mọi giá, nếu không user sẽ không bao giờ biết consent thành công.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                }
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        finish()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }
}
