// lib/widgets/ipa_source_chip.dart
import 'package:in4up/core/language/localized_material.dart';

/// Chip nhỏ chứng minh nguồn IPA của từ đã lưu — READ-IPA-002.
///
/// mdx = xanh dương · cmu = xám · g2p = vàng · user = tím (ADR-0005).
/// Nguồn lạ / rỗng → không render gì.
class IpaSourceChip extends StatelessWidget {
  final String source;

  const IpaSourceChip({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (source == 'mdx') {
      color = const Color(0xFF42A5F5);
      label = 'MDX';
    } else if (source == 'cmu') {
      color = const Color(0xFF9E9E9E);
      label = 'CMU';
    } else if (source == 'g2p') {
      color = const Color(0xFFFFB74D);
      label = 'G2P';
    } else if (source == 'user') {
      color = const Color(0xFFCE93D8);
      label = 'Bạn';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
