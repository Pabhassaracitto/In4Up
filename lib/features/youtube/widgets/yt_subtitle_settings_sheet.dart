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
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;

import 'package:in4up/features/translation/translation_service.dart';

import '../models/yt_learning_settings.dart';

/// Hiện menu cài đặt phụ đề. Trả về cài đặt mới (hoặc null nếu đóng).
///
/// YT-AUDIT-04 (IN4-103): nhận thêm [videoId] + [availableLangs] để ô
/// "Ngôn ngữ phụ đề gốc" liệt kê đúng các track thật của video (thay vì một
/// danh sách cứng).
Future<YtLearningSettings?> showYtSubtitleSettingsSheet(
  BuildContext context,
  YtLearningSettings current, {
  String? videoId,
  List<({String code, String name})> availableLangs = const [],
  // YT-AUDIT-11 (IN4-106): độ trễ kênh WebView → Flutter ĐÃ ĐO (ms) ở màn
  // player — 0 nghĩa là chưa đủ mẫu. Dùng để GỢI Ý, không tự áp.
  int measuredLagMs = 0,
}) {
  return showModalBottomSheet<YtLearningSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _YtSubtitleSettingsSheet(
      initial: current,
      videoId: videoId,
      availableLangs: availableLangs,
      measuredLagMs: measuredLagMs,
    ),
  );
}

class _YtSubtitleSettingsSheet extends StatefulWidget {
  final YtLearningSettings initial;
  final String? videoId;
  final List<({String code, String name})> availableLangs;
  final int measuredLagMs;

  const _YtSubtitleSettingsSheet({
    required this.initial,
    this.videoId,
    this.availableLangs = const [],
    this.measuredLagMs = 0,
  });

  @override
  State<_YtSubtitleSettingsSheet> createState() =>
      _YtSubtitleSettingsSheetState();
}

class _YtSubtitleSettingsSheetState extends State<_YtSubtitleSettingsSheet> {
  late YtTranslationMode _mode;
  late YtSubtitleLayout _layout;
  late double _threshold;
  // YT-AUDIT-10 (IN4-102): tự cuộn tab VĂN BẢN theo dòng đang phát.
  late bool _autoFollow;
  // YT-AUDIT-04 (IN4-103): ngôn ngữ phụ đề gốc + ngôn ngữ dịch.
  late String _subtitleLang;
  late String? _targetLang;
  // YT-AUDIT-11 (IN4-106): bù trễ âm thanh/chữ (ms).
  late double _audioLead;

  /// Giá trị giả cho mục "Theo Cài đặt Home" trong ô chọn ngôn ngữ dịch
  /// (`null` thật không dùng được làm value của DropdownButton).
  static const String _kFollowHome = '__home__';

  /// Phụ đề gốc rỗng (chưa nạp kịp) ⇒ danh sách mặc định để vẫn chọn được.
  static const _fallbackSubtitleLangs = <({String code, String name})>[
    (code: 'en', name: 'English'),
    (code: 'a.en', name: 'English (auto)'),
    (code: 'vi', name: 'Vietnamese'),
    (code: 'ja', name: 'Japanese'),
    (code: 'ko', name: 'Korean'),
    (code: 'zh-Hans', name: 'Chinese (Simplified)'),
    (code: 'fr', name: 'French'),
    (code: 'de', name: 'German'),
    (code: 'es', name: 'Spanish'),
  ];

