package com.in4up.screentranslate

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.TypedValue
import android.view.View

/**
 * XLAT-SCR-002 — lớp vẽ bản dịch ĐÈ lên màn hình (kiểu Google Lens).
 *
 * Nhận danh sách [TranslatedBlock] với toạ độ PIXEL MÀN HÌNH (Dart đã quy đổi
 * qua `mapCaptureRectToOverlay`, xem `screen_translate_geometry.dart`) — view
 * này KHÔNG tự scale lại lần nữa. Một công thức, một chỗ.
 *
 * Chiến lược vẽ: nền tối mờ phủ đúng khung chữ gốc (để chữ bên dưới không
 * lẫn vào), rồi vẽ bản dịch bằng [StaticLayout] (tự xuống dòng). Chữ không
 * vừa khung thì GIẢM cỡ dần tới 9sp; vẫn không vừa thì cho tràn xuống dưới
 * khung — thà đọc được còn hơn bị cắt mất chữ.
 */
class TranslationOverlayView(context: Context) : View(context) {

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
            val padding = 4f

            val layout = buildLayout(
                text = text,
                maxWidth = (width - padding * 2).toInt().coerceAtLeast(8),
                maxHeight = height,
                startSizeSp = block.textSizeSp,
            )

            val boxHeight = maxOf(height.toFloat(), layout.height + padding * 2)
            val rect = RectF(
                block.left.toFloat(),
                block.top.toFloat(),
                block.right.toFloat(),
                block.top + boxHeight,
            )
            canvas.drawRoundRect(rect, 6f, 6f, boxPaint)
            canvas.drawRoundRect(rect, 6f, 6f, edgePaint)

            canvas.save()
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
        var sizeSp = startSizeSp.coerceIn(9f, 28f)
        var layout = layoutAt(text, maxWidth, sizeSp)
        // Tối đa 6 lần thu nhỏ: đủ đi từ 28sp xuống 9sp mà không vòng lặp dài
        // trên onDraw (vẽ lại mỗi frame).
        var attempts = 0
        while (layout.height > maxHeight && sizeSp > 9f && attempts < 6) {
            sizeSp = (sizeSp - 2f).coerceAtLeast(9f)
            layout = layoutAt(text, maxWidth, sizeSp)
            attempts++
        }
        return layout
    }

    private fun layoutAt(
        text: String,
        maxWidth: Int,
        sizeSp: Float,
    ): StaticLayout {
        // TypedValue thay cho displayMetrics.scaledDensity (deprecated API 34)
        // và tôn trọng cỡ chữ hệ thống của người dùng.
        textPaint.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            sizeSp,
            resources.displayMetrics,
        )
        return StaticLayout.Builder
            .obtain(text, 0, text.length, textPaint, maxWidth)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1.0f)
            .setIncludePad(false)
            .build()
    }
}
