package com.in4up.screentranslate

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.view.MotionEvent
import android.view.View
import kotlin.math.max
import kotlin.math.min

/**
 * XLAT-SCR-005 (owner 24/10) — lớp phủ KÉO CHỌN VÙNG cần dịch.
 *
 * Vì sao có: trước đây mỗi lần bấm bong bóng là chụp + OCR + dịch CẢ màn hình.
 * Người dùng thường chỉ cần một đoạn văn/bảng ⇒ vừa chậm, vừa dịch cả những
 * thứ không cần (tốn quota engine online).
 *
 * Luật an toàn (bài học từ sự cố "kéo chọn vùng xong là SẬP" trong
 * `PROMPT_AGENT_SCREEN_TRANSLATE_BUBBLE.md`):
 *  1. KHÔNG giữ Bitmap, KHÔNG giữ `Image`/`ByteBuffer` — view này chỉ vẽ hình
 *     chữ nhật bằng [Paint] đã cấp phát sẵn. Không có gì để rò rỉ hay bị thu
 *     hồi giữa đường.
 *  2. KHÔNG cấp phát trong [onDraw] (tránh GC giật khi người dùng đang kéo).
 *  3. Toạ độ LUÔN clamp theo kích thước THẬT của view (không dùng
 *     `DisplayMetrics` — sai lệch khi xoay máy/cửa sổ chia đôi màn hình là
 *     nguồn của toạ độ âm ⇒ native cắt ảnh với Rect rỗng ⇒ crash).
 *  4. Service gỡ view này KHỎI WindowManager **trước** khi chụp, rồi mới chụp
 *     (nếu không, ảnh chụp sẽ dính luôn lớp phủ tối + viền chọn).
 *  5. Mọi callback được service bọc try/catch; view tự kết thúc phiên chọn
 *     trước khi trả kết quả.
 *
 * Thao tác: kéo một khung. Chạm/kéo quá ngắn (< [minSizePx]) = HUỶ (báo cho
 * người dùng biết), không bao giờ im lặng.
 */
