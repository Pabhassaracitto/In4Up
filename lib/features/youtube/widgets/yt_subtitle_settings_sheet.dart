// YT-LR-002 / IN4-88 — Menu `Subtitle Settings` của màn học YouTube.
//
// • 4 chế độ hiển thị bản dịch (`YtTranslationMode`)
// • 3 bố cục danh sách phụ đề (`YtSubtitleLayout`)
// • thanh trượt ngưỡng tần suất / độ khó
//
// Mọi nhãn chrome đi qua `context.uiText()` + English fallback trong
// `tool/legacy_ui_english_overrides.json` (quy tắc vàng ADR-0002: locale ≠ vi
// không được rớt về tiếng Việt).

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;

import '../models/yt_learning_settings.dart';

/// Hiện menu cài đặt phụ đề. Trả về cài đặt mới (hoặc null nếu đóng).
Future<YtLearningSettings?> showYtSubtitleSettingsSheet(
  BuildContext context,
  YtLearningSettings current,
) {
  return showModalBottomSheet<YtLearningSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _YtSubtitleSettingsSheet(initial: current),
  );
}

class _YtSubtitleSettingsSheet extends StatefulWidget {
  final YtLearningSettings initial;
  const _YtSubtitleSettingsSheet({required this.initial});

  @override
  State<_YtSubtitleSettingsSheet> createState() =>
      _YtSubtitleSettingsSheetState();
}

class _YtSubtitleSettingsSheetState extends State<_YtSubtitleSettingsSheet> {
  late YtTranslationMode _mode;
  late YtSubtitleLayout _layout;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.translationMode;
    _layout = widget.initial.subtitleLayout;
    _threshold = widget.initial.frequencyRankThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.uiText('Cài đặt phụ đề'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _sectionLabel(context, 'Bản dịch'),
            _modeTile(
              context,
              YtTranslationMode.withTranslation,
              'Có bản dịch',
              'Hiện bản dịch bên dưới phụ đề gốc.',
            ),
            _modeTile(
              context,
              YtTranslationMode.hideTranslation,
              'Ẩn bản dịch',
              'Chỉ hiện phụ đề gốc của video.',
            ),
            _modeTile(
              context,
              YtTranslationMode.blurTranslation,
              'Làm mờ bản dịch',
              'Làm mờ bản dịch; bấm để hiện tạm.',
            ),
            _modeTile(
              context,
              YtTranslationMode.hideSubtitle,
              'Ẩn phụ đề',
              'Ẩn hoàn toàn phụ đề để luyện nghe.',
            ),
            const SizedBox(height: 12),
            _sectionLabel(context, 'Bố cục danh sách'),
            _layoutTile(
              context,
              YtSubtitleLayout.simple,
              'Danh sách đơn giản',
              'Transcript cuộn theo thời gian, một cột.',
            ),
            _layoutTile(
              context,
              YtSubtitleLayout.sideBySide,
              'Song song',
              'Phụ đề gốc và bản dịch nằm cạnh nhau.',
            ),
            _layoutTile(
              context,
              YtSubtitleLayout.stacked,
              'Trên và dưới',
              'Phụ đề gốc ở trên, bản dịch ở dưới.',
            ),
            const SizedBox(height: 12),
            _sectionLabel(context, 'Ngưỡng tần suất'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _threshold,
                    min: YtLearningSettings.kMinRank,
                    max: YtLearningSettings.kMaxRank,
                    divisions: ((YtLearningSettings.kMaxRank -
                                YtLearningSettings.kMinRank) /
                            YtLearningSettings.kRankStep)
                        .round(),
                    activeColor: const Color(0xFF9C27B0),
                    onChanged: (v) => setState(() => _threshold = v),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    _threshold.round().toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              context.uiText('Từ có rank nhỏ hơn ngưỡng được coi là đã quen.'),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  YtLearningSettings(
                    translationMode: _mode,
                    subtitleLayout: _layout,
                    frequencyRankThreshold: _threshold,
                  ),
                ),
                child: Text(context.uiText('Xong')),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        context.uiText(label),
        style: const TextStyle(
          color: Color(0xFF9C27B0),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _modeTile(
    BuildContext context,
    YtTranslationMode mode,
    String title,
    String subtitle,
  ) {
    final selected = _mode == mode;
    return _optionTile(
      selected: selected,
      title: context.uiText(title),
      subtitle: context.uiText(subtitle),
      onTap: () => setState(() => _mode = mode),
    );
  }

  Widget _layoutTile(
    BuildContext context,
    YtSubtitleLayout layout,
    String title,
    String subtitle,
  ) {
    final selected = _layout == layout;
    return _optionTile(
      selected: selected,
      title: context.uiText(title),
      subtitle: context.uiText(subtitle),
      onTap: () => setState(() => _layout = layout),
    );
  }

  Widget _optionTile({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9C27B0).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF9C27B0) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? const Color(0xFF9C27B0) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
