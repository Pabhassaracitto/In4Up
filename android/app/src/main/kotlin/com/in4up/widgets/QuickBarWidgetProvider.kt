package com.in4up.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import com.in4up.R

// PLAN-050 · ADR-0040 — Widget 1: Thanh Lệnh Nhanh (4x1 / 4x2).
// 1 chạm tra từ điển + 3 nút công cụ tùy chọn của người dùng.
class QuickBarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val snapshot = HomeWidgetStore.load(context)
        for (widgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                widgetId,
                buildRemoteViews(context, snapshot, widgetId),
            )
        }
    }

    companion object {
        fun updateAll(context: Context, manager: AppWidgetManager) {
            val component = ComponentName(context, QuickBarWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component) ?: return
            if (ids.isEmpty()) return
            val snapshot = HomeWidgetStore.load(context)
            for (widgetId in ids) {
                manager.updateAppWidget(
                    widgetId,
                    buildRemoteViews(context, snapshot, widgetId),
                )
            }
        }

        private fun buildRemoteViews(
            context: Context,
            snapshot: HomeWidgetStore.ParsedSnapshot,
            widgetId: Int,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_bar)
            views.setTextViewText(R.id.txt_search_hint, snapshot.searchHint)

            views.setOnClickPendingIntent(
                R.id.btn_brand_home,
                HomeWidgetStore.deepLinkPendingIntent(
                    context,
                    "in4up://nav/studio?target=home&src=widget",
                    requestSeed = widgetId + 1,
                ),
            )
            views.setOnClickPendingIntent(
                R.id.btn_search_pill,
                HomeWidgetStore.deepLinkPendingIntent(
                    context,
                    "in4up://action/dict_search?autofocus=1&src=widget",
                    requestSeed = widgetId + 2,
                ),
            )

            val slotButtons = intArrayOf(R.id.btn_slot_1, R.id.btn_slot_2, R.id.btn_slot_3)
            val slotImages = intArrayOf(R.id.img_slot_1, R.id.img_slot_2, R.id.img_slot_3)
            for (idx in 0 until 3) {
                val slot = snapshot.quickSlots.getOrNull(idx) ?: continue
                views.setImageViewResource(
                    slotImages[idx],
                    HomeWidgetStore.iconResForKey(slot.iconKey),
                )
                views.setContentDescription(slotImages[idx], slot.label)
                views.setOnClickPendingIntent(
                    slotButtons[idx],
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        slot.deepLink,
                        requestSeed = widgetId + 10 + idx,
                    ),
                )
            }
            return views
        }
    }
}