class RegionSelectView(
    context: Context,
    private val hintText: String,
    private val onRegionSelected: (Rect) -> Unit,
    /** [tooSmall] = false khi người dùng chỉ CHẠM (ý là huỷ), true khi kéo
     *  một khung quá bé. Service dùng cờ này để chọn đúng câu thông báo. */
    private val onCancelled: (tooSmall: Boolean) -> Unit,
) : View(context) {

    private val density = context.resources.displayMetrics.density

    /** Khung tối thiểu để coi là "có chọn vùng" (dp). */
    private val minSizePx = (MIN_SIZE_DP * density).toInt().coerceAtLeast(8)

    private val dimPaint = Paint().apply {
        color = Color.argb(150, 0, 0, 0)
        style = Paint.Style.FILL
    }

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(255, 41, 182, 246)
        style = Paint.Style.STROKE
        strokeWidth = 3f * density
    }

    /** Viền ngoài mờ để khung nổi trên nền tối. */
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(60, 41, 182, 246)
        style = Paint.Style.STROKE
        strokeWidth = 10f * density
    }

    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 14f * density
        typeface = Typeface.DEFAULT_BOLD
    }

    private val hintBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(210, 20, 24, 38)
        style = Paint.Style.FILL
    }

    private val selection = Rect()

    private var anchorX = 0f
    private var anchorY = 0f
    private var dragging = false
    private var finished = false

    /** Dưới ngưỡng này ở CẢ hai chiều = người dùng chỉ chạm để huỷ. */
    private val tapSlopPx = (8 * density).toInt().coerceAtLeast(2)

    /** Cấp phát sẵn — onDraw không được tạo object mới. */
    private val dimTop = Rect()
    private val dimBottom = Rect()
    private val dimLeft = Rect()
    private val dimRight = Rect()

    init {
        // View toàn màn hình, nhận chạm (khác overlay bản dịch — cái đó
        // NOT_TOUCHABLE vì người dùng còn phải dùng app bên dưới).
        isClickable = true
        isFocusable = false
        contentDescription = hintText
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width
        val h = height

        if (!selection.isEmpty() && dragging) {
            // Tô tối 4 dải quanh khung chọn (KHÔNG dùng PorterDuff.CLEAR ⇒
            // không cần LAYER_TYPE_SOFTWARE, tránh tốn bộ nhớ đồ hoạ).
            dimTop.set(0, 0, w, selection.top)
            dimBottom.set(0, selection.bottom, w, h)
            dimLeft.set(0, selection.top, selection.left, selection.bottom)
            dimRight.set(selection.right, selection.top, w, selection.bottom)
            canvas.drawRect(dimTop, dimPaint)
            canvas.drawRect(dimBottom, dimPaint)
            canvas.drawRect(dimLeft, dimPaint)
            canvas.drawRect(dimRight, dimPaint)

            canvas.drawRect(selection, glowPaint)
            canvas.drawRect(selection, borderPaint)
        } else {
            canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), dimPaint)
        }

        drawHint(canvas, w)
    }

    private fun drawHint(canvas: Canvas, viewWidth: Int) {
        val padding = 12f * density
        val textWidth = hintPaint.measureText(hintText)
        val textHeight = hintPaint.descent() - hintPaint.ascent()
        val boxWidth = textWidth + padding * 2
        val boxHeight = textHeight + padding
        val left = max(0f, (viewWidth - boxWidth) / 2f)
        val top = 48f * density
        val radius = boxHeight / 2f
        canvas.drawRoundRect(
            left,
            top,
            left + boxWidth,
            top + boxHeight,
            radius,
            radius,
            hintBgPaint,
        )
        canvas.drawText(
            hintText,
            left + padding,
            top + padding / 2 - hintPaint.ascent(),
            hintPaint,
        )
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (finished) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                anchorX = event.x.coerceIn(0f, width.toFloat())
                anchorY = event.y.coerceIn(0f, height.toFloat())
                selection.set(
                    anchorX.toInt(),
                    anchorY.toInt(),
                    anchorX.toInt(),
                    anchorY.toInt(),
                )
                dragging = true
                invalidate()
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                if (!dragging) return false
                val x = event.x.coerceIn(0f, width.toFloat())
                val y = event.y.coerceIn(0f, height.toFloat())
                selection.set(
                    min(anchorX, x).toInt(),
                    min(anchorY, y).toInt(),
                    max(anchorX, x).toInt(),
                    max(anchorY, y).toInt(),
                )
                invalidate()
                return true
            }

            MotionEvent.ACTION_UP -> {
                if (!dragging) return false
                dragging = false
                invalidate()
                finishSession()
                return true
            }

            MotionEvent.ACTION_CANCEL -> {
                if (!dragging) return false
                dragging = false
                finishSession()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    /**
     * Kết thúc phiên chọn: chốt khung rồi mới gọi callback.
     *
     * View KHÔNG tự remove khỏi WindowManager — service làm việc đó (nó là
     * bên sở hữu `WindowManager`). Nhưng [finished] chặn mọi chạm tiếp theo
     * ngay lập tức, nên không thể có hai callback cho một lần kéo.
     */
    private fun finishSession() {
        if (finished) return
        finished = true
        val area = Rect(selection)
        val tapOnly = area.width() < tapSlopPx && area.height() < tapSlopPx
        val tooSmall =
            area.width() < minSizePx || area.height() < minSizePx || area.isEmpty()
        try {
            if (tapOnly) {
                // Chạm suông = "thôi, không chọn nữa" — KHÔNG doạ người dùng
                // bằng câu "vùng chọn quá nhỏ".
                onCancelled(false)
            } else if (tooSmall) {
                onCancelled(true)
            } else {
                onRegionSelected(area)
            }
        } catch (e: Exception) {
            // Callback là code của service; lỗi ở đó KHÔNG được làm sập app.
            e.printStackTrace()
        }
    }

    companion object {
        /** Cạnh nhỏ nhất (dp) của một vùng chọn hợp lệ. */
        const val MIN_SIZE_DP = 28

        /** Nhãn huỷ dùng khi người dùng chạm nhầm (chỉ để log/test). */
        const val TAG = "In4upRegionSelect"
    }
}
