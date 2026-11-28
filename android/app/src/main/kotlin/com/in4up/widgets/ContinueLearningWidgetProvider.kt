package com.in4up.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.in4up.R

// PLAN-050 · ADR-0040 — Widget 2: Tiếp Tục Học (4x2).
// Mở lại đúng bài nghe / Pháp thoại và tài liệu PDF / văn bản đang dở với 1 chạm.
class ContinueLearningWidgetProvider : AppWidgetProvider() {
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
            val component = ComponentName(context, ContinueLearningWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_continue_learning)
            views.setTextViewText(R.id.txt_continue_header, snapshot.continueHeader)
            views.setTextViewText(R.id.txt_continue_due_badge, snapshot.dueBadge)
            views.setOnClickPendingIntent(
                R.id.txt_continue_due_badge,
                HomeWidgetStore.deepLinkPendingIntent(
                    context,
                    "in4up://action/review_due?mode=srs&src=widget",
                    requestSeed = widgetId + 100,
                ),
            )

            val listen = snapshot.resumeListen
            val read = snapshot.resumeRead
            if (listen == null && read == null) {
                views.setViewVisibility(R.id.box_continue_items, View.GONE)
                views.setViewVisibility(R.id.box_continue_empty, View.VISIBLE)
                views.setTextViewText(R.id.txt_continue_empty_hint, snapshot.continueEmptyHint)
                views.setTextViewText(R.id.btn_empty_open_read, snapshot.openReadLabel)
                views.setTextViewText(R.id.btn_empty_open_listen, snapshot.openListenLabel)
                views.setOnClickPendingIntent(
                    R.id.btn_empty_open_read,
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        "in4up://nav/studio?target=read&src=widget",
                        requestSeed = widgetId + 101,
                    ),
                )
                views.setOnClickPendingIntent(
                    R.id.btn_empty_open_listen,
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        "in4up://nav/studio?target=listen&src=widget",
                        requestSeed = widgetId + 102,
                    ),
                )
                return views
            }

            views.setViewVisibility(R.id.box_continue_items, View.VISIBLE)
            views.setViewVisibility(R.id.box_continue_empty, View.GONE)

            if (listen != null) {
                views.setViewVisibility(R.id.row_resume_listen, View.VISIBLE)
                views.setTextViewText(R.id.txt_listen_title, listen.title)
                views.setTextViewText(R.id.txt_listen_subtitle, listen.subtitle)
                views.setProgressBar(R.id.bar_listen_progress, 100, listen.progressPercent, false)
                views.setImageViewResource(
                    R.id.img_listen_action,
                    if (listen.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
                )
                views.setOnClickPendingIntent(
                    R.id.row_resume_listen,
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        listen.deepLink,
                        requestSeed = widgetId + 103,
                    ),
                )
            } else {
                views.setViewVisibility(R.id.row_resume_listen, View.GONE)
            }

            if (read != null) {
                views.setViewVisibility(R.id.row_resume_read, View.VISIBLE)
                views.setTextViewText(R.id.txt_read_title, read.title)
                views.setTextViewText(R.id.txt_read_subtitle, read.subtitle)
                views.setProgressBar(R.id.bar_read_progress, 100, read.progressPercent, false)
                views.setOnClickPendingIntent(
                    R.id.row_resume_read,
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        read.deepLink,
                        requestSeed = widgetId + 104,
                    ),
                )
            } else {
                views.setViewVisibility(R.id.row_resume_read, View.GONE)
            }

            return views
        }
    }
}
