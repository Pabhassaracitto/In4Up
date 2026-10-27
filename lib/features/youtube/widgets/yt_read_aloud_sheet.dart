// YT-TTS-READ-001 — bảng "Đọc bản dịch" của màn học YouTube.
//
// Owner (2026-10-24): "chưa thoả mãn với việc chỉ dịch ra chữ… có thể phát
// luôn âm thanh đã dịch (TTS online hoặc offline, ưu tiên online nếu WiFi,
// ưu tiên offline nếu 4G nhưng vẫn có fallback), kiểu tab Đọc đang có chế độ
// đọc song ngữ, có đọc lặp mấy lần và đọc xen kẽ hay bên nhiều bên ít".
//
// Bảng này KHÔNG tự chứa logic đọc: nó chỉ chỉnh cài đặt (lưu vào
// `YtLearningSettings`) rồi trả kết quả để màn player chạy
// `YtReadAloudController`. Nhờ vậy đóng bảng vẫn đọc tiếp được.

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;

import '../models/yt_learning_settings.dart';
import '../../tts/tts_settings.dart';
import '../../tts/tts_service.dart';

/// Trả về cài đặt mới + hành động người dùng vừa chọn.
class YtReadAloudSheetResult {
  const YtReadAloudSheetResult({
    required this.settings,
    required this.start,
    this.fromCurrentLine = true,
  });

  final YtLearningSettings settings;

  /// `true` = bấm "Đọc ngay"; `false` = chỉ lưu cài đặt rồi đóng.
  final bool start;

  /// Đọc từ dòng đang phát hay từ đầu danh sách.
  final bool fromCurrentLine;
}

Future<YtReadAloudSheetResult?> showYtReadAloudSheet(
  BuildContext context,
  YtLearningSettings current,
  TtsService tts, {
  required bool hasTranslation,
}) {
  return showModalBottomSheet<YtReadAloudSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _YtReadAloudSheet(
      initial: current,
      tts: tts,
      hasTranslation: hasTranslation,
    ),
  );
}

class _YtReadAloudSheet extends StatefulWidget {
  const _YtReadAloudSheet({
    required this.initial,
    required this.tts,
    required this.hasTranslation,
  });

  final YtLearningSettings initial;
  final TtsService tts;
  final bool hasTranslation;

  @override
  State<_YtReadAloudSheet> createState() => _YtReadAloudSheetState();
}

class _YtReadAloudSheetState extends State<_YtReadAloudSheet> {
  late YtReadAloudMode _mode;
  late int _srcRepeats;
  late int _tgtRepeats;
  late int _gapMs;
  late double _speed;
  late bool _fromCurrent;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.readAloudMode;
    _srcRepeats = widget.initial.readAloudSourceRepeats;
    _tgtRepeats = widget.initial.readAloudTargetRepeats;
    _gapMs = widget.initial.readAloudGapMs;
    _speed = widget.initial.readAloudSpeed;
    _fromCurrent = true;