  List<({String code, String name})> get _subtitleLangs {
    final source = widget.availableLangs.isEmpty
        ? _fallbackSubtitleLangs
        : widget.availableLangs;
    // DropdownButton assert khi 2 mục trùng value ⇒ khử trùng ở đây (danh sách
    // từ `getAvailableLanguages` đã khử, nhưng phòng cả fallback).
    final seen = <String>{};
    final out = <({String code, String name})>[];
    for (final it in source) {
      if (seen.add(it.code)) out.add(it);
    }
    // Ngôn ngữ đang chọn PHẢI có mặt trong danh sách — nếu không DropdownButton
    // vừa ném assert vừa hiển thị sai giá trị.
    if (!seen.contains(_subtitleLang)) {
      out.insert(0, (code: _subtitleLang, name: _subtitleLang));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.translationMode;
    _layout = widget.initial.subtitleLayout;
    _threshold = widget.initial.frequencyRankThreshold;
    _autoFollow = widget.initial.transcriptAutoFollow;
    _subtitleLang = widget.initial.subtitleLang;
    _targetLang = widget.initial.targetLang;
    _audioLead = widget.initial.audioLeadMs;
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
            // YT-AUDIT-04 (IN4-103): ngôn ngữ phụ đề gốc + ngôn ngữ dịch.
            // Mặc định: phụ đề `en`, ngôn ngữ dịch THEO CÀI ĐẶT HOME.
            _sectionLabel(context, 'Ngôn ngữ'),
            _langDropdown(
              context,
              label: context.uiText('Phụ đề gốc'),
              value: _subtitleLang,
              items: _subtitleLangs,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _subtitleLang = v);
              },
            ),
            const SizedBox(height: 10),
            _langDropdown(
              context,
              label: context.uiText('Ngôn ngữ dịch'),
              value: _targetLang ?? _kFollowHome,
              items: <({String code, String name})>[
                (code: _kFollowHome, name: context.uiText('Theo Cài đặt Home')),
                ...AppLanguageCatalog.languages.map(
                  (l) => (
                    code: l.translationCode.toLowerCase(),
                    name: l.pickerLabel,
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _targetLang = v == _kFollowHome ? null : v);
              },
            ),
            const SizedBox(height: 8),
            _buildLanguageHint(context),
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
            // YT-AUDIT-10 (IN4-102): cùng chỗ với các tuỳ chọn khác để
            // người dùng tìm thấy cả ở đây lẫn ngay đầu tab VĂN BẢN.
            _sectionLabel(context, 'Theo dòng đang phát'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoFollow,
              activeColor: const Color(0xFF9C27B0),
              title: Text(
                context.uiText('Tự động theo dòng hiện tại'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                context.uiText(
                  'Tab VĂN BẢN tự cuộn theo phụ đề đang nói. Tắt để cuộn tự do.',
                ),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              onChanged: (v) => setState(() => _autoFollow = v),
            ),
            const SizedBox(height: 6),
            // YT-AUDIT-11 (IN4-106): bù trễ âm thanh & chữ.
            _sectionLabel(context, 'Căn chỉnh âm thanh & chữ'),
            _buildAudioSyncSection(context),
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
                    transcriptAutoFollow: _autoFollow,
                    subtitleLang: _subtitleLang,
                    targetLang: _targetLang,
                    audioLeadMs: _audioLead,
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

  /// YT-AUDIT-11 (IN4-106): thanh trượt bù trễ + gợi ý đo được.
  ///
  /// Hai phần lệch được tách RÕ rồi, không trộn:
  ///   * **Đo được tự động** = độ trễ kênh WebView → Flutter (`measuredLagMs`).
  ///     Phần này app ĐÃ TỰ BÙ (tối đa 1,5 s) nên ở đây chỉ hiện để người dùng
  ///     biết, kèm nút "áp dụng" nếu họ muốn đẩy hết sang tay cho chủ động.
  ///   * **Không đo được** = track phụ đề lệch so với audio. Muốn phát hiện
  ///     phải có PCM, mà iframe WebView không lấy được ⇒ bắt buộc bằng tay.
  Widget _buildAudioSyncSection(BuildContext context) {
    final lead = _audioLead;
    final secs = lead / 1000.0;
    final sign = secs > 0 ? '+' : '';
    final head = lead == 0
        ? context.uiText('Đang khớp')
        : (lead > 0
            ? context.uiText('Âm thanh nhanh hơn chữ')
            : context.uiText('Chữ nhanh hơn âm thanh'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lead == 0
                    ? head
                    : '$head  $sign${secs.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        Slider(
          min: YtLearningSettings.kAudioLeadMin,
          max: YtLearningSettings.kAudioLeadMax,
          // ±3000 ms / bước 100 ms ⇒ 60 nấc.
          divisions: 60,
          value: YtLearningSettings.clampAudioLead(lead),
          activeColor: const Color(0xFF9C27B0),
          // Chốt về bước 100 ms: Slider có thể trả 100.00000000000001.
          onChanged: (v) => setState(
              () => _audioLead = YtLearningSettings.snapAudioLead(v)),
        ),
        Text(
          context.uiText(
            'Dương: chữ đổi sớm hơn — dùng khi âm thanh nhanh hơn chữ.',
          ),
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 6),
        _buildLagSuggestion(context),
      ],
    );
  }

  /// YT-AUDIT-11 (IN4-106): gợi ý tự động từ độ trễ kênh ĐÃ ĐO.
  Widget _buildLagSuggestion(BuildContext context) {
    final lag = widget.measuredLagMs;
    if (lag < 100) {
      return Text(
        context.uiText(
          'Chưa đủ mẫu để đo — hãy xem tiếp vài giây rồi mở lại.',
        ),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      );
    }
    final secs = (lag / 1000.0).toStringAsFixed(1);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.uiText('Đo được chữ đến trễ ')
                + '${secs}s',
            style: const TextStyle(color: Colors.amber, fontSize: 11),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _audioLead =
              YtLearningSettings.snapAudioLead(lag.toDouble())),
          child: Text(context.uiText('Áp dụng')),
        ),
      ],
    );
  }

  /// YT-AUDIT-04 (IN4-103): ô chọn ngôn ngữ (phụ đề gốc / ngôn ngữ dịch).
  Widget _langDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<({String code, String name})> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Value phải nằm trong `items`, nếu không DropdownButton ném assert.
    final codes = items.map((e) => e.code).toList();
    final effective = codes.contains(value) ? value : codes.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effective,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E242C),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                for (final it in items)
                  DropdownMenuItem<String>(
                    value: it.code,
                    child: Text(
                      it.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// YT-AUDIT-04 (IN4-103): nói RÕ ngôn ngữ dịch đang là gì và vì sao — thay
  /// cho đoạn code cũ tự đoán `target == 'en' ? 'vi'` trong im lặng.
  Widget _buildLanguageHint(BuildContext context) {
    final home = TranslationService().targetLang.trim();
    final resolved = YtLearningSettings.resolveTargetLang(
      subtitleLang: _subtitleLang,
      overrideTargetLang: _targetLang,
      homeTargetLang: home,
    );
    final homeLabel = home.isEmpty
        ? '—'
        : (AppLanguageCatalog.maybeFromCode(home)?.nativeName ?? home);

    if (resolved.fellBack) {
      return Text(
        context.uiText(
          'Ngôn ngữ dịch đang trùng với phụ đề gốc nên tạm dùng tiếng Việt. '
          'Đổi một trong hai ô trên để dịch đúng ý bạn.',
        ),
        style: const TextStyle(color: Colors.amber, fontSize: 11, height: 1.4),
      );
    }
    return Text(
      context.uiText('Cài đặt Home đang để: ') + homeLabel,
      style: const TextStyle(color: Colors.grey, fontSize: 11),
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
