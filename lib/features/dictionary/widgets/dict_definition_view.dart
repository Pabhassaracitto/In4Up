import 'package:in4up/core/language/localized_material.dart';

import '../services/dict_text_cleaner.dart';

/// Render nội dung từ điển đã cấu trúc (DICT-CLEAN-001, DICT-VIEW-002).
///
/// Hai chế độ, phục vụ đúng hai mục đích khác nhau của người sở hữu:
/// - [compact] = `true`: nhúng trong sheet PDF/Read — chỉ nghĩa cốt lõi,
///   không đổ toàn bộ HTML đã bóc (hết "dư thừa").
/// - [compact] = `false`: trang từ điển thật — nhóm loại từ, nghĩa đánh số,
///   ví dụ in nghiêng, nhãn nguồn.
///
/// DICT-VIEW-002 (owner 2026-10-25 — "các từ điển hiển thị chưa tốt, tham
/// khảo lad.css"): bám đúng thứ bậc của một trang từ điển in —
///   headword (do sheet vẽ) → **nhóm loại từ** (nhãn riêng, đếm nghĩa) →
///   **nghĩa đánh số, đánh số LẠI từ 1 ở mỗi loại từ** (như lad.css/MDict) →
///   **ví dụ** thụt lề, nghiêng, có vạch dọc. Bản cũ đánh số chạy suốt nhiều
///   nhóm loại từ nên đọc rất khó đối chiếu với từ điển giấy.
class DictDefinitionView extends StatelessWidget {
  final List<DictPosGroup> groups;
  final int maxSenses;
  final bool compact;
  final Color accentColor;
  final String? sourceLabel;
  final VoidCallback? onOpenFull;

  /// `true` khi widget nằm trên nền sáng (vd WordAnalysisSheet màu trắng).
  final bool light;

  const DictDefinitionView({
    super.key,
    required this.groups,
    this.maxSenses = 3,
    this.compact = true,
    this.accentColor = const Color(0xFF2196F3),
    this.sourceLabel,
    this.onOpenFull,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  // ── Màu theo nền sáng/tối ───────────────────────────────────────────────

  Color get _primaryText => light ? Colors.black87 : Colors.white;
  Color get _secondaryText => light ? Colors.black54 : Colors.grey[400]!;
  Color get _mutedText => light ? Colors.black45 : Colors.grey[500]!;
  Color get _dividerColor => light
      ? Colors.black.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.08);

  // ── Chế độ cô đọng (nhúng trong sheet từ PDF/Read) ──────────────────────

  Widget _buildCompact(BuildContext context) {
    final pairs = <_SenseRef>[
      for (final group in groups)
        for (var s = 0; s < group.senses.length; s++)
          _SenseRef(senseIndex: s, group: group),
    ];
    final shown = pairs.take(maxSenses).toList();
    final hidden = pairs.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Nhãn loại từ chỉ hiện ở nghĩa ĐẦU của mỗi nhóm (không
                      // lặp "noun noun noun").
                      if (_showsPosLabel(shown, i))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _PosLabel(
                            pos: shown[i].group.pos!,
                            color: accentColor,
                            light: light,
                            dense: true,
                          ),
                        ),
                      Text(
                        shown[i].sense.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: light ? Colors.black87 : Colors.grey[300],
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      // Ví dụ đầu tiên: đủ để thấy cách dùng, không chiếm chỗ.
                      if (shown[i].sense.examples.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            shown[i].sense.examples.first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0 || onOpenFull != null)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (hidden > 0)
                Text(
                  context.uiText('+$hidden nghĩa khác'),
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (onOpenFull != null)
                TextButton.icon(
                  onPressed: onOpenFull,
                  icon: Icon(Icons.menu_book, size: 14, color: accentColor),
                  label: Text(
                    context.uiText('Xem từ điển đầy đủ'),
                    style: TextStyle(color: accentColor, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        if ((sourceLabel ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              context.uiText('Nguồn: ${sourceLabel!.trim()}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _mutedText, fontSize: 10.5),
            ),
          ),
      ],
    );
  }

  /// Nghĩa thứ [index] trong danh sách đã cắt có mở một nhóm mới không?
  bool _showsPosLabel(List<_SenseRef> shown, int index) {
    final pos = shown[index].group.pos;
    if (pos == null || pos.trim().isEmpty) return false;
    if (index == 0) return true;
    return shown[index - 1].group.pos != pos;
  }

  // ── Chế độ đầy đủ (trang từ điển) ──────────────────────────────────────

  Widget _buildFull(BuildContext context) {
    final sections = <Widget>[];

    for (final group in groups) {
      final pos = (group.pos ?? '').trim();
      final count = group.senses.length;
      if (count == 0) continue;

      sections.add(
        Padding(
          padding: EdgeInsets.only(
            top: sections.isEmpty ? 4 : 18,
            bottom: 6,
          ),
          child: Row(
            children: <Widget>[
              if (pos.isNotEmpty) ...<Widget>[
                _PosLabel(pos: pos, color: accentColor, light: light),
                const SizedBox(width: 8),
                Text(
                  // Template `{value0} nghĩa` (không ghép chuỗi đã dịch) để
                  // locale ≠ vi ra đúng "3 senses".
                  context.uiText('$count nghĩa'),
                  style: TextStyle(color: _mutedText, fontSize: 10.5),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: _dividerColor),
              ),
            ],
          ),
        ),
      );

      // Đánh số LẠI từ 1 cho mỗi loại từ — chuẩn từ điển in (lad.css/MDict).
      for (var i = 0; i < group.senses.length; i++) {
        sections.add(_senseRow(context, i + 1, group.senses[i]));
      }
    }

    if (sections.isEmpty) {
      // Có nhóm nhưng không có nghĩa nào dùng được ⇒ đừng im lặng.
      return Text(
        context.uiText('Chưa có nội dung cho từ này'),
        style: TextStyle(color: _mutedText, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _senseRow(BuildContext context, int number, DictSense sense) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '$number.',
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sense.text,
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
                for (final example in sense.examples.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        example,
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một nghĩa kèm nhóm loại từ của nó (để render compact đúng thứ bậc).
class _SenseRef {
  final int senseIndex;
  final DictPosGroup group;

  const _SenseRef({
    required this.senseIndex,
    required this.group,
  });

  DictSense get sense => group.senses[senseIndex];
}

/// Nhãn loại từ (`noun`, `verb`…) — kiểu "small caps" của từ điển giấy.
class _PosLabel extends StatelessWidget {
  final String pos;
  final Color color;
  final bool light;
  final bool dense;

  const _PosLabel({
    required this.pos,
    required this.color,
    required this.light,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: light ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(dense ? 5 : 6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        pos,
        style: TextStyle(
          color: color,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.1,
        ),
      ),
    );
  }
}
