// lib/screens/understand_mode/widgets/shadowing_button.dart

import 'package:flutter/material.dart';

class ShadowingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final bool fullWidth;

  const ShadowingButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.3),
        minimumSize: fullWidth ? const Size(double.infinity, 48) : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
