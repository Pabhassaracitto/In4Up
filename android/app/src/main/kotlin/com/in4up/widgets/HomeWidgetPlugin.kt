package com.in4up.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import com.in4up.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// PLAN-050 · ADR-0040 — Cầu nối MethodChannel("in4up/home_widget") gắn vào MainActivity.
// Hỗ trợ đồng bộ snapshot JSON, truy vấn số lượng widget và hộp thoại ghim 1 chạm.
class HomeWidgetPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, CHANNEL_NAME)
        ch.setMethodCallHandler(this)
        channel = ch
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncSnapshot" -> {
                val rawJson = call.argument<String>("json")
                if (rawJson.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                val appCtx = context.applicationContext
                HomeWidgetStore.saveSnapshotJson(appCtx, rawJson)
                val parsed = HomeWidgetStore.load(appCtx)
                HomeWidgetStore.refreshAllWidgets(appCtx)
                HomeWidgetStore.syncDynamicShortcuts(appCtx, parsed)
                result.success(true)
            }
            "getStatus" -> {
                val appCtx = context.applicationContext
                val manager = AppWidgetManager.getInstance(appCtx)
                val counts = mapOf(
                    "quick_bar" to countWidgets(appCtx, manager, "quick_bar"),
                    "continue_learning" to countWidgets(appCtx, manager, "continue_learning"),
                    "flashcard_srs" to countWidgets(appCtx, manager, "flashcard_srs"),
                    "streak_pulse" to countWidgets(appCtx, manager, "streak_pulse"),
                )
                val pinSupported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        manager.isRequestPinAppWidgetSupported
                    } catch (_: Exception) {
                        false
                    }
                } else {
                    false
                }
                result.success(
                    mapOf(
                        "requestPinSupported" to pinSupported,
                        "counts" to counts,
                    ),
                )
            }
            "requestPinWidget" -> {
                val kind = call.argument<String>("kind") ?: ""
                result.success(requestPinWidget(kind))
            }
            "requestPinShortcut" -> {
                val id = call.argument<String>("id") ?: ""
                val shortLabel = call.argument<String>("shortLabel") ?: ""
                val deepLink = call.argument<String>("deepLink") ?: ""
                val iconKey = call.argument<String>("iconKey") ?: "sparkle"
                result.success(requestPinShortcut(id, shortLabel, deepLink, iconKey))
            }
            else -> result.notImplemented()
        }
    }

    private fun countWidgets(
        appCtx: Context,
        manager: AppWidgetManager,
        kind: String,
    ): Int {
        val component = HomeWidgetStore.providerComponentForKind(appCtx, kind) ?: return 0
        return try {
            manager.getAppWidgetIds(component)?.size ?: 0
        } catch (_: Exception) {
            0
        }
    }

    private fun requestPinWidget(kind: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val appCtx = context.applicationContext
        val component = HomeWidgetStore.providerComponentForKind(appCtx, kind) ?: return false
        return try {
            val manager = AppWidgetManager.getInstance(appCtx)
            if (!manager.isRequestPinAppWidgetSupported) return false
            manager.requestPinAppWidget(component, null, null)
        } catch (_: Exception) {
            false
        }
    }

    private fun requestPinShortcut(
        id: String,
        shortLabel: String,
        deepLink: String,
        iconKey: String,
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (id.isBlank() || shortLabel.isBlank() || deepLink.isBlank()) return false
        val appCtx = context.applicationContext
        return try {
            val shortcutManager =
                appCtx.getSystemService(ShortcutManager::class.java) ?: return false
            if (!shortcutManager.isRequestPinShortcutSupported) return false
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                setPackage(appCtx.packageName)
                setClass(appCtx, MainActivity::class.java)
            }
            val iconRes = HomeWidgetStore.iconResForKey(iconKey)
            val info = ShortcutInfo.Builder(appCtx, id)
                .setShortLabel(shortLabel.take(24))
                .setLongLabel(shortLabel.take(48))
                .setIcon(Icon.createWithResource(appCtx, iconRes))
                .setIntent(intent)
                .build()
            shortcutManager.requestPinShortcut(info, null)
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val CHANNEL_NAME = "in4up/home_widget"
    }
}
