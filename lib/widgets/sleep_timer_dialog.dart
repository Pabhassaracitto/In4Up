import 'package:flutter/material.dart';

class SleepTimerDialog extends StatefulWidget {
  final Function(Duration?) onTimerSet;
  
  const SleepTimerDialog({super.key, required this.onTimerSet});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  final List<SleepOption> options = [
    SleepOption('Tắt', Duration.zero),
    SleepOption('15 phút', const Duration(minutes: 15)),
    SleepOption('30 phút', const Duration(minutes: 30)),
    SleepOption('45 phút', const Duration(minutes: 45)),
    SleepOption('1 giờ', const Duration(hours: 1)),
    SleepOption('1.5 giờ', const Duration(minutes: 90)),
    SleepOption('2 giờ', const Duration(hours: 2)),
    SleepOption('Hết bài', null), // null = end of track
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          const Row(
            children: [
              Icon(Icons.bedtime, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text(
                'Hẹn giờ tắt',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Options
          ...options.map((option) => ListTile(
            title: Text(
              option.label,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              widget.onTimerSet(option.duration);
              Navigator.pop(context);
            },
          )),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class SleepOption {
  final String label;
  final Duration? duration;
  
  SleepOption(this.label, this.duration);
}