import 'package:flutter/material.dart';

class HebbianInputCard extends StatelessWidget {
  const HebbianInputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NẠP TRI THỨC NHANH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickInputButton(
                  icon: Icons.mic,
                  label: 'Ghi chú nói',
                  color: const Color(0xFFFF4848),
                  onTap: () {
                    // Start STT flow
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickInputButton(
                  icon: Icons.auto_awesome,
                  label: 'Hừm! Gợi ý',
                  color: const Color(0xFF00D1FF),
                  onTap: () {
                    // Show random word with image
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickInputButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickInputButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
