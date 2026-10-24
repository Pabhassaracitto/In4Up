import 'package:in4up/core/language/localized_material.dart';

import '../services/dict_text_cleaner.dart';

/// Render nội dung từ điển đã cấu trúc (DICT-CLEAN-001).
///
/// Hai chế độ, phục vụ đúng hai mục đích khác nhau của người sở hữu:
/// - [compact] = `true`: nhúng trong sheet PDF/Read — chỉ nghĩa cốt lõi,
///   không đổ toàn bộ HTML đã bóc (hết "dư thừa").
/// - [compact] = `false`: trang từ điển thật — nhóm loại từ, nghĩa đánh số,
///   ví dụ in nghiêng, nhãn nguồn.
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

  List<DictSense> get _senses => <DictSense>[
        for (final group in groups) ...group.senses,
      ];

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  // ── Chế độ cô đọng (nhúng trong sheet từ PDF/Read) ──────────────────────

  Widget _buildCompact(BuildContext context) {
    final senses = _senses;
    final shown = senses.take(maxSenses).toList();
    final hidden = senses.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final sense in shown)
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
                  child: Text(
                    sense.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: light ? Colors.black87 : Colors.grey[300],
                      fontSize: 13.5,
                      height: 1.45,
                    ),
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
                    color: light ? Colors.black45 : Colors.grey[500],
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (onOpenFull != null)
                TextButton.icon(
                  onPressed: onOpenFull,
                  icon: Icon(Icons.menu_book,
                      size: 14, color: accentColor),
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
              context.uiText('Nguồn: $sourceLabel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: light ? Colors.black38 : Colors.grey[600],
                fontSize: 10.5,
              ),
            ),
          ),
      ],
    );
  }

  // ── Chế độ đầy đủ (trang từ điển) ──────────────────────────────────────

  Widget _buildFull(BuildContext context) {
    final sections = <Widget>[];
    var senseNumber = 0;

    for (final group in groups) {
      final pos = (group.pos ?? '').trim();
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(
            children: <Widget>[
              if (pos.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    pos,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              if (pos.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
        ),
      );

      for (final sense in group.senses) {
        senseNumber++;
        sections.add(_senseRow(context, senseNumber, sense));
      }
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
            width: 22,
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
                  style: const TextStyle(
                    color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        example,
                        style: TextStyle(
                          color: Colors.grey[400],
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
