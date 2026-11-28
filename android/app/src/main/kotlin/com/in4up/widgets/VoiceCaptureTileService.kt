package com.in4up.widgets

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.in4up.MainActivity

// PLAN-050 · ADR-0040 — Ô Cài đặt nhanh (Quick Settings Tile) cho «I4U Ghi chú nói».
// 1 chạm từ thanh thông báo mở thẳng QuickCaptureSheet và bắt đầu thu âm STT ngay.
class VoiceCaptureTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("in4up://action/voice_capture?autostart=1&src=qs_tile"),
        ).apply {
            setPackage(packageName)
            setClass(this@VoiceCaptureTileService, MainActivity::class.java)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this,
                9202,
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
