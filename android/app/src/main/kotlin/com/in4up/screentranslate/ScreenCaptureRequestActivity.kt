package com.in4up.screentranslate

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle

/**
 * XLAT-SCR-002 — activity TRONG SUỐT chỉ để xin consent MediaProjection.
 *
 * Vì sao cần: `MediaProjectionManager.createScreenCaptureIntent()` phải được
 * `startActivityForResult` từ một Activity — service không làm được. Bong bóng
 * nằm ngoài app nên khi user bấm, ta mở activity này (không giao diện, không
 * animation) để hệ thống hiện hộp thoại "Bắt đầu ghi/truyền màn hình?".
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
