// lib/screens/understand_mode/sheets/speed_control_sheet.dart

import 'package:flutter/material.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/core/language/tr_extension.dart';

void showSpeedControlSheet(BuildContext context, PlayerProvider player) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TrText('Tốc độ phát', style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth < 360 ? 62.0 : 70.0;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    final isSelected = player.state.speed == speed;
                    return GestureDetector(
                      onTap: () {
                        player.setSpeed(speed);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: itemWidth,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFB300)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFFB300)
                                : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '${speed}x',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const TrText(context.l10n.commonClose),
            ),
          ],
        ),
      ),
    ),
  );
}