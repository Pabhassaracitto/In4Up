// PLAN-043 mục 2 — Sheet cài đặt "Đọc từ + nghĩa" của Worklist.
// Chỉ sửa [WordlistReadSettings] (model thuần); việc lưu + phát nằm ở
// `WordlistPlaybackService`. Mặc định: Từ ×2 → Nghĩa ×1 (chốt owner).

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../../../core/language/app_language.dart';
import 'wordlist_read_sequence.dart';

class WordlistReadSettingsSheet extends StatefulWidget {
  final WordlistReadSettings initial;

  const WordlistReadSettingsSheet({super.key, required this.initial});

  static Future<WordlistReadSettings?> show(
    BuildContext context,
    WordlistReadSettings initial,
  ) {
    return showModalBottomSheet<WordlistReadSettings>(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WordlistReadSettingsSheet(initial: initial),
    );
  }

  @override
  State<WordlistReadSettingsSheet> createState() =>
      _WordlistReadSettingsSheetState();
}

class _WordlistReadSettingsSheetState
    extends State<WordlistReadSettingsSheet> {
  late WordlistReadSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.initial;
  }

  String _modeLabel(WordlistReadMode mode) {
    switch (mode) {
      case WordlistReadMode.wordOnly:
        return context.uiText('Chỉ từ');
      case WordlistReadMode.meaningOnly:
        return context.uiText('Chỉ nghĩa');
      case WordlistReadMode.wordThenMeaning:
        return context.uiText('Từ → Nghĩa');
      case WordlistReadMode.meaningThenWord:
        return context.uiText('Nghĩa → Từ');
      case WordlistReadMode.recall:
        return context.uiText('Gợi nhớ: nghĩa → lặng → từ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              context.uiText('Đọc từ + nghĩa'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(
                  'Áp dụng cho nút Phát và chạm loa từng từ. Ngôn ngữ của TỪ lấy theo từng mục.'),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 16),
            _label(context.uiText('Thứ tự đọc')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in WordlistReadMode.values)
                  ChoiceChip(
                    label: Text(_modeLabel(mode)),
                    selected: _s.mode == mode,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _s = _s.copyWith(mode: mode));
                    },
                  ),
              ],
            ),
            if (_s.mode == WordlistReadMode.recall) ...[
              const SizedBox(height: 8),
              Text(
                context.uiText(
                    'Ở chế độ Gợi nhớ, khoảng nghỉ giữa nghĩa và từ là thời gian để bạn tự nhớ từ trước khi nghe đáp án.'),
                style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 16),
            _stepper(
              label: context.uiText('Số lần đọc TỪ'),
              value: _s.wordRepeats,
              onChanged: (v) => setState(() => _s = _s.copyWith(wordRepeats: v)),
            ),
            _stepper(
              label: context.uiText('Số lần đọc NGHĨA'),
              value: _s.meaningRepeats,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(meaningRepeats: v)),
            ),
            const SizedBox(height: 8),
            _label(context.uiText('Khoảng nghỉ giữa từ và nghĩa')),
            _gapChips(
              currentMs: _s.gapBetweenSidesMs,
              optionsMs: const [0, 700, 1500, 3000, 5000],
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(gapBetweenSidesMs: v)),
            ),
            const SizedBox(height: 12),
            _label(context.uiText('Khoảng nghỉ giữa các từ')),
            _gapChips(
              currentMs: _s.gapBetweenWordsMs,
              optionsMs: const [0, 500, 1000, 2000],
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(gapBetweenWordsMs: v)),
            ),
            const SizedBox(height: 16),
            _label(context.uiText('Ngôn ngữ đọc nghĩa')),
            DropdownButtonFormField<String>(
              key: ValueKey(_meaningLanguageValue()),
              initialValue: _meaningLanguageValue(),
              dropdownColor: const Color(0xFF16202F),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text(context.uiText('Tự động theo nội dung')),
                ),
                for (final lang in AppLanguageCatalog.languages)
                  DropdownMenuItem(
                    value: lang.appLocaleCode,
                    child: Text('${lang.flag} ${lang.nativeName}'),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _s = _s.copyWith(meaningLanguage: v));
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _s = const WordlistReadSettings()),
                  child: Text(context.uiText('Đặt lại mặc định')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _s),
                  child: Text(context.uiText('Lưu')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Giá trị dropdown phải khớp một item — mã lạ (vd 'zh-CN' đã lưu) được
  /// chuẩn hoá về appLocaleCode qua catalog; không khớp thì 'auto'.
  String _meaningLanguageValue() {
    final raw = _s.meaningLanguage.trim();
    if (raw.isEmpty || raw == 'auto') return 'auto';
    final lang = AppLanguageCatalog.maybeFromCode(raw);
    return lang?.appLocaleCode ?? 'auto';
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _stepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        IconButton(
          onPressed:
              value <= 0 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline, size: 20),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed:
              value >= 5 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline, size: 20),
        ),
      ],
    );
  }

  Widget _gapChips({
    required int currentMs,
    required List<int> optionsMs,
    required ValueChanged<int> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ms in optionsMs)
          ChoiceChip(
            label: Text(_gapLabel(ms)),
            selected: currentMs == ms,
            onSelected: (_) => onChanged(ms),
          ),
      ],
    );
  }

  String _gapLabel(int ms) {
    if (ms == 0) return context.uiText('Không nghỉ');
    final seconds = ms / 1000;
    final text = seconds == seconds.roundToDouble()
        ? seconds.toInt().toString()
        : seconds.toStringAsFixed(1);
    return '$text ${context.uiText('giây')}';
  }
}