    // Chưa có bản dịch ⇒ mặc định đọc bản gốc, đừng để người dùng bấm rồi
    // mới biết không có gì để đọc.
    if (!widget.hasTranslation && _mode == YtReadAloudMode.targetOnly) {
      _mode = YtReadAloudMode.sourceOnly;
    }
    if (!widget.hasTranslation && _mode == YtReadAloudMode.interleaved) {
      _mode = YtReadAloudMode.sourceOnly;
    }
  }

  YtLearningSettings get _result => widget.initial.copyWith(
        readAloudMode: _mode,
        readAloudSourceRepeats: _srcRepeats,
        readAloudTargetRepeats: _tgtRepeats,
        readAloudGapMs: _gapMs,
        readAloudSpeed: _speed,
      );

  /// Chế độ đọc hiện tại có thật sự đọc bản dịch không — dùng để cảnh báo.
  bool get _readsTarget =>
      _mode == YtReadAloudMode.targetOnly ||
      _mode == YtReadAloudMode.interleaved;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.record_voice_over,
                    size: 18, color: Color(0xFF53D6BD)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Đọc bản dịch thành tiếng'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(
                  'Phụ đề và bản dịch được đọc bằng giọng nói, không phụ thuộc âm thanh của video.'),
              style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 14),

            // ── Chế độ ────────────────────────────────────────────
            _label(context.uiText('Đọc gì')),
            const SizedBox(height: 8),
            _modeTile(
              context,
              YtReadAloudMode.sourceOnly,
              context.uiText('Chỉ bản gốc'),
              context.uiText('Luyện nghe/đọc đúng phát âm gốc'),
            ),
            _modeTile(
              context,
              YtReadAloudMode.targetOnly,
              context.uiText('Chỉ bản dịch'),
              context.uiText('Nghe âm thanh đã dịch — đúng ý cần nghe bản dịch'),
              enabled: widget.hasTranslation,
            ),
            _modeTile(
              context,
              YtReadAloudMode.interleaved,
              context.uiText('Xen kẽ gốc → dịch'),
              context.uiText('Đọc gốc rồi đọc bản dịch ngay sau đó'),
              enabled: widget.hasTranslation,
            ),

            if (!widget.hasTranslation) ...[
              const SizedBox(height: 8),
              _note(
                context.uiText(
                    'Chưa có bản dịch cho video này nên chỉ đọc được bản gốc.'),
                Colors.amber,
              ),
            ],

            const SizedBox(height: 16),
            _label(context.uiText('Số lần lặp mỗi dòng')),
            const SizedBox(height: 8),
            _stepper(
              context,
              label: context.uiText('Bản gốc'),
              value: _srcRepeats,
              onChanged: (v) => setState(() => _srcRepeats = v),
              enabled: _mode != YtReadAloudMode.targetOnly,
            ),
            const SizedBox(height: 8),
            _stepper(
              context,
              label: context.uiText('Bản dịch'),
              value: _tgtRepeats,
              onChanged: (v) => setState(() => _tgtRepeats = v),
              enabled:
                  _mode != YtReadAloudMode.sourceOnly && widget.hasTranslation,
            ),
            const SizedBox(height: 6),
            Text(
              _srcRepeats == 2 && _tgtRepeats == 1
                  ? context.uiText('Bên nhiều bên ít: gốc 2 lần, dịch 1 lần')
                  : context.uiText(
                      'Bên nhiều bên ít: đặt hai số khác nhau (vd gốc 2 · dịch 1)'),
              style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
            ),

            const SizedBox(height: 16),
            _label(context.uiText('Khoảng nghỉ giữa hai lượt')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _gapChip(context, 0, context.uiText('Không nghỉ')),
                _gapChip(context, 500, context.uiText('Thư giãn')),
                _gapChip(context, 1500, context.uiText('Suy nghĩ')),
                _gapChip(context, 3000, context.uiText('Tự kiểm tra')),
              ],
            ),

            const SizedBox(height: 16),
            _label('${context.uiText('Tốc độ đọc')} · ${_speed.toStringAsFixed(1)}x'),
            Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_speed.toStringAsFixed(1)}x',
              activeColor: const Color(0xFF53D6BD),
              onChanged: (v) => setState(() => _speed = v),
            ),

            const SizedBox(height: 8),
            _label(context.uiText('Đọc từ đâu')),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _fromCurrent,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF53D6BD),
              title: Text(
                context.uiText('Từ dòng đang phát'),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                context.uiText('Tắt để đọc lại từ dòng đầu tiên'),
                style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
              ),
              onChanged: (v) => setState(() => _fromCurrent = v),
            ),

            const SizedBox(height: 4),
            // Nguồn giọng THẬT đang cấu hình — nói thẳng để người dùng biết
            // vì sao đôi khi phải chờ (online) hay nghe giọng máy (offline).
            _note(
              '${context.uiText('Nguồn giọng')}: ${_voiceSourceLabel(context)}',
              Colors.blueGrey,
            ),

            if (_readsTarget && _srcRepeats == 0 && _tgtRepeats == 0) ...[
              const SizedBox(height: 8),
              _note(
                context.uiText('Cả hai bên đều đặt 0 lần — sẽ không đọc gì.'),
                Colors.orange,
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      YtReadAloudSheetResult(
                        settings: _result,
                        start: false,
                        fromCurrentLine: _fromCurrent,
                      ),
                    ),
                    child: Text(context.uiText('Lưu')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF53D6BD),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      YtReadAloudSheetResult(
                        settings: _result,
                        start: true,
                        fromCurrentLine: _fromCurrent,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(context.uiText('Đọc ngay')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _voiceSourceLabel(BuildContext context) {
    final p = widget.tts.priority;
    final label = switch (p) {
      TtsPriority.auto => context.uiText('Tự động theo mạng'),
      TtsPriority.offlineFirst => context.uiText('Offline trước (nhanh)'),
      TtsPriority.onlineFirst => context.uiText('Online trước (tự nhiên)'),
      TtsPriority.offlineOnly => context.uiText('Chỉ Offline'),
      TtsPriority.onlineOnly => context.uiText('Chỉ Online'),
    };
    return label;
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF53D6BD),
          letterSpacing: 0.3,
        ),
      );

  Widget _note(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          // Màu chữ lấy CHÍNH màu khung (đậm hơn nền 12% alpha nên vẫn đọc
          // được). Không dùng `shade100` — đó là API của MaterialColor, còn
          // tham số ở đây là `Color` nên sẽ không biên dịch được.
          style: TextStyle(color: color, fontSize: 10.5, height: 1.4),
        ),
      );

  Widget _modeTile(
    BuildContext context,
    YtReadAloudMode mode,
    String title,
    String subtitle, {
    bool enabled = true,
  }) {
    final selected = _mode == mode;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled ? () => setState(() => _mode = mode) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF53D6BD).withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF53D6BD) : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected ? const Color(0xFF53D6BD) : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.5,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          SizedBox(
            width: 24,
            child: Text(
              context.uiText('$value'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: enabled && value < 5 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _gapChip(BuildContext context, int ms, String label) {
    final selected = _gapMs == ms;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      selectedColor: const Color(0xFF53D6BD).withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _gapMs = ms),
    );
  }
}
