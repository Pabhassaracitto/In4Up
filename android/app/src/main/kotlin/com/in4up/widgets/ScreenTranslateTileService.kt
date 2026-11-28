package com.in4up.widgets

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.in4up.MainActivity
import com.in4up.screentranslate.ScreenTranslateService

// PLAN-050 · ADR-0040 — Ô Cài đặt nhanh (Quick Settings Tile) cho «I4U Dịch màn hình».
// Kéo thanh thông báo từ bất kỳ ứng dụng nào → 1 chạm tắt nếu đang bật, hoặc mở luồng
// bật bong bóng an toàn trên Android 7..16 (targetSdk 35 dùng overload PendingIntent).
class ScreenTranslateTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        syncTileState()
    }

    override fun onClick() {
        super.onClick()
        if (ScreenTranslateService.isRunning) {
            try {
                val stopIntent = Intent(this, ScreenTranslateService::class.java).apply {
                    action = ScreenTranslateService.ACTION_STOP
                }
                startService(stopIntent)
            } catch (_: Exception) {
                // Nếu hệ thống đã dừng service, chỉ cần đồng bộ lại trạng thái ô.
            }
            qsTile?.let { tile ->
                tile.state = Tile.STATE_INACTIVE
                tile.updateTile()
            }
            return
        }

        launchDeepLinkAndCollapse(
            deepLinkUri = "in4up://action/screen_translate?src=qs_tile",
            requestCode = 9201,
        )
    }

    private fun syncTileState() {
        val tile = qsTile ?: return
        tile.state = if (ScreenTranslateService.isRunning) {
            Tile.STATE_ACTIVE
        } else {
            Tile.STATE_INACTIVE
        }
        tile.updateTile()
    }

    private fun launchDeepLinkAndCollapse(deepLinkUri: String, requestCode: Int) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUri)).apply {
            setPackage(packageName)
            setClass(this@ScreenTranslateTileService, MainActivity::class.java)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
