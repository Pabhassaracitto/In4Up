// lib/features/learn_by_heart/widgets/cloze_interactive_text.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n/learn_by_heart_l10n.dart';
import '../services/cloze_generator.dart';

class ClozeInteractiveText extends StatefulWidget {
  final List<ClozeToken> tokens;
  final ClozeLevel initialLevel;
  final ValueChanged<ClozeLevel>? onLevelChanged;
  final VoidCallback? onAllRevealed;
  final double fontSize;

  const ClozeInteractiveText({
    super.key,
    required this.tokens,
    this.initialLevel = ClozeLevel.firstLetter,
    this.onLevelChanged,
    this.onAllRevealed,
    this.fontSize = 17.5,
  });

  @override
  State<ClozeInteractiveText> createState() => _ClozeInteractiveTextState();
}

class _ClozeInteractiveTextState extends State<ClozeInteractiveText> {
  late List<ClozeToken> _tokens;
  late ClozeLevel _currentLevel;

  @override
  void initState() {
    super.initState();
    _tokens = widget.tokens;
    _currentLevel = widget.initialLevel;
  }

  @override
  void didUpdateWidget(covariant ClozeInteractiveText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokens != widget.tokens) {
      setState(() {
        _tokens = widget.tokens;
      });
    }
  }

  void _setLevel(ClozeLevel level) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentLevel = level;
      // Reset trạng thái reveal khi đổi cấp độ
      for (final t in _tokens) {
        t.isRevealed = false;
      }
    });
    widget.onLevelChanged?.call(level);
  }

  void _toggleToken(ClozeToken token) {
    if (!token.isMaskedAtLevel(_currentLevel)) return;
    HapticFeedback.selectionClick();
    setState(() {
      token.isRevealed = !token.isRevealed;
    });

    final maskedTokens = _tokens.where((t) => t.isMaskedAtLevel(_currentLevel));
    if (maskedTokens.isNotEmpty && maskedTokens.every((t) => t.isRevealed)) {
      widget.onAllRevealed?.call();
    }
  }

  void _revealAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final t in _tokens) {
        if (t.isMaskedAtLevel(_currentLevel)) {
          t.isRevealed = true;
        }
      }
    });
    widget.onAllRevealed?.call();
  }

  void _hideAll() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final t in _tokens) {
        t.isRevealed = false;
      }
    });
  }

  int get _totalMaskedForLevel => _tokens.where((t) => t.isMaskedAtLevel(_currentLevel)).length;
  int get _revealedForLevel => _tokens.where((t) => t.isMaskedAtLevel(_currentLevel) && t.isRevealed).length;

  @override
  Widget build(BuildContext context) {
    final l10n = LearnByHeartL10n.of(context);
    final totalMasked = _totalMaskedForLevel;
    final revealed = _revealedForLevel;
    final isFullLevel = _currentLevel == ClozeLevel.fullText;
    final progress = totalMasked > 0 ? (revealed / totalMasked) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Level Selector (4 Tầng Bốc Hơi Chữ)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              _LevelTabButton(
                label: l10n.level1Full,
                level: ClozeLevel.fullText,
                isSelected: _currentLevel == ClozeLevel.fullText,
                onTap: () => _setLevel(ClozeLevel.fullText),
              ),
              _LevelTabButton(
                label: l10n.level2Keywords,
                level: ClozeLevel.keywords,
                isSelected: _currentLevel == ClozeLevel.keywords,
                onTap: () => _setLevel(ClozeLevel.keywords),
              ),
              _LevelTabButton(
                label: l10n.level3FirstLetter,
                level: ClozeLevel.firstLetter,
                isSelected: _currentLevel == ClozeLevel.firstLetter,
                onTap: () => _setLevel(ClozeLevel.firstLetter),
              ),
              _LevelTabButton(
                label: l10n.level4Ghost,
                level: ClozeLevel.ghost,
                isSelected: _currentLevel == ClozeLevel.ghost,
                onTap: () => _setLevel(ClozeLevel.ghost),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Helper Hint & Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isFullLevel
                ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(
                isFullLevel
                    ? Icons.menu_book_rounded
                    : (_currentLevel == ClozeLevel.firstLetter
                        ? Icons.text_fields_rounded
                        : (_currentLevel == ClozeLevel.keywords
                            ? Icons.vpn_key_rounded
                            : Icons.visibility_off_rounded)),
                size: 16,
                color: isFullLevel
                    ? const Color(0xFF90CAF9)
                    : (_currentLevel == ClozeLevel.firstLetter
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF81C784)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getHelperText(l10n),
                  style: TextStyle(
                    fontSize: 12,
                    color: isFullLevel ? const Color(0xFF90CAF9) : Colors.grey[300],
                    fontWeight: isFullLevel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!isFullLevel && totalMasked > 0) ...[
                Text(
                  '$revealed/$totalMasked',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _currentLevel == ClozeLevel.firstLetter
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF81C784),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: revealed == totalMasked ? _hideAll : _revealAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    revealed == totalMasked ? l10n.hideAll : l10n.revealAll,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Progress Meter (Only in Cloze / Interactive Modes)
        if (!isFullLevel && totalMasked > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0
                    ? const Color(0xFF4CAF50)
                    : (_currentLevel == ClozeLevel.firstLetter
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF818CF8)),
              ),
              minHeight: 3,
            ),
          ),
        ],
        const SizedBox(height: 12),

        // 4. Interactive Text Rendering Area
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _currentLevel == ClozeLevel.firstLetter
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _tokens.map((token) {
              final isMaskedHere = token.isMaskedAtLevel(_currentLevel);

              // ═══ TRƯỜNG HỢP 1: TỪ BÌNH THƯỜNG (KHÔNG BỊ ẨN) ═══
              // Render dạng chữ thuần mượt mà, không đóng khung hộp, không có viền nút
              if (!isMaskedHere || isFullLevel) {
                return Text(
                  token.text,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.5,
                  ),
                );
              }

              // ═══ TRƯỜNG HỢP 2: TỪ ĐANG BỊ ẨN / MỒI CHỮ ═══
              // Render dạng Pill tương tác có thể chạm mở
              final displayStr = token.getDisplayForLevel(_currentLevel);
              final isRevealed = token.isRevealed;

              return GestureDetector(
                onTap: () => _toggleToken(token),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isRevealed
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                        : (_currentLevel == ClozeLevel.firstLetter
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
                            : const Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRevealed
                          ? const Color(0xFF4CAF50)
                          : (_currentLevel == ClozeLevel.firstLetter
                              ? const Color(0xFF818CF8).withValues(alpha: 0.6)
                              : const Color(0xFF64748B)),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    displayStr,
                    style: TextStyle(
                      fontSize: widget.fontSize * 0.95,
                      fontWeight: isRevealed ? FontWeight.bold : FontWeight.w600,
                      letterSpacing: !isRevealed ? 0.8 : 0.0,
                      color: isRevealed
                          ? const Color(0xFFA5D6A7)
                          : (_currentLevel == ClozeLevel.firstLetter
                              ? const Color(0xFFFFD54F)
                              : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getHelperText(LearnByHeartL10n l10n) {
    switch (_currentLevel) {
      case ClozeLevel.fullText:
        return l10n.level1Desc;
      case ClozeLevel.keywords:
        return l10n.level2Desc;
      case ClozeLevel.firstLetter:
        return l10n.level3Desc;
      case ClozeLevel.ghost:
        return l10n.level4Desc;
    }
  }
}

class _LevelTabButton extends StatelessWidget {
  final String label;
  final ClozeLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelTabButton({
    required this.label,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
