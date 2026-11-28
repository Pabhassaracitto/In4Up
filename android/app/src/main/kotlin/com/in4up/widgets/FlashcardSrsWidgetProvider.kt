package com.in4up.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.in4up.R

// PLAN-050 · ADR-0040 — Widget 3: Thẻ Từ & Vườn Trí Nhớ (4x2).
// Hỗ trợ lật nghĩa và chuyển từ NGAY TRÊN MÀN HÌNH CHÍNH (không mở app),
// đồng thời giữ tách biệt 3 thanh SM-2 Hiểu · Nghe · Đọc (Quy tắc vàng #2).
class FlashcardSrsWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_FLIP_CARD -> {
                HomeWidgetStore.toggleFlashcardFlip(context)
                updateAll(context, AppWidgetManager.getInstance(context))
            }
            ACTION_NEXT_CARD -> {
                val deckSize = HomeWidgetStore.load(context).deck.size
                HomeWidgetStore.advanceFlashcard(context, deckSize)
                updateAll(context, AppWidgetManager.getInstance(context))
            }
        }
    }

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
        const val ACTION_FLIP_CARD = "com.in4up.widgets.ACTION_FLIP_CARD"
        const val ACTION_NEXT_CARD = "com.in4up.widgets.ACTION_NEXT_CARD"

        fun updateAll(context: Context, manager: AppWidgetManager) {
            val component = ComponentName(context, FlashcardSrsWidgetProvider::class.java)
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

        private fun selfBroadcastPendingIntent(
            context: Context,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, FlashcardSrsWidgetProvider::class.java).apply {
                this.action = action
                setPackage(context.packageName)
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun buildRemoteViews(
            context: Context,
            snapshot: HomeWidgetStore.ParsedSnapshot,
            widgetId: Int,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_flashcard_srs)
            views.setTextViewText(R.id.txt_garden_header, snapshot.gardenHeader)
            views.setTextViewText(R.id.txt_srs_due_badge, snapshot.dueBadge)
            views.setTextViewText(R.id.lbl_skill_understand, snapshot.skillUnderstand)
            views.setTextViewText(R.id.lbl_skill_listen, snapshot.skillListen)
            views.setTextViewText(R.id.lbl_skill_read, snapshot.skillRead)
            views.setTextViewText(R.id.btn_next_card, snapshot.nextCardLabel)
            views.setTextViewText(R.id.btn_review_now, snapshot.reviewNowLabel)

            val reviewIntent = HomeWidgetStore.deepLinkPendingIntent(
                context,
                "in4up://action/review_due?mode=srs&src=widget",
                requestSeed = widgetId + 200,
            )
            views.setOnClickPendingIntent(R.id.btn_review_now, reviewIntent)
            views.setOnClickPendingIntent(R.id.txt_srs_due_badge, reviewIntent)

            val deck = snapshot.deck
            if (deck.isEmpty()) {
                views.setTextViewText(R.id.txt_card_word, "—")
                views.setTextViewText(R.id.txt_card_ipa, "")
                views.setTextViewText(R.id.txt_card_meaning, snapshot.srsEmptyHint)
                views.setViewVisibility(R.id.row_three_skills, View.GONE)
                views.setViewVisibility(R.id.btn_flip_card, View.GONE)
                views.setViewVisibility(R.id.btn_next_card, View.GONE)
                views.setOnClickPendingIntent(
                    R.id.box_srs_card_body,
                    HomeWidgetStore.deepLinkPendingIntent(
                        context,
                        "in4up://nav/studio?target=remember&src=widget",
                        requestSeed = widgetId + 201,
                    ),
                )
                return views
            }

            views.setViewVisibility(R.id.row_three_skills, View.VISIBLE)
            views.setViewVisibility(R.id.btn_flip_card, View.VISIBLE)
            views.setViewVisibility(
                R.id.btn_next_card,
                if (deck.size > 1) View.VISIBLE else View.GONE,
            )

            val cardIndex = HomeWidgetStore.getFlashcardIndex(context) % deck.size
            val card = deck[cardIndex]
            val flipped = HomeWidgetStore.isFlashcardFlipped(context)

            views.setTextViewText(R.id.txt_card_word, card.word)
            val ipaDisplay = if (card.ipa.isNotEmpty()) {
                if (card.ipa.startsWith("/")) card.ipa else "/${card.ipa}/"
            } else {
                "${cardIndex + 1}/${deck.size}"
            }
            views.setTextViewText(R.id.txt_card_ipa, ipaDisplay)

            val meaningText = if (flipped) {
                if (card.example.isNotEmpty() && card.meaning.isNotEmpty()) {
                    "${card.meaning} · ${card.example}"
                } else if (card.meaning.isNotEmpty()) {
                    card.meaning
                } else {
                    card.example
                }
            } else {
                "•••  (${snapshot.flipShowLabel})"
            }
            views.setTextViewText(R.id.txt_card_meaning, meaningText)
            views.setTextViewText(
                R.id.btn_flip_card,
                if (flipped) snapshot.flipHideLabel else snapshot.flipShowLabel,
            )

            views.setProgressBar(R.id.bar_skill_understand, 100, card.understandPercent, false)
            views.setProgressBar(R.id.bar_skill_listen, 100, card.listenPercent, false)
            views.setProgressBar(R.id.bar_skill_read, 100, card.readPercent, false)

            val flipPending = selfBroadcastPendingIntent(context, ACTION_FLIP_CARD, 7101)
            views.setOnClickPendingIntent(R.id.btn_flip_card, flipPending)
            views.setOnClickPendingIntent(R.id.box_srs_card_body, flipPending)
            views.setOnClickPendingIntent(
                R.id.btn_next_card,
                selfBroadcastPendingIntent(context, ACTION_NEXT_CARD, 7102),
            )
            return views
        }
    }
}
