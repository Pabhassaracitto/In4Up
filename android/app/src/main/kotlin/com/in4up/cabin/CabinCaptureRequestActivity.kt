package com.in4up.cabin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle

/** One consent per capture. This activity must be opened while the app is visible. */
class CabinCaptureRequestActivity : Activity() {
    companion object {
        private const val REQUEST_CAPTURE = 0x6C11
        fun newIntent(context: Context): Intent = Intent(context, CabinCaptureRequestActivity::class.java)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated Activity is still waiting for the original result.
        if (savedInstanceState != null) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || CabinSystemAudioService.listener == null) {
            CabinSystemAudioService.listener?.onError("unavailable")
            finish()
            return
        }
        try {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            @Suppress("DEPRECATION")
            startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CAPTURE)
        } catch (_: Exception) {
            CabinSystemAudioService.listener?.onError("consent_unavailable")
            finish()
        }
    }

    @Deprecated("MediaProjection consent uses the Activity result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CAPTURE) return
        if (resultCode != RESULT_OK || data == null) {
            CabinSystemAudioService.listener?.onError("consent_denied")
            finish()
            return
        }
        try {
            val service = Intent(this, CabinSystemAudioService::class.java).apply {
                action = CabinSystemAudioService.ACTION_START
                putExtra(CabinSystemAudioService.EXTRA_RESULT_CODE, resultCode)
                putExtra(CabinSystemAudioService.EXTRA_RESULT_DATA, data)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(service)
            else startService(service)
        } catch (_: Exception) {
            CabinSystemAudioService.listener?.onError("service_unavailable")
        }
        finish()
    }
}
