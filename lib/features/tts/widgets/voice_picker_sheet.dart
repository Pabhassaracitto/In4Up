// lib/features/tts/widgets/voice_picker_sheet.dart
//
// AUDIT v1.30.1 (mục 5) — «Tab đọc: danh sách giọng Microsoft Edge chiếm nhiều
// chỗ ⇒ cho thu gọn/bung».
//
// Trước đây `ReaderVoiceTile` mở một `SimpleDialog` phẳng liệt kê MỌI giọng
// của engine. Edge có 35 giọng / 17 ngôn ngữ (cộng danh sách live tải từ
// `voices/list`), nên:
//   • hộp thoại cao hơn màn hình điện thoại, phải cuộn mù để tìm 1 giọng;
//   • không thấy được đang dùng giọng nào (không có dấu chọn);
//   • mỗi lần đổi giọng là một lần cuộn từ đầu.
//
// Nay: bottom sheet có TÌM KIẾM + nhóm theo ngôn ngữ, mỗi nhóm thu gọn/bung
// được; nhóm đang dùng mở sẵn. Khi chưa gõ tìm kiếm thì chỉ hiện tiêu đề nhóm
// (1 dòng/ngôn ngữ) ⇒ 17 ngôn ngữ gói trong nửa màn hình thay vì 35 dòng.

import 'package:in4up/core/language/localized_material.dart';

import '../engines/tts_engine.dart' show TtsVoice;
import '../reader_voice_preference.dart';
import '../voice_catalog_grouping.dart';

/// Mở bảng chọn giọng có nhóm thu gọn/bung.
///
/// Trả về `null` khi người dùng đóng bảng; `ReaderVoicePreference(engineId)`
/// khi chọn «kế thừa»; `ReaderVoicePreference(engineId, voice, locale)` khi
/// chọn một giọng cụ thể.
Future<ReaderVoicePreference?> showVoicePickerSheet(
  BuildContext context, {
  required String title,
  required String engineId,
  required List<TtsVoice> voices,
  required String inheritLabel,
  String? selectedVoiceId,
}) {
  return showModalBottomSheet<ReaderVoicePreference>(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VoicePickerSheet(
      title: title,
      engineId: engineId,
      voices: voices,
      inheritLabel: inheritLabel,
      selectedVoiceId: selectedVoiceId,
    ),
  );
}

class _VoicePickerSheet extends StatefulWidget {
  final String title;
  final String engineId;
  final List<TtsVoice> voices;
  final String inheritLabel;
  final String? selectedVoiceId;

  const _VoicePickerSheet({
    required this.title,
    required this.engineId,
    required this.voices,
    required this.inheritLabel,
    this.selectedVoiceId,
  });

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  late final List<VoiceLanguageGroup> _groups =
      groupVoicesByLanguage(widget.voices);

  late Set<String> _expanded = defaultExpandedVoiceGroups(
    groupVoicesByLanguage(widget.voices),
    selectedVoiceId: widget.selectedVoiceId,
  );

  /// `true` khi người dùng đã tự thu/bung ⇒ ngừng áp "mở sẵn" mỗi lần gõ.
  bool _touchedExpansion = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleGroup(String language) {
    _touchedExpansion = true;
    setState(() {
      if (_expanded.contains(language)) {
        _expanded.remove(language);
      } else {
        _expanded.add(language);
      }
    });
  }

  List<VoiceLanguageGroup> get _visibleGroups {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _groups;
    return [
      for (final group in _groups)
        if (group.language.toLowerCase().contains(query) ||
            group.voices.any((voice) =>
                voice.name.toLowerCase().contains(query) ||
                voice.id.toLowerCase().contains(query)))
          group,
    ];
  }

  /// Đang TÌM KIẾM ⇒ luôn bung nhóm khớp: bắt người dùng gõ rồi vẫn phải bung
  /// thêm một lần nữa là hai lần chạm cho một ý định.
  bool _isExpanded(VoiceLanguageGroup group) {
    if (_query.trim().isNotEmpty) return true;
    return _expanded.contains(group.language);
  }

  int get _totalVoices => widget.voices.length;

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups;
    final selected = widget.selectedVoiceId?.trim() ?? '';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              // Số giọng + số ngôn ngữ (số, không cần dịch) để người dùng biết
              // quy mô danh sách trước khi cuộn.
              '$_totalVoices ${context.uiText('giọng')} · ${_groups.length} '
              '${context.uiText('ngôn ngữ')}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() {
                _query = value;
                _touchedExpansion = false;
              }),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.uiText('Tìm giọng hoặc ngôn ngữ…'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: Colors.white38),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.white38),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                          _touchedExpansion = false;
                        }),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.settings_backup_restore,
                      size: 18, color: Colors.white54),
                  title: Text(
                    widget.inheritLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: selected.isEmpty
                      ? const Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF2196F3))
                      : null,
                  onTap: () => Navigator.of(context)
                      .pop(ReaderVoicePreference(widget.engineId)),
                ),
                const Divider(color: Colors.white12, height: 8),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 20),
                    child: Text(
                      context.uiText('Không tìm thấy giọng phù hợp'),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                for (final group in groups) ..._buildGroup(context, group, selected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(
    BuildContext context,
    VoiceLanguageGroup group,
    String selected,
  ) {
    final expanded = _isExpanded(group);
    final hasSelection =
        group.voices.any((voice) => voice.id == selected);
    return [
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleGroup(group.language),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 20,
                color: Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                group.language.isEmpty ? '—' : group.language,
                style: TextStyle(
                  color: hasSelection
                      ? const Color(0xFF90CAF9)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight:
                      hasSelection ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${group.count}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
              if (hasSelection) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, size: 14, color: Color(0xFF2196F3)),
              ],
              const Spacer(),
              Text(
                group.shortLabel,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
      if (expanded)
        for (final voice in group.voices)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 34, right: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            selected: voice.id == selected,
            selectedTileColor:
                const Color(0xFF2196F3).withValues(alpha: 0.12),
            title: Text(
              voice.name,
              style: TextStyle(
                color: voice.id == selected
                    ? const Color(0xFF90CAF9)
                    : Colors.white70,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              [
                voice.language,
                if (voice.gender.isNotEmpty) voice.gender,
                if (voice.isNeural) 'neural',
              ].join(' · '),
              style: const TextStyle(color: Colors.white30, fontSize: 10),
            ),
            trailing: voice.id == selected
                ? const Icon(Icons.check_circle,
                    size: 16, color: Color(0xFF2196F3))
                : null,
            onTap: () => Navigator.of(context).pop(
              ReaderVoicePreference(
                widget.engineId,
                voice: voice.id,
                locale: voice.language,
              ),
            ),
          ),
      const SizedBox(height: 2),
    ];
  }
}
