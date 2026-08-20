// lib/widgets/sound_auto_toc_dialog.dart
// UI dùng chung cho "⚡ Tự tạo mục lục âm thanh":
//   • Dialog chọn chế độ: VAD + Whisper (tự đặt tên) / Chỉ VAD (nhanh)
//   • Dialog tiến trình với thanh progress + nút hủy
//   • Snackbar kết quả
//
// Được gọi từ panel Âm mục (Listen Mode) và màn hình thư viện Âm mục.

import 'package:flutter/material.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:provider/provider.dart';

import '../models/vad_settings.dart';
import '../providers/soundlist_provider.dart';
import '../services/sound_auto_toc_service.dart';

/// Chạy toàn bộ luồng tự tạo mục lục cho [audioPath].
Future<void> runSoundAutoToc(
  BuildContext context, {
  required String audioPath,
  Duration? totalDuration,
  required bool hasExistingChapters,
}) async {
  final soundlist = context.read<SoundlistProvider>();

  // ── 1. Xác nhận + chọn chế độ ──
  final mode = await _showModeDialog(
    context,
    hasExistingChapters: hasExistingChapters,
  );
  if (mode == null || !context.mounted) return;

  final useWhisper = mode == _AutoTocMode.whisper;
  final nav = Navigator.of(context);

  // ── 2. Dialog tiến trình ──
  final status = ValueNotifier<String>(
    useWhisper ? 'Bắt đầu…' : 'Phân tích khoảng lặng (VAD)…',
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AutoTocProgressDialog(status: status, cancelable: useWhisper),
  );

  SoundAutoTocResult? result;
  String? error;
  try {
    result = await soundlist.autoGenerateToc(
      audioPath: audioPath,
      totalDuration: totalDuration,
      useWhisper: useWhisper,
      onStatus: (msg) => status.value = msg,
    );
  } catch (e) {
    error = e.toString();
  }

  nav.pop(); // đóng dialog tiến trình

  if (!context.mounted) return;

  // ── 3. Snackbar kết quả ──
  final messenger = ScaffoldMessenger.of(context);
  final chapters = result?.chapters ?? const [];

  if (error != null) {
    messenger.showSnackBar(SnackBar(
      content: Text('⚠️ Lỗi khi tự tạo mục lục: $error'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFEF5350),
    ));
    return;
  }

  if (chapters.isEmpty) {
    messenger.showSnackBar(const SnackBar(
      content: Text('⚠️ Không tạo được mục lục (không đủ khoảng lặng hoặc '
          'không nhận diện được giọng nói).'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFEF5350),
    ));
    return;
  }

  final usedWhisperText = result!.usedWhisper ? ' + Whisper tự đặt tên' : '';
  messenger.showSnackBar(SnackBar(
    content: Text('✅ Đã tạo ${chapters.length} mục lục$usedWhisperText '
        '· chạm để nhảy tới'),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 3200),
    backgroundColor: const Color(0xFF26C6DA),
  ));
}

enum _AutoTocMode { whisper, vadOnly }

