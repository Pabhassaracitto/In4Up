package com.in4up.screentranslate

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
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
 *  • Chỉ ellipsize khi bất khả kháng, và **ghi log** để biết đường sửa (nếu
 *    log xuất hiện nhiều nghĩa là bộ ước lượng ở Dart đang hụt).
 *  • Vẫn KHÔNG phình khung xuống dưới ⇒ không bao giờ đè khối kế tiếp.
 *
 * AUDIT-1.21.0 #1 / XLAT-SCR-005: trước đây `boxHeight =
 * max(height, layout.height + padding)` cho ô của khối TRÊN phình xuống đè
 * lên khối DƯỚI ⇒ nhiều khối dịch bị chữ chồng lên nhau. Giờ Dart
 * (`layoutTranslatedBlocks`) đã xếp/cắt khung sẵn; native chỉ vẽ ĐÚNG khung
 * nhận được. Một công thức, một chỗ — không scale/phình ở đây nữa.
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
    }

    data class TranslatedBlock(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
        val original: String,
        val translation: String,
        val textSizeSp: Float,
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

    private var blocks: List<TranslatedBlock> = emptyList()

    fun setBlocks(value: List<TranslatedBlock>) {
        blocks = value
        invalidate()
    }

    fun clear() {
        blocks = emptyList()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (blocks.isEmpty()) return
        for (block in blocks) {
            // Khối dịch hỏng (translation rỗng): KHÔNG vẽ ô trống — để
            // nguyên chữ gốc bên dưới cho user biết chỗ nào chưa dịch được.
            val text = block.translation.trim()
            if (text.isEmpty()) continue

            val width = (block.right - block.left).coerceAtLeast(1)
            val height = (block.bottom - block.top).coerceAtLeast(1)
            val padding = PADDING

            // AUDIT-1.21.0 #1: KHUNG CỐ ĐỊNH. Dart đã cắt khung trên đúng
            // mép khung dưới; nếu vẫn phình ở đây sẽ đè chữ khối kế tiếp.
            val rect = RectF(
                block.left.toFloat(),
                block.top.toFloat(),
                block.right.toFloat(),
                block.bottom.toFloat(),
            )
            val availableHeight = (height - padding * 2).toInt()
            // Khung quá mỏng ⇒ bỏ hẳn, để lộ chữ gốc bên dưới thay vì nghiền
            // chữ nhỏ đè lên dòng khác. Dart đã có sàn `kOverlayMinBoxHeightDp`
            // nên trường hợp này là bất thường ⇒ log để truy.
            if (availableHeight < 8) {
                Log.w(LOG_TAG, "bỏ khối vì khung quá mỏng: h=$availableHeight")
                continue
            }

            val layout = buildLayout(
                text = text,
                maxWidth = (width - padding * 2).toInt().coerceAtLeast(8),
                maxHeight = availableHeight,
                startSizeSp = block.textSizeSp,
            )
            // Ghi log khi vẫn phải cắt: nghĩa là bộ ước lượng bên Dart hụt so
            // với font thật của thiết bị ⇒ nới hệ số an toàn ở đó.
            if (layout.height > availableHeight) {
                Log.w(
                    LOG_TAG,
                    "chữ vẫn tràn khung: need=${layout.height} have=$availableHeight" +
                        " size=${block.textSizeSp}",
                )
            }

            // Chữ vẫn dài hơn khung ⇒ cắt số dòng + ellipsize. Không vẽ ra
            // ngoài `rect` (canvas.clipRect là hàng rào cuối cùng).
            canvas.drawRoundRect(rect, 6f, 6f, boxPaint)
            canvas.drawRoundRect(rect, 6f, 6f, edgePaint)

            canvas.save()
            canvas.clipRect(
                rect.left + padding,
                rect.top + padding,
                rect.right - padding,
                rect.bottom - padding,
            )
            canvas.translate(block.left + padding, block.top + padding)
            layout.draw(canvas)
            canvas.restore()
        }
    }

    private fun buildLayout(
        text: String,
        maxWidth: Int,
        maxHeight: Int,
        startSizeSp: Float,
    ): StaticLayout {
        var sizeSp = startSizeSp.coerceIn(MIN_READABLE_SP, 28f)
        var layout = layoutAt(text, maxWidth, sizeSp)
        // Tối đa 6 lần thu nhỏ (1sp mỗi lần) và DỪNG ở MIN_READABLE_SP: chữ
        // nhỏ hơn 10sp thì không đọc được nữa — thà để Dart cấp thêm chỗ.
        var attempts = 0
        while (layout.height > maxHeight && sizeSp > MIN_READABLE_SP &&
            attempts < 6
        ) {
            sizeSp = (sizeSp - 1f).coerceAtLeast(MIN_READABLE_SP)
            layout = layoutAt(text, maxWidth, sizeSp)
            attempts++
        }
        // AUDIT-1.21.0 #1: vẫn không vừa ⇒ giới hạn số dòng + "…" thay vì
        // tràn xuống khung dưới (nguyên nhân chữ chồng nhau).
        if (layout.height > maxHeight) {
            val lineHeight = (layout.getLineBottom(0) - layout.getLineTop(0))
                .coerceAtLeast(1)
            val maxLines = (maxHeight / lineHeight).coerceAtLeast(1)
            layout = layoutAt(
                text,
                maxWidth,
                sizeSp,
                maxLines = maxLines,
                ellipsize = true,
            )
        }
        return layout
    }

    private fun layoutAt(
        text: String,
        maxWidth: Int,
        sizeSp: Float,
        maxLines: Int? = null,
        ellipsize: Boolean = false,
    ): StaticLayout {
        // TypedValue thay cho displayMetrics.scaledDensity (deprecated API 34)
        // và tôn trọng cỡ chữ hệ thống của người dùng.
        textPaint.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            sizeSp,
            resources.displayMetrics,
        )
        val builder = StaticLayout.Builder
            .obtain(text, 0, text.length, textPaint, maxWidth)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1.0f)
            .setIncludePad(false)
        if (maxLines != null) {
            builder.setMaxLines(maxLines)
            if (ellipsize) {
                builder.setEllipsize(TextUtils.TruncateAt.END)
                builder.setEllipsizedWidth(maxWidth)
            }
        }
        return builder.build()
    }
}
