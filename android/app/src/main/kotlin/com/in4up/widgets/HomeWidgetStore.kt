package com.in4up.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import com.in4up.MainActivity
import com.in4up.R
import org.json.JSONArray
import org.json.JSONObject

// PLAN-050 · ADR-0040 — Kho lưu & bộ đọc JSON phẳng cho toàn bộ Home Screen Widgets.
// Không khởi tạo Flutter Engine, Hive hay SQLite: chỉ đọc SharedPreferences trong < 2 ms.
object HomeWidgetStore {
    private const val PREFS_NAME = "in4up_home_widgets_v1"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val KEY_FLASHCARD_INDEX = "flashcard_index"
    private const val KEY_FLASHCARD_FLIPPED = "flashcard_flipped"

    data class QuickSlot(
        val id: String,
        val label: String,
        val iconKey: String,
        val deepLink: String,
    )

    data class ResumeRow(
        val title: String,
        val subtitle: String,
        val progressPercent: Int,
        val isPlaying: Boolean,
        val deepLink: String,
    )

    data class FlashcardCard(
        val word: String,
        val ipa: String,
        val meaning: String,
        val example: String,
        val understandPercent: Int,
        val listenPercent: Int,
        val readPercent: Int,
    )

    data class ParsedSnapshot(
        val searchHint: String,
        val continueHeader: String,
        val continueEmptyHint: String,
        val openReadLabel: String,
        val openListenLabel: String,
        val gardenHeader: String,
        val srsEmptyHint: String,
        val flipShowLabel: String,
        val flipHideLabel: String,
        val nextCardLabel: String,
        val reviewNowLabel: String,
        val skillUnderstand: String,
        val skillListen: String,
        val skillRead: String,
        val dueBadge: String,
        val streakHeadline: String,
        val streakTodaySummary: String,
        val streakBars: List<Double>,
        val streakDayLabels: List<String>,
        val streakCtaLabel: String,
        val streakCtaDeepLink: String,
        val resumeListen: ResumeRow?,
        val resumeRead: ResumeRow?,
        val dueTotalCount: Int,
        val deck: List<FlashcardCard>,
        val quickSlots: List<QuickSlot>,
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveSnapshotJson(context: Context, rawJson: String) {
        prefs(context)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, rawJson)
            .apply()
    }

    fun getFlashcardIndex(context: Context): Int =
        prefs(context).getInt(KEY_FLASHCARD_INDEX, 0).coerceAtLeast(0)

    fun isFlashcardFlipped(context: Context): Boolean =
        prefs(context).getBoolean(KEY_FLASHCARD_FLIPPED, false)

    fun toggleFlashcardFlip(context: Context) {
        val current = isFlashcardFlipped(context)
        prefs(context).edit().putBoolean(KEY_FLASHCARD_FLIPPED, !current).apply()
    }

    fun advanceFlashcard(context: Context, deckSize: Int) {
        val next = if (deckSize <= 0) 0 else (getFlashcardIndex(context) + 1) % deckSize
        prefs(context)
            .edit()
            .putInt(KEY_FLASHCARD_INDEX, next)
            .putBoolean(KEY_FLASHCARD_FLIPPED, false)
            .apply()
    }

    fun load(context: Context): ParsedSnapshot {
        val raw = prefs(context).getString(KEY_SNAPSHOT_JSON, null)
        val root = try {
            if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }

        val labels = root.optJSONObject("labels") ?: JSONObject()
        val streak = root.optJSONObject("streak") ?: JSONObject()
        val resume = root.optJSONObject("resume") ?: JSONObject()
        val srs = root.optJSONObject("srs") ?: JSONObject()

        val dueVocab = srs.optInt("dueVocabCount", 0)
        val dueLhb = srs.optInt("dueLhbCount", 0)
        val totalDue = (dueVocab + dueLhb).coerceAtLeast(0)

        return ParsedSnapshot(
            searchHint = labels.optNonBlank(
                "searchHint",
                context.getString(R.string.widget_default_search_hint),
            ),
            continueHeader = labels.optNonBlank(
                "continueHeader",
                context.getString(R.string.widget_default_continue_header),
            ),
            continueEmptyHint = labels.optNonBlank(
                "continueEmptyHint",
                context.getString(R.string.widget_default_continue_empty),
            ),
            openReadLabel = labels.optNonBlank(
                "openReadLabel",
                context.getString(R.string.widget_default_read),
            ),
            openListenLabel = labels.optNonBlank(
                "openListenLabel",
                context.getString(R.string.widget_default_listen),
            ),
            gardenHeader = labels.optNonBlank(
                "gardenHeader",
                context.getString(R.string.widget_default_garden_header),
            ),
            srsEmptyHint = labels.optNonBlank(
                "srsEmptyHint",
                context.getString(R.string.widget_default_srs_empty),
            ),
            flipShowLabel = labels.optNonBlank(
                "flipShowLabel",
                context.getString(R.string.widget_default_flip_show),
            ),
            flipHideLabel = labels.optNonBlank(
                "flipHideLabel",
                context.getString(R.string.widget_default_flip_hide),
            ),
            nextCardLabel = labels.optNonBlank(
                "nextCardLabel",
                context.getString(R.string.widget_default_next_card),
            ),
            reviewNowLabel = labels.optNonBlank(
                "reviewNowLabel",
                context.getString(R.string.widget_default_review_now),
            ),
            skillUnderstand = labels.optNonBlank(
                "skillUnderstand",
                context.getString(R.string.widget_default_understand),
            ),
            skillListen = labels.optNonBlank(
                "skillListen",
                context.getString(R.string.widget_default_listen),
            ),
            skillRead = labels.optNonBlank(
                "skillRead",
                context.getString(R.string.widget_default_read),
            ),
            dueBadge = labels.optNonBlank("dueCountBadge", totalDue.toString()),
            streakHeadline = streak.optNonBlank(
                "headline",
                context.getString(R.string.widget_default_streak_headline),
            ),
            streakTodaySummary = streak.optNonBlank(
                "todaySummary",
                context.getString(R.string.widget_default_streak_today),
            ),
            streakBars = parseDoubleList(streak.optJSONArray("weekBars")),
            streakDayLabels = parseStringList(streak.optJSONArray("weekDayLabels")),
            streakCtaLabel = streak.optNonBlank(
                "ctaLabel",
                context.getString(R.string.widget_default_start_learning),
            ),
            streakCtaDeepLink = streak.optNonBlank(
                "ctaDeepLink",
                "in4up://nav/studio?target=home&src=widget",
            ),
            resumeListen = parseResumeRow(resume.optJSONObject("listen")),
            resumeRead = parseResumeRow(resume.optJSONObject("read")),
            dueTotalCount = totalDue,
            deck = parseDeck(srs.optJSONArray("deck")),
            quickSlots = parseQuickSlots(context, root.optJSONArray("quickSlots")),
        )
    }