Future<_AutoTocMode?> _showModeDialog(
  BuildContext context, {
  required bool hasExistingChapters,
}) async {
  final baseReady = SoundAutoTocService.isWhisperModelReady(
    WhisperModelLevel.base,
  );
  final existingWarn = hasExistingChapters
      ? '\n\n⚠️ Mục lục hiện có của file sẽ được THAY THẾ.'
      : '';

  return showDialog<_AutoTocMode>(
    context: context,
    builder: (ctx) {
      final soundlist = ctx.read<SoundlistProvider>();
      var vad = soundlist.vadSettings;

      Future<void> pick(_AutoTocMode mode) async {
        await soundlist.setVadSettings(vad);
        if (ctx.mounted) Navigator.pop(ctx, mode);
      }

      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF232841),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⚡ Tự tạo mục lục',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App sẽ phân tích âm thanh và tạo mục lục như sách.$existingWarn',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF26C6DA), width: 1),
                  ),
                  leading: const Icon(Icons.auto_awesome, color: Color(0xFF26C6DA)),
                  title: const Text(
                    'VAD + Whisper (khuyên dùng)',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    baseReady
                        ? 'Tách đoạn theo khoảng lặng + tự đặt tiêu đề chương'
                        : 'Cần tải model Whisper (~57MB, tự động, 1 lần đầu)',
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  onTap: () => pick(_AutoTocMode.whisper),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  leading: const Icon(Icons.bolt, color: Color(0xFFFFB300)),
                  title: const Text(
                    'Chỉ VAD (nhanh, không cần tải)',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Tách đoạn theo khoảng lặng, tên mặc định "Đoạn 1 · 00:00"…',
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  onTap: () => pick(_AutoTocMode.vadOnly),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // ── Tùy chỉnh tách đoạn (VAD) ──
                const Text(
                  'Tùy chỉnh tách đoạn (VAD)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _vadPresetChip('Tách ít', vad.presetLabel == 'Tách ít', () {
                      setDialogState(() => vad = VadSettings.few);
                    }),
                    _vadPresetChip('Bình thường', vad.presetLabel == 'Bình thường', () {
                      setDialogState(() => vad = VadSettings.normal);
                    }),
                    _vadPresetChip('Tách nhiều', vad.presetLabel == 'Tách nhiều', () {
                      setDialogState(() => vad = VadSettings.many);
                    }),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Khoảng lặng tối thiểu: ${vad.minSilenceSec.toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Slider(
                  value: vad.minSilenceSec.clamp(0.4, 2.5).toDouble(),
                  min: 0.4,
                  max: 2.5,
                  divisions: 21,
                  activeColor: const Color(0xFF26C6DA),
                  inactiveColor: const Color(0xFF2A3050),
                  onChanged: (v) =>
                      setDialogState(() => vad = vad.copyWith(minSilenceSec: v)),
                ),
                Text(
                  'Đoạn tối thiểu: ${vad.minSegmentSec.toStringAsFixed(0)}s',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Slider(
                  value: vad.minSegmentSec.clamp(2, 20).toDouble(),
                  min: 2,
                  max: 20,
                  divisions: 18,
                  activeColor: const Color(0xFF26C6DA),
                  inactiveColor: const Color(0xFF2A3050),
                  onChanged: (v) =>
                      setDialogState(() => vad = vad.copyWith(minSegmentSec: v)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
    },
  );
}

Widget _vadPresetChip(String label, bool selected, VoidCallback onTap) {
  return ChoiceChip(
    selected: selected,
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selectedColor: const Color(0xFF26C6DA),
    backgroundColor: const Color(0xFF2A3050),
    labelStyle: TextStyle(
      color: selected ? Colors.black : Colors.white70,
      fontSize: 12,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
    ),
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
  );
}

// ─────────────────────────── DIALOG TIẾN TRÌNH ───────────────────────────

class _AutoTocProgressDialog extends StatelessWidget {
  final ValueNotifier<String> status;
  final bool cancelable;

  const _AutoTocProgressDialog({required this.status, required this.cancelable});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF232841),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF26C6DA)),
                  SizedBox(width: 8),
                  Text(
                    'Tự tạo mục lục…',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, msg, _) => Text(
                  msg,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<SttProgress>(
                stream: SttServiceFacade().progressStream,
                initialData: SttProgress.idle,
                builder: (context, snapshot) {
                  final p = snapshot.data ?? SttProgress.idle;
                  if (!p.isActive) {
                    return const LinearProgressIndicator(
                      backgroundColor: Color(0xFF2A3050),
                      color: Color(0xFF26C6DA),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: p.progress.clamp(0.0, 1.0).toDouble(),
                        backgroundColor: const Color(0xFF2A3050),
                        color: const Color(0xFF26C6DA),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(p.progress * 100).toStringAsFixed(0)}%  ·  ${p.message}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (cancelable)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF5350),
                      side: const BorderSide(color: Color(0xFFEF5350), width: 1),
                    ),
                    onPressed: () {
                      SttServiceFacade().cancelTranscription();
                    },
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Hủy', style: TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
