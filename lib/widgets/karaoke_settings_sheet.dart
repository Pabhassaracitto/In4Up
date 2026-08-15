// lib/widgets/karaoke_settings_sheet.dart
//
// Bottom sheet tuỳ chỉnh hiển thị karaoke: cỡ chữ, màu sắc, căn lề,
// và bật/tắt bản dịch.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';

class KaraokeSettingsSheet extends StatefulWidget {
  const KaraokeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => const KaraokeSettingsSheet(),
    );
  }

  @override
  State<KaraokeSettingsSheet> createState() => _KaraokeSettingsSheetState();
}

class _KaraokeSettingsSheetState extends State<KaraokeSettingsSheet> {
  late KaraokeStyle _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<KaraokeSettingsProvider>().style;
  }

  void _save() {
    context.read<KaraokeSettingsProvider>().update(_draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tuỳ chỉnh karaoke',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 16),

            // Cỡ chữ dòng đang phát
            _label('Cỡ chữ (dòng đang phát)'),
            Slider(
              value: _draft.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              label: _draft.fontSize.toStringAsFixed(0),
              onChanged: (v) => setState(() => _draft =
                  _draft.copyWith(fontSize: v)),
            ),
            _label('Cỡ chữ (dòng không phát)'),
            Slider(
              value: _draft.inactiveFontSize,
              min: 10,
              max: 24,
              divisions: 14,
              label: _draft.inactiveFontSize.toStringAsFixed(0),
              onChanged: (v) => setState(() =>
                  _draft = _draft.copyWith(inactiveFontSize: v)),
            ),

            // Căn lề
            _label('Căn lề'),
            SegmentedButton<TextAlign>(
              segments: const [
                ButtonSegment(
                    value: TextAlign.left,
                    label: Text('Trái', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: TextAlign.center,
                    label: Text('Giữa', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: TextAlign.right,
                    label: Text('Phải', style: TextStyle(fontSize: 12))),
              ],
              selected: {_draft.textAlign},
              onSelectionChanged: (s) =>
                  setState(() => _draft = _draft.copyWith(textAlign: s.first)),
            ),

            // Bản dịch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiện bản dịch (nếu có)',
                  style: TextStyle(color: Colors.white)),
              value: _draft.showTranslation,
              onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(showTranslation: v)),
            ),

            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Áp dụng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(s,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );
}
