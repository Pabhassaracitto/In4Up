import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class QuickReplayButtons extends StatelessWidget {
  const QuickReplayButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ReplayButton(
              seconds: 30,
              onTap: () => player.replay30(),
            ),
            const SizedBox(width: 8),
            _ReplayButton(
              seconds: 10,
              onTap: () => player.replay10(),
            ),
            const SizedBox(width: 8),
            _ReplayButton(
              seconds: 5,
              onTap: () => player.replay5(),
            ),
            const SizedBox(width: 24),
            _ForwardButton(
              seconds: 5,
              onTap: () => player.forward5(),
            ),
            const SizedBox(width: 8),
            _ForwardButton(
              seconds: 10,
              onTap: () => player.forward10(),
            ),
            const SizedBox(width: 8),
            _ForwardButton(
              seconds: 30,
              onTap: () => player.forward30(),
            ),
          ],
        );
      },
    );
  }
}

class _ReplayButton extends StatelessWidget {
  final int seconds;
  final VoidCallback onTap;

  const _ReplayButton({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.replay, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              '${seconds}s',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForwardButton extends StatelessWidget {
  final int seconds;
  final VoidCallback onTap;

  const _ForwardButton({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${seconds}s',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.forward, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}