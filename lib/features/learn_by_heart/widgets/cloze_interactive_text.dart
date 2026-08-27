// lib/features/learn_by_heart/widgets/cloze_interactive_text.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../services/cloze_generator.dart';

class ClozeInteractiveText extends StatefulWidget {
  final List<ClozeToken> tokens;
  final VoidCallback? onAllRevealed;
  final double fontSize;

  const ClozeInteractiveText({
    super.key,
    required this.tokens,
    this.onAllRevealed,
    this.fontSize = 18.0,
  });

  @override
  State<ClozeInteractiveText> createState() => _ClozeInteractiveTextState();
}

class _ClozeInteractiveTextState extends State<ClozeInteractiveText> {
  late List<ClozeToken> _tokens;

  @override
  void initState() {
    super.initState();
    _tokens = widget.tokens;
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

  bool get _isAllRevealed => _tokens.every((t) => !t.isMasked || t.isRevealed);

  int get _maskedCount => _tokens.where((t) => t.isMasked).length;
  int get _revealedCount => _tokens.where((t) => t.isMasked && t.isRevealed).length;

  void _toggleToken(ClozeToken token) {
    if (!token.isMasked) return;
    HapticFeedback.selectionClick();
    setState(() {
      token.isRevealed = !token.isRevealed;
    });

    if (_isAllRevealed) {
      widget.onAllRevealed?.call();
    }
  }

  void _revealAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final t in _tokens) {
        if (t.isMasked) t.isRevealed = true;
      }
    });
    widget.onAllRevealed?.call();
  }

  void _hideAll() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final t in _tokens) {
        if (t.isMasked) t.isRevealed = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper hint bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chạm vào ô [ ___ ] để lật mở từng từ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_maskedCount > 0)
                Text(
                  '$_revealedCount/$_maskedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64B5F6),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isAllRevealed ? _hideAll : _revealAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _isAllRevealed ? 'Ẩn lại' : 'Mở hết',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ),

        // Tokens interactive wrap
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _tokens.map((token) {
              if (!token.isMasked) {
                return Text(
                  token.text,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                );
              }

              // Masked Token
              final isRevealed = token.isRevealed;
              return GestureDetector(
                onTap: () => _toggleToken(token),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRevealed
                        ? (token.isKeyword
                            ? const Color(0xFFFFB300).withValues(alpha: 0.22)
                            : const Color(0xFF4CAF50).withValues(alpha: 0.2))
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRevealed
                          ? (token.isKeyword
                              ? const Color(0xFFFFB300).withValues(alpha: 0.8)
                              : const Color(0xFF4CAF50).withValues(alpha: 0.7))
                          : const Color(0xFF64748B),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    isRevealed ? token.text : ' ___ ',
                    style: TextStyle(
                      fontSize: widget.fontSize * 0.95,
                      fontWeight: isRevealed ? FontWeight.bold : FontWeight.w600,
                      color: isRevealed
                          ? (token.isKeyword ? const Color(0xFFFFD54F) : const Color(0xFFA5D6A7))
                          : const Color(0xFF94A3B8),
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
}