    private fun parseResumeRow(obj: JSONObject?): ResumeRow? {
        if (obj == null) return null
        val title = obj.optString("title", "").trim()
        if (title.isEmpty()) return null
        val progress = (obj.optDouble("progress", 0.0).coerceIn(0.0, 1.0) * 100.0).toInt()
        return ResumeRow(
            title = title,
            subtitle = obj.optString("subtitle", "").trim(),
            progressPercent = progress,
            isPlaying = obj.optBoolean("isPlaying", false),
            deepLink = obj.optNonBlank(
                "deepLink",
                "in4up://nav/studio?target=home&src=widget",
            ),
        )
    }

    private fun parseDeck(arr: JSONArray?): List<FlashcardCard> {
        if (arr == null || arr.length() == 0) return emptyList()
        val list = ArrayList<FlashcardCard>(arr.length())
        for (i in 0 until arr.length()) {
            val item = arr.optJSONObject(i) ?: continue
            val word = item.optString("word", "").trim()
            if (word.isEmpty()) continue
            list.add(
                FlashcardCard(
                    word = word,
                    ipa = item.optString("ipa", "").trim(),
                    meaning = item.optString("meaning", "").trim(),
                    example = item.optString("example", "").trim(),
                    understandPercent =
                        (item.optDouble("understandScore", 0.0).coerceIn(0.0, 1.0) * 100.0).toInt(),
                    listenPercent =
                        (item.optDouble("listenScore", 0.0).coerceIn(0.0, 1.0) * 100.0).toInt(),
                    readPercent =
                        (item.optDouble("readScore", 0.0).coerceIn(0.0, 1.0) * 100.0).toInt(),
                ),
            )
        }
        return list
    }

