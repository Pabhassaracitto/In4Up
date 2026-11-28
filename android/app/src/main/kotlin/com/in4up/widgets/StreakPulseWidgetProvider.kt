package com.in4up.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import com.in4up.R

// PLAN-050 · ADR-0040 — Widget 4: Nhịp Điệu & Chuỗi Ngày Học (2x2 / 4x2).
// Hiển thị chuỗi ngày học liên tiếp + 7 cột hoạt động thật + 1 nút CTA ngữ cảnh.
class StreakPulseWidgetProvider : AppWidgetProvider() {
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
        private val DAY_PILL_IDS = intArrayOf(
            R.id.day_pill_0,
            R.id.day_pill_1,
            R.id.day_pill_2,
            R.id.day_pill_3,
            R.id.day_pill_4,
            R.id.day_pill_5,
            R.id.day_pill_6,
        )

        private val DAY_LABEL_IDS = intArrayOf(
            R.id.day_lbl_0,
            R.id.day_lbl_1,
            R.id.day_lbl_2,
            R.id.day_lbl_3,
            R.id.day_lbl_4,
            R.id.day_lbl_5,
            R.id.day_lbl_6,
        )

        fun updateAll(context: Context, manager: AppWidgetManager) {
            val component = ComponentName(context, StreakPulseWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_streak_pulse)
            views.setTextViewText(R.id.txt_streak_headline, snapshot.streakHeadline)
            views.setTextViewText(R.id.txt_streak_today, snapshot.streakTodaySummary)
            views.setTextViewText(R.id.btn_streak_cta, snapshot.streakCtaLabel)

            for (idx in 0 until 7) {
                val bar = snapshot.streakBars.getOrNull(idx) ?: 0.0
                val dayLabel = snapshot.streakDayLabels.getOrNull(idx) ?: "-"
                val drawableRes = when {
                    bar >= 0.5 -> R.drawable.bg_widget_day_high
                    bar > 0.1 -> R.drawable.bg_widget_day_low
                    else -> R.drawable.bg_widget_day_idle
                }
                views.setImageViewResource(DAY_PILL_IDS[idx], drawableRes)
                views.setTextViewText(DAY_LABEL_IDS[idx], dayLabel)
            }

            val ctaPending = HomeWidgetStore.deepLinkPendingIntent(
                context,
                snapshot.streakCtaDeepLink,
                requestSeed = widgetId + 300,
            )
            views.setOnClickPendingIntent(R.id.btn_streak_cta, ctaPending)
            views.setOnClickPendingIntent(
                R.id.widget_streak_root,
                HomeWidgetStore.deepLinkPendingIntent(
                    context,
                    "in4up://nav/studio?target=home&src=widget",
                    requestSeed = widgetId + 301,
                ),
            )
            return views
        }
    }
}
