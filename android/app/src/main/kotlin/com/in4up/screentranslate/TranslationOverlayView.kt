package com.in4up.screentranslate

import android.app.AlertDialog
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import android.util.TypedValue
import android.view.View

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
 *    **BỎ VẼ khối đó** (để lộ nguyên chữ gốc bên dưới) + ghi log
 *    `[in4up-xlat-overlay]` — KHÔNG ellipsize, KHÔNG clip.
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
 *
 * PSRC-211 vòng 2 (mục 3 của `L4-hub-tra-loi.md` — font scale 2.0× vẫn rơi
 * 2/10 khối): khối không đủ chỗ ngay cả ở sàn [MIN_READABLE_SP] **không còn bị
 * bỏ vẽ**. Dart trả `collapsed = true` ⇒ view vẽ một **chip nhỏ** (… ) ở góc
 * trên-phải khối gốc; chạm chip mở popup hiện ĐỦ bản dịch ở cỡ chữ đọc được.
 * Hai luật owner 2026-11-11 vẫn nguyên: không vẽ dưới 10sp, không cắt chữ.
 * Nhờ vậy "mỗi khối OCR vào có đúng một đầu ra" - bong bóng đầy đủ hoặc chip.
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

        const val LOG_TAG = "in4up-xlat-overlay"

        /** Nhãn trên chip thu gọn — một ký tự, không phải chữ bị cắt giữa từ. */
        const val CHIP_LABEL = "…"

        /** Kích thước tối thiểu của chip (dp) — khớp `kOverlayChip*Dp` bên Dart. */
        const val CHIP_MIN_WIDTH_DP = 26f
        const val CHIP_MIN_HEIGHT_DP = 20f
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
         * PSRC-211 vòng 2 — khối bị THU GỌN: vẽ chip + nhận chạm để mở popup
         * bản dịch đầy đủ. Mặc định `false` ⇒ payload cũ giữ hành vi cũ.
         */
        val collapsed: Boolean = false,
    )

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

    /** Nền chip thu gọn — đậm hơn nền bong bóng để thấy rõ dù chỉ ~26×20dp. */
    private val chipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(236, 112, 66, 200)
        style = Paint.Style.FILL
    }

    /** Popup bản dịch đầy đủ đang mở (để đóng dứt điểm khi overlay bị gỡ). */
    private val collapsedDialogs = mutableListOf<AlertDialog>()

    private var blocks: List<TranslatedBlock> = emptyList()

    /** Vị trí view trên màn hình — cấp phát một lần, không tạo rác trong onDraw. */
    private val screenOrigin = IntArray(2)

    private val boxRect = RectF()

    fun setBlocks(value: List<TranslatedBlock>) {
        blocks = value
        invalidate()
    }

    fun clear() {
        blocks = emptyList()
        dismissCollapsedDialogs()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (blocks.isEmpty()) return

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

    private fun drawBlocks(canvas: Canvas) {
        for (block in blocks) {
            if (block.collapsed) {
                drawCollapsedChip(canvas, block)
                continue
            }
            // Khối dịch hỏng (translation rỗng): KHÔNG vẽ ô trống — để
            // nguyên chữ gốc bên dưới cho user biết chỗ nào chưa dịch được.
            val text = block.translation.trim()
            if (text.isEmpty()) continue

            val width = (block.right - block.left).coerceAtLeast(1)
            val height = (block.bottom - block.top).coerceAtLeast(1)
            val padding = PADDING

            // AUDIT-1.21.0 #1: KHUNG CỐ ĐỊNH. `block.bottom` là TRẦN do Dart
            // cấp (không đè khối kế tiếp) — chữ phải vừa trong đó.
            val availableHeight = (height - padding * 2).toInt()
            // Khung quá mỏng ⇒ bỏ hẳn, để lộ chữ gốc bên dưới thay vì nghiền
            // chữ nhỏ đè lên dòng khác. Dart đã có sàn `kOverlayMinBoxHeightDp`
            // nên trường hợp này là bất thường ⇒ log để truy.
            if (availableHeight < 8) {
                Log.w(LOG_TAG, "bỏ khối vì khung quá mỏng: h=$availableHeight")
                continue
            }

            val textWidth = (width - padding * 2).toInt().coerceAtLeast(8)
            // PSRC-211: thử từ cỡ chữ GỐC trước; `buildLayout` tự thu nhỏ tới
            // khi chữ thật vừa khung (Dart đã bảo đảm vừa ở `textSizeSp`).
            val startSizeSp = maxOf(block.textSizeSp, block.maxTextSizeSp)
            val layout = buildLayout(
                text = text,
                maxWidth = textWidth,
                maxHeight = availableHeight,
                startSizeSp = startSizeSp,
                fitSizeSp = block.textSizeSp,
            ) ?: run {
                // PSRC-211 vòng 2 (mục 3): KHÔNG bỏ khối, KHÔNG cắt chữ. Bộ ước
                // lượng Dart lệch (font thật khác ước lượng) ⇒ native vẫn vẽ
                // CHIP như một khối `collapsed`, thay vì để trống chỗ đó.
                // Log `need`/`have` để biết bộ ước lượng bên Dart đang hụt.
                Log.w(
                    LOG_TAG,
                    "khối không vừa khung ⇒ vẽ chip (không cắt chữ):" +
                        " need=${neededHeightOf(text, textWidth, block.textSizeSp)}" +
                        " have=$availableHeight size=${block.textSizeSp}" +
                        " text=${text.take(24)}",
                )
                drawCollapsedChip(
                    canvas,
                    block.copy(
                        // Chip ~26×20dp ở góc trên-phải, không phải cả khung: hàm
                        // vẽ đọc đúng 4 cạnh này.
                        left = maxOf(block.left, block.right - chipWidthPx()),
                        top = block.top,
                        right = block.right,
                        bottom = block.top + chipHeightPx(),
                    ),
                    // Chạm vào chip này rơi xuống app bên dưới (overlay không nhận
                    // chạm) — nhưng người dùng vẫn THẤY khối đã được dịch ở đâu.
                    // Đường chính (Dart trả `collapsed = true`) có lớp chạm riêng
                    // do service tạo, mở popup đầy đủ.
                )
                continue
            }

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
    }

    /** Mật độ màn hình, kẹp sàn 0.5 để chip không bao giờ bé hơn 13px. */
    private fun density(): Float =
        resources.displayMetrics.density.coerceAtLeast(0.5f)

    private fun chipWidthPx(): Int = (CHIP_MIN_WIDTH_DP * density()).toInt()

    private fun chipHeightPx(): Int = (CHIP_MIN_HEIGHT_DP * density()).toInt()

    /**
     * PSRC-211 vòng 2 — vẽ chip thu gọn thay vì bỏ khối.
     *
     * Chip chỉ là DẤU HIỆU (nhãn "…"), không phải chữ bị cắt: bản dịch vẫn
     * nguyên vẹn trong [TranslatedBlock.translation] và mở ra đọc đủ khi chạm
     * (xem [showCollapsedTranslation]). Chip nhỏ (~26×20dp) nên gần như không
     * che chữ gốc và không đẩy khối kế tiếp.
     */
    private fun drawCollapsedChip(canvas: Canvas, block: TranslatedBlock) {
        // Chip = ĐÚNG hình chữ nhật Dart đã cấp (`overlayChipSize`, 26×20dp):
        // nhờ vậy lớp chạm của service (`syncChipTouchTargets`) trùng khít hình
        // vẽ, và hai khối khác nhau không bao giờ ra cùng một chip.
        val right = block.right.toFloat()
        val left = block.left.toFloat()
        val top = block.top.toFloat()
        // Dart cấp hình chip ~26×20dp; nếu vì lý do gì đó khung hẹp/thấp hơn
        // (payload cũ), vẫn vẽ đủ kích thước tối thiểu để bấm được.
        val chipRight = maxOf(right, left + chipWidthPx())
        val chipBottom = maxOf(block.bottom.toFloat(), top + chipHeightPx())
        boxRect.set(left, top, chipRight, chipBottom)
        canvas.drawRoundRect(boxRect, 6f, 6f, chipPaint)
        canvas.drawRoundRect(boxRect, 6f, 6f, edgePaint)
        textPaint.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            MIN_READABLE_SP,
            resources.displayMetrics,
        )
        val labelWidth = textPaint.measureText(CHIP_LABEL)
        canvas.drawText(
            CHIP_LABEL,
            boxRect.centerX() - labelWidth / 2f,
            boxRect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2f,
            textPaint,
        )
    }

    /**
     * PSRC-211 vòng 2 — popup bản dịch ĐẦY ĐỦ của một khối thu gọn.
     *
     * Chữ ở đây vẽ bằng `setTextSize(SP)` thường của app nên luôn >= 10sp và
     * KHÔNG bị cắt: đúng hai luật owner 2026-11-11, chỉ là bản dịch không nằm
     * trong khung gốc nữa.
     */
    fun showCollapsedTranslation(
        block: TranslatedBlock,
        title: String,
        note: String,
        closeLabel: String,
    ) {
        val density = density()
        val pad = (16 * density).toInt()
        val body = android.widget.TextView(context).apply {
            text = block.translation.trim()
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(pad, pad, pad, pad)
            setTextIsSelectable(true)
        }
        // Nhãn đi từ service (`getString(R.string...)`) thay vì đọc `R` ở đây:
        // file này được biên dịch riêng bằng kotlinc với `android.jar` (job
        // `android-resolver-compile`) nên KHÔNG có lớp `R` sinh ra.
        val dialog = AlertDialog.Builder(context)
            .setTitle(title)
            .setView(body)
            .setMessage(note)
            .setPositiveButton(closeLabel, null)
            .create()
        dialog.getWindow()?.setType(overlayWindowTypeCompat())
        dialog.show()
        collapsedDialogs.add(dialog)
        dialog.setOnDismissListener { collapsedDialogs.remove(dialog) }
    }

    /**
     * Cửa sổ popup phải cùng "hạng" với overlay hiện tại, nếu không
     * `AlertDialog` (application window) sẽ nằm DƯỚI overlay trong suốt và
     * người dùng bấm chip mà không thấy gì.
     */
    private fun overlayWindowTypeCompat(): Int =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            android.view.WindowManager.LayoutParams.TYPE_PHONE
        }

    /**
     * Chip tại toạ độ MÀN HÌNH (x, y) — `null` nếu không trúng chip nào.
     *
     * Công thức giống `collapsedBlockAt` bên Dart (máy bắt nằm ở phía Dart);
     * khi nhiều chip chồng nhau thì lấy chip có diện tích nhỏ nhất.
     */
    fun collapsedBlockAt(x: Float, y: Float): TranslatedBlock? {
        var best: TranslatedBlock? = null
        var bestArea = Int.MAX_VALUE
        for (block in blocks) {
            if (!block.collapsed) continue
            if (x < block.left || x > block.right) continue
            if (y < block.top || y > block.bottom) continue
            val area = (block.right - block.left) * (block.bottom - block.top)
            if (area < bestArea) {
                bestArea = area
                best = block
            }
        }
        return best
    }

    /** Đóng mọi popup đang mở (dùng khi ẩn overlay / đổi kết quả). */
    fun dismissCollapsedDialogs() {
        for (dialog in collapsedDialogs.toList()) {
            try {
                dialog.dismiss()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        collapsedDialogs.clear()
    }

    /**
     * Dựng layout vừa khung, hoặc `null` nếu KHÔNG THỂ vừa mà không cắt chữ.
     *
     * Nguyên tắc (owner 2026-11-11): "chữ hiện đầy đủ, không bị bóp nhỏ, ẩn do
     * khung nhỏ". Vì vậy:
     *  • 1 lần dựng ở cỡ chữ gốc.
     *  • Nếu tràn: thu nhỏ 1sp mỗi bước tới sàn [MIN_READABLE_SP], MỖI bước hỏi
     *    lại `height` (thu nhỏ làm giảm số dòng nên có bước giảm mạnh).
     *  • Vẫn tràn ở sàn ⇒ trả `null` để caller BỎ VẼ khối (không ellipsize).
     *    Bản cũ ellipsize ở đây ⇒ chữ bị cắt "…" mất nội dung, đúng lỗi owner.
     */
    private fun buildLayout(
        text: String,
        maxWidth: Int,
        maxHeight: Int,
        startSizeSp: Float,
        fitSizeSp: Float = startSizeSp,
    ): StaticLayout? {
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
        return if (layout.height > maxHeight) null else layout
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
        // mất nội dung. Không vừa khung ⇒ caller bỏ vẽ khối (xem buildLayout).
        return StaticLayout.Builder
            .obtain(text, 0, text.length, textPaint, maxWidth)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1.0f)
            .setIncludePad(false)
            .build()
    }
}