    private fun parseQuickSlots(context: Context, arr: JSONArray?): List<QuickSlot> {
        val list = ArrayList<QuickSlot>(3)
        if (arr != null) {
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                val link = item.optString("deepLink", "").trim()
                if (link.isEmpty()) continue
                list.add(
                    QuickSlot(
                        id = item.optString("id", "slot_$i"),
                        label = item.optNonBlank("label", context.getString(R.string.app_name)),
                        iconKey = item.optNonBlank("iconKey", "sparkle"),
                        deepLink = link,
                    ),
                )
                if (list.size >= 3) break
            }
        }
        if (list.size < 3) {
            val defaults = listOf(
                QuickSlot(
                    id = "voice_capture",
                    label = context.getString(R.string.shortcut_voice_short),
                    iconKey = "mic",
                    deepLink = "in4up://action/voice_capture?autostart=1&src=widget",
                ),
                QuickSlot(
                    id = "ocr_scan",
                    label = context.getString(R.string.shortcut_ocr_short),
                    iconKey = "ocr",
                    deepLink = "in4up://action/ocr_scan?src=widget",
                ),
                QuickSlot(
                    id = "screen_translate",
                    label = context.getString(R.string.tile_screen_translate_label),
                    iconKey = "translate",
                    deepLink = "in4up://action/screen_translate?src=widget",
                ),
            )
            for (fallback in defaults) {
                if (list.size >= 3) break
                if (list.none { it.id == fallback.id }) {
                    list.add(fallback)
                }
            }
        }
        return list
    }

    private fun parseDoubleList(arr: JSONArray?): List<Double> {
        if (arr == null) return emptyList()
        val out = ArrayList<Double>(arr.length())
        for (i in 0 until arr.length()) {
            out.add(arr.optDouble(i, 0.0).coerceIn(0.0, 1.0))
        }
        return out
    }

    private fun parseStringList(arr: JSONArray?): List<String> {
        if (arr == null) return emptyList()
        val out = ArrayList<String>(arr.length())
        for (i in 0 until arr.length()) {
            out.add(arr.optString(i, "-"))
        }
        return out
    }

    private fun JSONObject.optNonBlank(key: String, fallback: String): String {
        val raw = optString(key, "").trim()
        return if (raw.isEmpty()) fallback else raw
    }

    fun iconResForKey(iconKey: String): Int =
        when (iconKey.trim().lowercase()) {
            "search" -> R.drawable.ic_widget_search
            "mic" -> R.drawable.ic_widget_mic
            "ocr" -> R.drawable.ic_widget_ocr
            "translate" -> R.drawable.ic_widget_translate
            "sparkle" -> R.drawable.ic_widget_sparkle
            "cabin" -> R.drawable.ic_widget_cabin
            "leaf" -> R.drawable.ic_widget_leaf
            "book" -> R.drawable.ic_widget_book
            "headphones" -> R.drawable.ic_widget_headphones
            "play" -> R.drawable.ic_widget_play
            "pause" -> R.drawable.ic_widget_pause
            else -> R.drawable.ic_widget_sparkle
        }

    // Tạo PendingIntent an toàn theo đúng flavor (stable / beta / dev) nhờ setPackage + setClass.
    fun deepLinkPendingIntent(
        context: Context,
        deepLinkUri: String,
        requestSeed: Int = 0,
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUri)).apply {
            setPackage(context.packageName)
            setClass(context, MainActivity::class.java)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val reqCode = (deepLinkUri.hashCode() * 31) + requestSeed
        return PendingIntent.getActivity(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun refreshAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        QuickBarWidgetProvider.updateAll(context, manager)
        ContinueLearningWidgetProvider.updateAll(context, manager)
        FlashcardSrsWidgetProvider.updateAll(context, manager)
        StreakPulseWidgetProvider.updateAll(context, manager)
    }

    // Đồng bộ Dynamic Shortcuts (Android 7.1+ API 25) để hiện số từ đến hạn thật và
    // gắn tường minh vào đúng package flavor hiện tại.
    fun syncDynamicShortcuts(context: Context, snapshot: ParsedSnapshot) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        try {
            val shortcutManager =
                context.getSystemService(ShortcutManager::class.java) ?: return
            val reviewLabel = if (snapshot.dueTotalCount > 0) {
                "${snapshot.reviewNowLabel} (${snapshot.dueTotalCount})"
            } else {
                snapshot.reviewNowLabel
            }
            val reviewIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("in4up://action/review_due?mode=srs&src=dyn_shortcut"),
            ).apply {
                setPackage(context.packageName)
                setClass(context, MainActivity::class.java)
            }
            val reviewShortcut = ShortcutInfo.Builder(context, "dyn_review_due")
                .setShortLabel(reviewLabel.take(24))
                .setLongLabel(snapshot.dueBadge.take(48))
                .setIcon(Icon.createWithResource(context, R.drawable.ic_widget_leaf))
                .setIntent(reviewIntent)
                .build()

            val resumeLink = snapshot.resumeListen?.deepLink
                ?: snapshot.resumeRead?.deepLink
            val dynamicList = ArrayList<ShortcutInfo>(2)
            dynamicList.add(reviewShortcut)
            if (!resumeLink.isNullOrBlank()) {
                val resumeTitle = snapshot.resumeListen?.title
                    ?: snapshot.resumeRead?.title
                    ?: snapshot.continueHeader
                val resumeIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse(resumeLink),
                ).apply {
                    setPackage(context.packageName)
                    setClass(context, MainActivity::class.java)
                }
                val iconRes = if (snapshot.resumeListen != null) {
                    R.drawable.ic_widget_headphones
                } else {
                    R.drawable.ic_widget_book
                }
                dynamicList.add(
                    ShortcutInfo.Builder(context, "dyn_continue_learning")
                        .setShortLabel(resumeTitle.take(24))
                        .setLongLabel(resumeTitle.take(48))
                        .setIcon(Icon.createWithResource(context, iconRes))
                        .setIntent(resumeIntent)
                        .build(),
                )
            }
            shortcutManager.dynamicShortcuts = dynamicList
        } catch (_: Exception) {
            // Không để giới hạn của Launcher tùy biến làm ảnh hưởng luồng đồng bộ.
        }
    }

    fun providerComponentForKind(context: Context, kind: String): ComponentName? =
        when (kind) {
            "quick_bar" -> ComponentName(context, QuickBarWidgetProvider::class.java)
            "continue_learning" ->
                ComponentName(context, ContinueLearningWidgetProvider::class.java)
            "flashcard_srs" ->
                ComponentName(context, FlashcardSrsWidgetProvider::class.java)
            "streak_pulse" ->
                ComponentName(context, StreakPulseWidgetProvider::class.java)
            else -> null
        }
}
