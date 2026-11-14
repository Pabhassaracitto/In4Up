package com.in4up.screentranslate

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * XLAT-SCR-002 — lớp vẽ bản dịch ĐÈ lên màn hình (kiểu Google Lens).
 *
 * Nhận danh sách [TranslatedBlock] với toạ độ PIXEL MÀN HÌNH (Dart đã quy đổi
 * qua `mapCaptureRectToOverlay`, xem `screen_translate_geometry.dart`) — view
 * này KHÔNG tự scale lại lần nữa. Một công thức, một chỗ.
 *
 * Chiến lược vẽ: nền tối mờ phủ đúng khung, rồi vẽ bản dịch bằng
 * [StaticLayout] (tự xuống dòng).
 *
 * XLAT-SCR-006 (owner 2026-11-11): Dart (`layoutTranslatedBlocks`) đã **đo
 * nhu cầu chữ và cấp đủ chiều cao** (nới rộng → nới cao → đẩy khối dưới
 * xuống), nên ở đây việc thu nhỏ gần như không còn cần. Vì vậy:
 *  • **KHÔNG BAO GIỜ vẽ nhỏ hơn [MIN_READABLE_SP] (10sp)** — nhỏ hơn thì chữ
 *    thành vệt xám (đúng lỗi owner báo: "chữ bị bóp nhỏ, khó đọc").
 *  • **KHÔNG BAO GIỜ vẽ chữ cụt** (owner: "khung bị nhỏ hơn nội dung chữ nên
 *    bị mất phần"). Nếu dù đã thu tới sàn mà chữ vẫn không vừa khung thì
 *    khối đó **THU GỌN thành chip** (xem dưới) + ghi log
 *    `[in4up-xlat-overlay]` — KHÔNG ellipsize, KHÔNG clip.
 *  • **KHÔNG BỎ KHỐI IM LẶNG** (hub 2026-11-13): bản XLAT-SCR-006 bỏ vẽ hẳn
 *    khối không vừa ⇒ máy bật cỡ chữ 2.0× mất 2/10 khối mà không ai báo. Giờ
 *    mỗi khối có bản dịch luôn ra ĐÚNG MỘT thứ: khung đủ chữ, hoặc chip "…" ở
 *    góc trên-phải — chạm chip mở popup có đủ bản dịch ([OverlayChipLayer]).
 *    Chip đến từ hai nguồn: Dart đã thu gọn sẵn (`collapsed`, khung = chỗ vẽ
 *    chip) hoặc chính view này đo font THẬT thấy không vừa.
 *  • Vẫn KHÔNG phình khung xuống dưới ⇒ không bao giờ đè khối kế tiếp.
 *
 * AUDIT-1.21.0 #1 / XLAT-SCR-005: trước đây `boxHeight =
 * max(height, layout.height + padding)` cho ô của khối TRÊN phình xuống đè
 * lên khối DƯỚI ⇒ nhiều khối dịch bị chữ chồng lên nhau. Giờ Dart
 * (`layoutTranslatedBlocks`) đã xếp/cắt khung sẵn; native chỉ vẽ TRONG khung
 * nhận được. Một công thức, một chỗ — không scale/phình ở đây nữa.
 *
 * PSRC-211 (audit v1.28.0 — "khung bản dịch thừa khoảng trống bên dưới; cần
 * thu gọn, ôm sát nội dung"): khung Dart gửi là chỗ GIỮ cho khối, tính bằng bộ
 * ước lượng cố tình ước DƯ (Dart không đo được font thật). Tô kín cả khung
 * (bản trước) làm phần dư đó hiện thành khoảng trống dưới chữ. Giờ:
 *  • Nền vẽ ÔM SÁT chữ thật: `đáy nền = max(đáy chữ dịch, coverBottom)`,
 *    không bao giờ vượt `bottom` (vẫn không đè khối kế tiếp). [coverBottom] =
 *    đáy chữ GỐC ⇒ chữ gốc không lòi ra dưới nền.
 *  • Cỡ chữ thử từ [TranslatedBlock.maxTextSizeSp] (cỡ chữ gốc) rồi mới thu
 *    nhỏ: Dart hạ `textSizeSp` theo số ước dư, còn ở đây đo được thật.
 *  • Toạ độ khối là toạ độ MÀN HÌNH; view này có thể không nằm ở (0,0) của màn
 *    hình (tai thỏ khi xoay ngang, ROM chèn lề) ⇒ trừ `getLocationOnScreen`
 *    trước khi vẽ, nếu không mọi khối lệch đúng bằng độ dời của cửa sổ.
 */
class TranslationOverlayView(context: Context) : View(context) {

    private companion object {
        /**
         * Padding trong khung, PIXEL — PHẢI khớp `kOverlayTextPaddingPx` bên
         * Dart (`screen_translate_overlay_layout.dart`). Lệch nhau ⇒ Dart cấp
         * thiếu chỗ và native phải cắt chữ.
         */
        const val PADDING = 4f

        /** Sàn cỡ chữ: dưới ngưỡng này chữ không còn đọc được. */
        const val MIN_READABLE_SP = 10f

        /**
         * Kích thước chip thu gọn (dp) — PHẢI khớp `kOverlayChipWidthDp` /
         * `kOverlayChipHeightDp` bên Dart; sàn theo hub 2026-11-13 (≈ 20×14).
         */
        const val CHIP_WIDTH_DP = 28f
        const val CHIP_HEIGHT_DP = 20f
        const val CHIP_MIN_HEIGHT_DP = 14f

        /** Nhãn chip: dấu "còn nữa" — KHÔNG phải chữ dịch bị cắt. */
        const val CHIP_LABEL = "…"
        const val CHIP_LABEL_DP = 13f

        const val LOG_TAG = "in4up-xlat-overlay"
    }

    data class TranslatedBlock(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
        val original: String,
        val translation: String,
        val textSizeSp: Float,
        /**
         * PSRC-211 — cỡ chữ ưa thích (sp), ≥ [textSizeSp]. Mặc định bằng
         * [textSizeSp] ⇒ payload cũ (không có khoá này) giữ hành vi cũ.
         */
        val maxTextSizeSp: Float = textSizeSp,
        /**
         * PSRC-211 — đáy chữ gốc (pixel màn hình). Mặc định bằng [bottom] ⇒
         * payload cũ vẫn tô kín cả khung như trước.
         */
        val coverBottom: Int = bottom,
        /**
         * PSRC-211 (hub 2026-11-13) — Dart đã THU GỌN khối này: khung
         * (left/top/right/bottom) là chỗ vẽ CHIP, [translation] vẫn là bản
         * dịch nguyên vẹn (hiện trong popup khi chạm). Mặc định `false` ⇒
         * payload cũ giữ hành vi cũ.
         */
        val collapsed: Boolean = false,
    )

    /**
     * Một chip thu gọn ĐÃ CHỐT chỗ vẽ (pixel màn hình). Vùng chạm của chip là
     * đúng khung này — khớp `collapsedBlockAt` bên Dart.
     */
    data class Chip(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
        val original: String,
        val translation: String,
    )

    /**
     * Kết quả [buildLayout]: [collapsed] = false ⇒ [layout] là NGUYÊN bản
     * dịch, vừa khung; [collapsed] = true ⇒ không cỡ chữ ≥ sàn nào vừa, và
     * [layout] là nhãn chip (không phải bản dịch bị cắt).
     */
    class FittedText(val layout: StaticLayout, val collapsed: Boolean)

    /** Khung vẽ đủ chữ đã dựng xong layout (dựng một lần, không dựng trong onDraw). */
    private class Box(val block: TranslatedBlock, val layout: StaticLayout)

    private val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(224, 16, 18, 28)
        style = Paint.Style.FILL
    }

    private val edgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(120, 120, 200, 255)
        style = Paint.Style.STROKE
        strokeWidth = 1.5f
    }

    private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
    }

    private val chipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(240, 20, 110, 160)
        style = Paint.Style.FILL
    }

    private val chipEdgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(230, 255, 255, 255)
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }

    private val chipTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        isFakeBoldText = true
    }

    /** Nhãn chip — dựng một lần (nội dung và cỡ không đổi theo khối). */
    private val chipLabel: StaticLayout by lazy {
        // Nhãn là KÝ HIỆU "còn nữa", không phải chữ dịch ⇒ cỡ theo DP để vừa
        // chip dù máy bật cỡ chữ 2.0× (luật ≥ 10sp áp cho chữ dịch — chữ dịch
        // của chip nằm trong popup, ở cỡ bình thường).
        chipTextPaint.textSize = dpToPx(CHIP_LABEL_DP)
        StaticLayout.Builder
            .obtain(CHIP_LABEL, 0, CHIP_LABEL.length, chipTextPaint, chipWidthPx())
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setIncludePad(false)
            .build()
    }

    private var blocks: List<TranslatedBlock> = emptyList()
    private var boxes: List<Box> = emptyList()

    /**
     * Các chip đang vẽ (toạ độ màn hình), theo thứ tự khối. Service dựng một
     * cửa sổ chạm cho mỗi chip ([OverlayChipLayer]) — bản thân view này
     * `FLAG_NOT_TOUCHABLE` để app bên dưới vẫn cuộn/bấm được.
     */
    var chips: List<Chip> = emptyList()
        private set

    /** Vị trí view trên màn hình — cấp phát một lần, không tạo rác trong onDraw. */
    private val screenOrigin = IntArray(2)

    private val boxRect = RectF()

    /** Nhận khối mới, CHỐT luôn khối nào vẽ khung / khối nào thành chip. */
    fun setBlocks(value: List<TranslatedBlock>): List<Chip> {
        blocks = value
        resolveBlocks()
        invalidate()
        return chips
    }

    fun clear() {
        blocks = emptyList()
        boxes = emptyList()
        chips = emptyList()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (boxes.isEmpty() && chips.isEmpty()) return

        // PSRC-211: khối mang toạ độ MÀN HÌNH, canvas là toạ độ VIEW. Hai hệ
        // chỉ trùng nhau khi cửa sổ overlay nằm đúng (0,0) của màn hình.
        getLocationOnScreen(screenOrigin)
        canvas.save()
        canvas.translate(-screenOrigin[0].toFloat(), -screenOrigin[1].toFloat())
        try {
            drawBlocks(canvas)
        } finally {
            canvas.restore()
        }
    }

    /**
     * Quyết định cho TỪNG khối có bản dịch: vẽ khung đủ chữ, hay thu gọn thành
     * chip. Không có nhánh thứ ba — khối có bản dịch không bao giờ biến mất.
     *
     * Chạy ở [setBlocks] (không phải `onDraw`) vì service cần danh sách chip
     * NGAY để dựng cửa sổ chạm, và để `onDraw` không phải dựng layout.
     */
    private fun resolveBlocks() {
        val newBoxes = ArrayList<Box>()
        val newChips = ArrayList<Chip>()
        for (block in blocks) {
            // Khối dịch hỏng / không có chữ để dịch (translation rỗng): KHÔNG
            // vẽ ô trống — chữ gốc bên dưới vẫn nguyên, không có gì để thu gọn.
            val text = block.translation.trim()
            if (text.isEmpty()) continue

            if (block.collapsed) {
                // Dart đã thu gọn: khung nhận được LÀ chỗ vẽ chip.
                newChips.add(
                    Chip(
                        left = block.left,
                        top = block.top,
                        right = maxOf(block.left + 1, block.right),
                        bottom = maxOf(block.top + 1, block.bottom),
                        original = block.original,
                        translation = text,
                    ),
                )
                continue
            }

            val width = (block.right - block.left).coerceAtLeast(1)
            val height = (block.bottom - block.top).coerceAtLeast(1)
            val padding = PADDING

            // AUDIT-1.21.0 #1: KHUNG CỐ ĐỊNH. `block.bottom` là TRẦN do Dart
            // cấp (không đè khối kế tiếp) — chữ phải vừa trong đó.
            val availableHeight = (height - padding * 2).toInt()
            val textWidth = (width - padding * 2).toInt().coerceAtLeast(8)
            // PSRC-211: thử từ cỡ chữ GỐC trước; `buildLayout` tự thu nhỏ tới
            // khi chữ thật vừa khung (Dart đã bảo đảm vừa ở `textSizeSp`).
            val startSizeSp = maxOf(block.textSizeSp, block.maxTextSizeSp)
            val fitted = buildLayout(
                text = text,
                maxWidth = textWidth,
                maxHeight = availableHeight,
                startSizeSp = startSizeSp,
                fitSizeSp = block.textSizeSp,
            )
            if (fitted.collapsed) {
                // Font thật to hơn ước lượng của Dart (hoặc khung quá mỏng).
                // KHÔNG cắt chữ, KHÔNG bỏ khối: thu gọn tại góc trên-phải.
                // Log `need`/`have` để biết bộ ước lượng bên Dart đang hụt.
                Log.w(
                    LOG_TAG,
                    "thu gọn khối vì chữ không vừa khung (không cắt chữ):" +
                        " need=${neededHeightOf(text, textWidth, block.textSizeSp)}" +
                        " have=$availableHeight size=${block.textSizeSp}" +
                        " text=${text.take(24)}",
                )
                newChips.add(chipAtCorner(block, text))
                continue
            }
            newBoxes.add(Box(block, fitted.layout))
        }
        boxes = newBoxes
        chips = newChips
    }

    /**
     * Chỗ vẽ chip khi CHÍNH view này phải thu gọn: góc TRÊN-PHẢI khung của
     * khối (bám `collapsedChipRect` bên Dart), kẹp trong màn hình.
     *
     * Chip nằm trong phần chỗ Dart đã giữ cho khối này. Khung mỏng hơn chip
     * thì chip thấp lại theo khung (sàn [CHIP_MIN_HEIGHT_DP]) để không lấn
     * sang khối bên dưới.
     */
    private fun chipAtCorner(block: TranslatedBlock, text: String): Chip {
        val chipW = chipWidthPx()
        val boxHeight = (block.bottom - block.top).coerceAtLeast(1)
        val chipH = boxHeight.coerceIn(
            dpToPx(CHIP_MIN_HEIGHT_DP).toInt().coerceAtLeast(1),
            dpToPx(CHIP_HEIGHT_DP).toInt().coerceAtLeast(1),
        )
        val metrics = resources.displayMetrics
        var right = maxOf(chipW, block.right)
        if (metrics.widthPixels in 1 until right) right = maxOf(chipW, metrics.widthPixels)
        val top = maxOf(0, block.top)
        return Chip(
            left = right - chipW,
            top = top,
            right = right,
            bottom = top + chipH,
            original = block.original,
            translation = text,
        )
    }

    private fun chipWidthPx(): Int = dpToPx(CHIP_WIDTH_DP).toInt().coerceAtLeast(8)

    private fun dpToPx(dp: Float): Float = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        dp,
        resources.displayMetrics,
    )

    private fun drawBlocks(canvas: Canvas) {
        val padding = PADDING
        for (box in boxes) {
            val block = box.block
            val layout = box.layout

            // PSRC-211: nền ÔM SÁT chữ thật. Đáy = đáy chữ dịch, nhưng ít nhất
            // phủ hết chữ gốc (`coverBottom`) và không bao giờ quá trần.
            val textBottom = block.top + layout.height + padding * 2
            val hugBottom = minOf(
                block.bottom.toFloat(),
                maxOf(textBottom, block.coverBottom.toFloat()),
            )
            boxRect.set(
                block.left.toFloat(),
                block.top.toFloat(),
                block.right.toFloat(),
                hugBottom,
            )

            canvas.drawRoundRect(boxRect, 6f, 6f, boxPaint)
            canvas.drawRoundRect(boxRect, 6f, 6f, edgePaint)

            canvas.save()
            canvas.clipRect(
                boxRect.left + padding,
                boxRect.top + padding,
                boxRect.right - padding,
                boxRect.bottom - padding,
            )
            canvas.translate(block.left + padding, block.top + padding)
            layout.draw(canvas)
            canvas.restore()
        }

        // Chip vẽ SAU các khung ⇒ luôn nằm trên, không bị khung nào che.
        val label = chipLabel
        for (chip in chips) {
            boxRect.set(
                chip.left.toFloat(),
                chip.top.toFloat(),
                chip.right.toFloat(),
                chip.bottom.toFloat(),
            )
            val radius = boxRect.height() / 2f
            canvas.drawRoundRect(boxRect, radius, radius, chipPaint)
            canvas.drawRoundRect(boxRect, radius, radius, chipEdgePaint)
            canvas.save()
            canvas.translate(
                boxRect.left + (boxRect.width() - label.width) / 2f,
                boxRect.top + (boxRect.height() - label.height) / 2f,
            )
            label.draw(canvas)
            canvas.restore()
        }
    }

    /**
     * Dựng layout vừa khung. LUÔN trả kết quả (hub 2026-11-13) — không còn
     * `null` để caller lặng lẽ bỏ khối.
     *
     * Nguyên tắc (owner 2026-11-11): "chữ hiện đầy đủ, không bị bóp nhỏ, ẩn do
     * khung nhỏ". Vì vậy:
     *  • 1 lần dựng ở cỡ chữ gốc.
     *  • Nếu tràn: thu nhỏ 1sp mỗi bước tới sàn [MIN_READABLE_SP], MỖI bước hỏi
     *    lại `height` (thu nhỏ làm giảm số dòng nên có bước giảm mạnh).
     *  • Vẫn tràn ở sàn ⇒ trả [FittedText] `collapsed = true` mang NHÃN CHIP
     *    (không phải bản dịch bị cắt): caller vẽ chip, bản dịch đầy đủ nằm
     *    trong popup. Không ellipsize, không hạ sàn 10sp.
     */
    private fun buildLayout(
        text: String,
        maxWidth: Int,
        maxHeight: Int,
        startSizeSp: Float,
        fitSizeSp: Float = startSizeSp,
    ): FittedText {
        // PSRC-211: [fitSizeSp] là cỡ chữ Dart đã tính là VỪA. Khi bắt đầu từ
        // cỡ lớn hơn, bước lùi 1sp không được nhảy qua nó (13.1 → 12.1 → 11.1
        // sẽ bỏ lỡ 11.9 ⇒ chữ nhỏ hơn mức cần thiết).
        val fit = fitSizeSp.coerceIn(MIN_READABLE_SP, 28f)
        var sizeSp = startSizeSp.coerceIn(MIN_READABLE_SP, 28f)
        var layout = layoutAt(text, maxWidth, sizeSp)
        while (layout.height > maxHeight && sizeSp > MIN_READABLE_SP) {
            val next = (sizeSp - 1f).coerceAtLeast(MIN_READABLE_SP)
            sizeSp = if (sizeSp > fit && next < fit) fit else next
            layout = layoutAt(text, maxWidth, sizeSp)
        }
        return if (layout.height > maxHeight) {
            FittedText(chipLabel, collapsed = true)
        } else {
            FittedText(layout, collapsed = false)
        }
    }

    /** Chiều cao (px) cần để vẽ [text] ở cỡ [startSizeSp] (chẩn đoán/log). */
    private fun neededHeightOf(
        text: String,
        maxWidth: Int,
        startSizeSp: Float,
    ): Int = layoutAt(text, maxWidth, startSizeSp.coerceIn(MIN_READABLE_SP, 28f)).height

    private fun layoutAt(
        text: String,
        maxWidth: Int,
        sizeSp: Float,
    ): StaticLayout {
        // TypedValue thay cho displayMetrics.scaledDensity (deprecated API 34)
        // và tôn trọng cỡ chữ hệ thống của người dùng — Dart nhận cùng tỉ lệ
        // qua `fontScale` nên hai bên vẫn khớp số đo.
        textPaint.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            sizeSp,
            resources.displayMetrics,
        )
        // KHÔNG setMaxLines/ellipsize: owner 2026-11-11 bác "…" vì nó làm
        // mất nội dung. Không vừa khung ⇒ thu gọn thành chip (xem buildLayout).
        return StaticLayout.Builder
            .obtain(text, 0, text.length, textPaint, maxWidth)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1.0f)
            .setIncludePad(false)
            .build()
    }
}

/**
 * PSRC-211 (hub 2026-11-13) — lớp CHẠM đi kèm [TranslationOverlayView].
 *
 * Overlay bản dịch phủ kín màn hình nên phải `FLAG_NOT_TOUCHABLE` (app bên
 * dưới vẫn cuộn/bấm được). Vì thế những thứ CẦN chạm là các cửa sổ nhỏ riêng,
 * chỉ chiếm đúng diện tích của chúng:
 *  • mỗi chip thu gọn một cửa sổ trong suốt, trùng khung chip mà overlay vẽ
 *    (vùng chạm = khung chip, khớp `collapsedBlockAt` bên Dart) — chạm ⇒
 *    [showPopup] hiện ĐỦ bản dịch ở cỡ chữ bình thường;
 *  • chip "Còn N khối · Dịch tiếp" ([showPending]) khi màn hình có nhiều khối
 *    hơn trần một lượt.
 *
 * Nằm chung file với [TranslationOverlayView] và chỉ phụ thuộc `android.jar`
 * (mọi chữ hiển thị do bên gọi truyền vào, không đọc `R`) ⇒ job kotlinc của
 * `listen_queue_tests.yml` biên dịch được, không cần build APK.
 */
class OverlayChipLayer(
    private val context: Context,
    private val windowManager: WindowManager,
    private val windowType: Int,
) {
    private companion object {
        const val LOG_TAG = "in4up-xlat-overlay"

        /** Cỡ chữ bản dịch trong popup — "bình thường", luôn ≥ sàn 10sp. */
        const val POPUP_TEXT_SP = 16f
        const val POPUP_TITLE_SP = 13f
        const val POPUP_ORIGINAL_SP = 12f
        const val PENDING_TEXT_SP = 12.5f
    }

    private val chipViews = ArrayList<View>()
    private var popupView: View? = null
    private var pendingView: TextView? = null
    private var pendingParams: WindowManager.LayoutParams? = null

    /** Số cửa sổ chạm của chip đang gắn (chẩn đoán / log). */
    val chipCount: Int
        get() = chipViews.size

    /**
     * Dựng lại cửa sổ chạm cho [chips] (toạ độ MÀN HÌNH). [popupTitle] là tiêu
     * đề popup, đã dịch sẵn ở Dart (rỗng ⇒ popup không có dòng tiêu đề).
     */
    fun showChips(chips: List<TranslationOverlayView.Chip>, popupTitle: String) {
        removeChips()
        hidePopup()
        for (chip in chips) {
            val width = (chip.right - chip.left).coerceAtLeast(1)
            val height = (chip.bottom - chip.top).coerceAtLeast(1)
            val view = View(context)
            view.contentDescription =
                if (popupTitle.isEmpty()) chip.translation else "$popupTitle: ${chip.translation}"
            view.setOnClickListener {
                showPopup(popupTitle, chip.translation, chip.original)
            }
            val params = WindowManager.LayoutParams(
                width,
                height,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = chip.left
                y = chip.top
            }
            try {
                windowManager.addView(view, params)
                chipViews.add(view)
            } catch (e: Exception) {
                // Chip vẫn được VẼ (overlay lo) — chỉ là không chạm được.
                Log.w(LOG_TAG, "không gắn được cửa sổ chạm cho chip: $e")
                continue
            }
            // Cửa sổ có thể bị hệ thống dời (tai thỏ khi xoay ngang, ROM chèn
            // lề) ⇒ đo lại vị trí THẬT trên màn hình rồi bù đúng độ lệch, để
            // vùng chạm trùng chip đang vẽ. Cùng phép bù `getLocationOnScreen`
            // mà overlay dùng khi vẽ.
            view.post { alignToScreen(view, params, chip.left, chip.top) }
        }
    }

    private fun alignToScreen(
        view: View,
        params: WindowManager.LayoutParams,
        wantX: Int,
        wantY: Int,
    ) {
        if (!view.isAttachedToWindow) return
        val actual = IntArray(2)
        view.getLocationOnScreen(actual)
        val dx = wantX - actual[0]
        val dy = wantY - actual[1]
        if (dx == 0 && dy == 0) return
        params.x += dx
        params.y += dy
        try {
            windowManager.updateViewLayout(view, params)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "không dời được cửa sổ chip: $e")
        }
    }

    /**
     * Popup hiện ĐỦ bản dịch của một chip: chữ ở cỡ bình thường (theo cỡ chữ
     * hệ thống), dài thì CUỘN — không cắt, không "…". Chạm ra ngoài thẻ để
     * đóng (chạm trong thẻ là để cuộn).
     */
    fun showPopup(title: String, translation: String, original: String) {
        hidePopup()
        val scrim = FrameLayout(context)
        scrim.setBackgroundColor(Color.argb(150, 0, 0, 0))
        scrim.setOnClickListener { hidePopup() }

        val card = LinearLayout(context)
        card.orientation = LinearLayout.VERTICAL
        // Thẻ NUỐT cú chạm của chính nó (tiêu đề, lề): không có dòng này cú
        // chạm rơi xuống lớp mờ và popup đóng khi người dùng chỉ muốn đọc.
        card.isClickable = true
        card.setPadding(dp(16), dp(14), dp(16), dp(14))
        card.background = GradientDrawable().apply {
            cornerRadius = dp(14).toFloat()
            setColor(Color.argb(250, 16, 20, 32))
            setStroke(dp(1), Color.argb(170, 41, 182, 246))
        }

        if (title.isNotEmpty()) {
            val titleView = TextView(context)
            titleView.text = title
            titleView.setTextColor(Color.argb(255, 129, 212, 250))
            titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, POPUP_TITLE_SP)
            titleView.setPadding(0, 0, 0, dp(8))
            card.addView(titleView)
        }

        val content = LinearLayout(context)
        content.orientation = LinearLayout.VERTICAL
        val body = TextView(context)
        body.text = translation
        body.setTextColor(Color.WHITE)
        body.setTextSize(TypedValue.COMPLEX_UNIT_SP, POPUP_TEXT_SP)
        content.addView(body)
        if (original.isNotBlank()) {
            // Chữ gốc để đối chiếu — chip có thể nằm xa chỗ chữ gốc khi màn
            // hình kín khung.
            val source = TextView(context)
            source.text = original
            source.setTextColor(Color.argb(190, 255, 255, 255))
            source.setTextSize(TypedValue.COMPLEX_UNIT_SP, POPUP_ORIGINAL_SP)
            source.setPadding(0, dp(10), 0, 0)
            content.addView(source)
        }
        val scroll = ScrollView(context)
        scroll.addView(
            content,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        card.addView(
            scroll,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        val cardParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        )
        cardParams.setMargins(dp(24), dp(56), dp(24), dp(56))
        scrim.addView(card, cardParams)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windowManager.addView(scrim, params)
            popupView = scrim
        } catch (e: Exception) {
            Log.w(LOG_TAG, "không mở được popup bản dịch: $e")
        }
    }

    fun hidePopup() {
        val view = popupView ?: return
        popupView = null
        removeQuietly(view)
    }

    /**
     * Chip "Còn N khối · Dịch tiếp" tại ([x], [y]) (pixel màn hình). [label]
     * đã dịch sẵn ở Dart. Gọi lại để đổi nhãn/vị trí.
     */
    fun showPending(label: String, x: Int, y: Int, onTap: () -> Unit) {
        if (label.isEmpty()) {
            hidePending()
            return
        }
        val existing = pendingView
        val view = existing ?: TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, PENDING_TEXT_SP)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(Color.argb(240, 20, 110, 160))
                setStroke(dp(1), Color.argb(230, 255, 255, 255))
            }
        }
        view.text = label
        view.contentDescription = label
        view.setOnClickListener { onTap() }
        val params = pendingParams ?: WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        params.x = x
        params.y = y
        try {
            if (existing == null) {
                windowManager.addView(view, params)
                pendingView = view
                pendingParams = params
            } else {
                windowManager.updateViewLayout(view, params)
            }
        } catch (e: Exception) {
            Log.w(LOG_TAG, "không hiện được chip dịch tiếp: $e")
        }
    }

    fun hidePending() {
        val view = pendingView ?: return
        pendingView = null
        pendingParams = null
        removeQuietly(view)
    }

    /** Gỡ MỌI cửa sổ của lớp này (ẩn bản dịch, dừng service, mất quyền). */
    fun clear() {
        removeChips()
        hidePopup()
        hidePending()
    }

    private fun removeChips() {
        for (view in chipViews) removeQuietly(view)
        chipViews.clear()
    }

    private fun removeQuietly(view: View) {
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "gỡ cửa sổ overlay lỗi: $e")
        }
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        context.resources.displayMetrics,
    ).toInt()
}
