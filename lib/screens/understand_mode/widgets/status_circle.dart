// lib/screens/understand_mode/widgets/status_circle.dart

import 'package:in4up/core/language/localized_material.dart';

class StatusCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isReady;
  final Color color;

  const StatusCircle({
    super.key,
    required this.icon,
    required this.label,
    required this.isReady,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isReady
                ? color.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isReady ? color : Colors.grey[700]!,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isReady ? color : Colors.grey[700],
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isReady ? color : Colors.grey[600],
            fontSize: 12,
            fontWeight: isReady ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
