// lib/screens/memory_mode/widgets/memory_card_widget.dart

import 'package:in4up/core/language/localized_material.dart';

import '../models/memory_item.dart';
import '../models/memory_stage.dart';

class MemoryCardWidget extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback? onTap;

  const MemoryCardWidget({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stage = item.stage;
    final baseFontSize = 16.0;
    final fontSize = item.getFontSize(baseFontSize);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minHeight: stage.cardMinHeight),
        padding: EdgeInsets.all(stage == MemoryStage.seed ? 16 : 10),
        decoration: BoxDecoration(
          color: item.displayBackgroundColor,
          borderRadius: BorderRadius.circular(
            stage == MemoryStage.seed ? 16 : 10,
          ),
          border: stage.borderWidth > 0
              ? Border.all(
                  color: stage.primaryColor.withValues(alpha: 0.5),
                  width: stage.borderWidth,
                )
              : null,
          boxShadow: stage.elevation > 0
              ? [
                  BoxShadow(
                    color: stage.primaryColor.withValues(alpha: 0.15),
                    blurRadius: stage.elevation * 2,
                    spreadRadius: stage.elevation * 0.3,
                    offset: Offset(0, stage.elevation * 0.5),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  stage.emoji,
                  style: TextStyle(
                    fontSize: stage == MemoryStage.seed ? 16 : 12,
                  ),
                ),
                const Spacer(),
                if (item.needsReview)
                  _PulseDot(
                    color: item.overdueHours > 24
                        ? const Color(0xFFFF1744)
                        : const Color(0xFFFF9800),
                    size: stage == MemoryStage.seed ? 10 : 6,
                  ),
              ],
            ),
            if (stage == MemoryStage.seed) const SizedBox(height: 8),
            Text(
              item.word,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: _fontWeight(stage),
                color: item.displayColor,
                height: 1.3,
                letterSpacing: stage == MemoryStage.seed ? 0.5 : 0,
              ),
              maxLines: stage.index <= 1 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.meaning != null &&
                (stage == MemoryStage.seed || stage == MemoryStage.sprout)) ...[
              const SizedBox(height: 4),
              Text(
                item.meaning!,
                style: TextStyle(
                  fontSize: fontSize * 0.65,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (stage.index <= 2) ...[
              const SizedBox(height: 6),
              _StrengthBar(
                strength: item.strength,
                color: stage.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  FontWeight _fontWeight(MemoryStage stage) {
    switch (stage) {
      case MemoryStage.seed:
        return FontWeight.w900;
      case MemoryStage.sprout:
        return FontWeight.w700;
      case MemoryStage.tree:
        return FontWeight.w600;
      case MemoryStage.branch:
        return FontWeight.w500;
      case MemoryStage.bud:
        return FontWeight.w400;
      case MemoryStage.bloom:
        return FontWeight.w300;
    }
  }
}

class _PulseDot extends StatelessWidget {
  final Color color;
  final double size;

  const _PulseDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: size * 0.5,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final double strength;
  final Color color;

  const _StrengthBar({required this.strength, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: strength,
        backgroundColor: color.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
        minHeight: 3,
      ),
    );
  }
}
