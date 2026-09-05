// lib/features/pdf_reader/widgets/pdf_tts_bar.dart
//
// Thanh đọc to. Hai lỗi cũ của nó:
//   • nút ⏭/⏮ trang là NÚT GIẢ (onTap chỉ gọi callback + haptic, không làm gì);
//   • Play đọc nguyên trang một khối → không highlight, không dừng giữa câu,
//     không tự lật trang, không resume.
// Giờ: đọc THEO CÂU, câu đang đọc được tô sáng bởi PdfWordOverlay, tới cuối
// trang thì tự sang trang kế (tắt được), và Pause/Resume thật.
// localized_material EXPORT material (chỉ hide `Text` để thay bằng shim dịch
// nhãn) — import thẳng material ở đây sẽ làm `Text` thành ambiguous và còn bỏ
// qua catalog, nên chỉ import shim.
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../pdf_reader_controller.dart';

class PdfTtsBar extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const PdfTtsBar({
    super.key,
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final playing = controller.ttsState == PdfTtsState.playing;
    final paused = controller.ttsState == PdfTtsState.paused;
    final loading = controller.ttsState == PdfTtsState.loading;
    final active = controller.isReadingActive;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_statusLabel(context, playing, paused, active),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: active && controller.totalCues > 0
                        ? ((controller.readingCueIndex + 1) /
                            controller.totalCues)
                        : null,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _BarBtn(
            icon: Icons.skip_previous_rounded,
            tooltip: context.uiText('Trang trước'),
            onTap: controller.currentPage > 0
                ? () {
                    onUserInteraction?.call();
                    HapticFeedback.selectionClick();
                    controller.previousPage();
                  }
                : null,
          ),
          const SizedBox(width: 4),
          _BarBtn(
            icon: Icons.undo_rounded,
            tooltip: context.uiText('Câu trước'),
            onTap: active
                ? () {
                    onUserInteraction?.call();
                    HapticFeedback.selectionClick();
                    controller.stepSentence(-1);
                  }
                : null,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              onUserInteraction?.call();
              HapticFeedback.mediumImpact();
              controller.speakCurrentPage();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: playing
                    ? const Color(0xFF2196F3)
                    : (paused ? const Color(0xFFFFB300) : const Color(0xFF2196F3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3)
                        .withValues(alpha: playing ? 0.35 : 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_rounded
                          : (paused
                              ? Icons.play_arrow_rounded
                              : (active
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded)),
                      color: Colors.white,
                      size: 25,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          _BarBtn(
            icon: Icons.redo_rounded,
            tooltip: context.uiText('Câu kế tiếp'),
            onTap: active
                ? () {
                    onUserInteraction?.call();
                    HapticFeedback.selectionClick();
                    controller.stepSentence(1);
                  }
                : null,
          ),
          const SizedBox(width: 4),
          _BarBtn(
            icon: Icons.skip_next_rounded,
            tooltip: context.uiText('Trang kế'),
            onTap: controller.currentPage < controller.totalPages - 1
                ? () {
                    onUserInteraction?.call();
                    HapticFeedback.selectionClick();
                    controller.nextPage();
                  }
                : null,
          ),
          const SizedBox(width: 6),
          // Auto-advance trang — đọc liên tục như audiobook.
          _BarBtn(
            icon: controller.ttsAutoAdvance
                ? Icons.auto_awesome_motion_rounded
                : Icons.radio_button_unchecked_rounded,
            tooltip: context.uiText('Tự lật trang khi đọc xong'),
            active: controller.ttsAutoAdvance,
            onTap: () {
              onUserInteraction?.call();
              HapticFeedback.selectionClick();
              controller.setTtsAutoAdvance(!controller.ttsAutoAdvance);
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              onUserInteraction?.call();
              TtsSpeedPickerSheet.show(context, controller);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${controller.ttsSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ghép từ các chuỗi NGUYÊN VĂN đã có trong catalog: `context.uiText` chỉ
  // khớp exact/template đã review, còn chuỗi nội suy tự do sẽ lọt tiếng Việt
  // sang locale khác (quy tắc vàng #5).
  String _statusLabel(
    BuildContext context,
    bool playing,
    bool paused,
    bool active,
  ) {
    if (playing || paused) {
      final cue = controller.currentCue;
      final page = (cue?.pageIndex ?? controller.currentPage) + 1;
      final parts = <String>[
        context.uiText(playing ? 'Đang đọc' : 'Tạm dừng'),
        controller.readingProgressLabel,
        '$page',
      ];
      return parts.where((p) => p.isNotEmpty).join(' · ');
    }
    if (controller.pageHasNoTextLayer) {
      return context.uiText('Trang này là ảnh, không có chữ để đọc');
    }
    return context.uiText('Đọc to theo câu');
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool active;

  const _BarBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF2196F3).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: onTap != null ? 0.07 : 0.03),
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.4))
                : null,
          ),
          child: Icon(
            icon,
            size: 19,
            color: onTap == null
                ? Colors.grey[700]
                : (active ? const Color(0xFF64B5F6) : Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// Danh sách tốc độ đọc — giữ nguyên kiểu "chip to, bấm là được" vì thanh TTS
/// hay dùng khi đang cầm điện thoại một tay.
class TtsSpeedPickerSheet {
  static Future<void> show(BuildContext context, PdfReaderController controller) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.uiText('Tốc độ đọc'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                context.uiText('Chậm lại để bắt kịp âm; nhanh để ôn lại bài đã quen.'),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.5, 0.7, 0.9, 1.0, 1.2, 1.5, 1.75].map((speed) {
                  final selected = (controller.ttsSpeed - speed).abs() < 0.05;
                  return GestureDetector(
                    onTap: () {
                      controller.setTtsSpeed(speed);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2196F3)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      );
}
