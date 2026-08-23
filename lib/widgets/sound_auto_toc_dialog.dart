// lib/widgets/sound_auto_toc_dialog.dart
// UI cho "⚡ Tự tạo mục lục âm thanh":
//   • Dialog chọn chế độ (VAD + Whisper / Chỉ VAD) + tinh chỉnh VAD
//     + chọn ngôn ngữ (D16) + PREVIEW mini-waveform (thấy ranh giới cắt).
//   • Job chạy NỀN qua SoundlistProvider.startAutoTocBackground() — người
//     dùng đóng dialog / đi dùng chỗ khác; tiến trình hiện dưới dạng
//     bong bóng ở đầu màn hình Listen (xem listen_mode_screen.dart).
//
// Được gọi từ panel Âm mục (Listen Mode) và màn hình thư viện Âm mục.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vad_settings.dart';
import '../providers/player_provider.dart';
import '../providers/soundlist_provider.dart';
import '../providers/waveform_provider.dart';
import '../services/sound_auto_toc_service.dart';

/// Chạy toàn bộ luồng tự tạo mục lục cho [audioPath] — KHÔNG block UI.
Future<void> runSoundAutoToc(
  BuildContext context, {
  required String audioPath,
  Duration? totalDuration,
  required bool hasExistingChapters,
}) async {
  final soundlist = context.read<SoundlistProvider>();

  // ── 1. Chọn chế độ + tinh chỉnh VAD + ngôn ngữ (có preview) ──
  final selection = await _showModeDialog(
    context,
    audioPath: audioPath,
    totalDuration: totalDuration,
    hasExistingChapters: hasExistingChapters,
  );
  if (selection == null || !context.mounted) return;

  final useWhisper = selection.mode == _AutoTocMode.whisper;
  final language = selection.language;

  // ── 2. Chạy NỀN (không await) — bubble ở đầu màn hình báo tiến trình ──
  unawaited(soundlist.startAutoTocBackground(
    audioPath: audioPath,
    totalDuration: totalDuration,
    useWhisper: useWhisper,
    language: language,
  ));

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('⚡ Đang tạo mục lục… '
          'bạn có thể dùng app bình thường (xem bong bóng ở đầu màn hình).'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2600),
      backgroundColor: const Color(0xFF26C6DA),
    ));
}

enum _AutoTocMode { whisper, vadOnly }

/// Kết quả chọn: (chế độ, ngôn ngữ Whisper).
typedef _AutoTocSelection = ({_AutoTocMode mode, String language});

Future<_AutoTocSelection?> _showModeDialog(
  BuildContext context, {
  required String audioPath,
  Duration? totalDuration,
  required bool hasExistingChapters,
}) async {
  final baseReady = SoundAutoTocService.isWhisperModelReady(
    WhisperModelLevel.base,
  );
  final existingWarn = hasExistingChapters
      ? '\n\n⚠️ Mục lục hiện có của file sẽ được THAY THẾ.'
      : '';

  return showDialog<_AutoTocSelection>(
    context: context,
    builder: (ctx) {
      final soundlist = ctx.read<SoundlistProvider>();
      final player = ctx.read<PlayerProvider>();
      final waveform = ctx.read<WaveformProvider>();
      var vad = soundlist.vadSettings;
      var language = 'auto'; // 'auto' | 'vi' | 'en' — D16

      // Peaks cho preview: dùng waveform thật nếu khớp file, ngược lại sóng giả.
      final normPath = audioPath.replaceAll('\\', '/');
      final hasRealWave = waveform.currentFilePath != null &&
          waveform.currentFilePath!.replaceAll('\\', '/') == normPath &&
          waveform.waveformData.isNotEmpty;
      final peaks = hasRealWave ? waveform.waveformData : _syntheticPeaks(500);

      final durationMs = (totalDuration != null &&
              totalDuration.inMilliseconds > 0)
          ? totalDuration.inMilliseconds
          : 600000; // preview mặc định 10 phút nếu chưa biết

      Future<void> pick(_AutoTocMode mode) async {
        await soundlist.setVadSettings(vad);
        if (ctx.mounted) {
          Navigator.pop(ctx, (mode: mode, language: language));
        }
      }

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final boundaries = SoundAutoTocService.computeBoundaryMs(
            peaks,
            durationMs,
            settings: vad,
          );
          return AlertDialog(
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
                    'App sẽ phân tích âm thanh và tạo mục lục như sách.$existingWarn\n\n'
                    '🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trình hiện ở đầu màn hình.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
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

                  // ── Preview mini-waveform + ranh giới cắt ──
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq, color: Color(0xFF26C6DA), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Xem trước các đoạn sẽ cắt',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        boundaries.isEmpty ? 'chưa có ranh giới' : '${boundaries.length + 1} đoạn',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F31),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _VadPreviewPainter(
                        peaks: peaks,
                        durationMs: durationMs,
                        boundaries: boundaries,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '⬇ Kéo các thanh trượt bên dưới — vạch vàng là nơi file sẽ được cắt. '
                    'Nếu không có vạch nào, app sẽ tự chia đều.',
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.4),
                  ),
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

                  // ── Ngôn ngữ nhận diện (D16) ──
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Ngôn ngữ nhận diện',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _langChip('🌐 Tự động', language == 'auto', () {
                        setDialogState(() => language = 'auto');
                      }),
                      _langChip('🇻🇳 Tiếng Việt', language == 'vi', () {
                        setDialogState(() => language = 'vi');
                      }),
                      _langChip('🇬🇧 English', language == 'en', () {
                        setDialogState(() => language = 'en');
                      }),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language == 'vi'
                        ? 'Tiêu đề chương sẽ ra tiếng Việt có dấu.'
                        : language == 'en'
                            ? 'Tiêu đề chương sẽ ra tiếng Anh.'
                            : 'Tự động — hiện mặc định tiếng Anh (xem báo cáo D16).',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Sóng giả (deterministic) cho preview khi chưa có waveform thật.
List<double> _syntheticPeaks(int count) {
  final rnd = math.Random(7);
  return List.generate(count, (i) {
    final v = math.sin(i * 0.09) * 0.3 +
        math.sin(i * 0.023) * 0.25 +
        (rnd.nextDouble() - 0.5) * 0.5;
    return v.abs().clamp(0.05, 1.0);
  });
}

/// Vẽ mini-waveform + vạch ranh giới cắt (vàng) + vùng đoạn xen kẽ.
class _VadPreviewPainter extends CustomPainter {
  final List<double> peaks;
  final int durationMs;
  final List<int> boundaries;

  _VadPreviewPainter({
    required this.peaks,
    required this.durationMs,
    required this.boundaries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || durationMs <= 0) return;

    final barPaint = Paint()
      ..color = const Color(0xFF26C6DA).withValues(alpha: 0.55);
    final boundPaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = 1.6;

    final slot = size.width / peaks.length;
    final mid = size.height / 2;

    // Waveform bars.
    for (int i = 0; i < peaks.length; i++) {
      final h = (peaks[i].clamp(0.02, 1.0) * (size.height - 6)).toDouble();
      final x = i * slot + slot / 2;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), barPaint);
    }

    // Vùng đoạn xen kẽ (trước vạch) — tô nhẹ.
    if (boundaries.isNotEmpty) {
      final regionPaint = Paint()..color = Colors.white.withValues(alpha: 0.05);
      var prevX = 0.0;
      for (int i = 0; i < boundaries.length; i++) {
        final x = (boundaries[i] / durationMs) * size.width;
        if (i.isEven) {
          canvas.drawRect(Rect.fromLTRB(prevX, 0, x, size.height), regionPaint);
        }
        prevX = x;
      }
      if (boundaries.length.isEven) {
        canvas.drawRect(
            Rect.fromLTRB(prevX, 0, size.width, size.height), regionPaint);
      }
    }

    // Vạch ranh giới.
    for (final b in boundaries) {
      final x = (b / durationMs) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), boundPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VadPreviewPainter old) =>
      old.boundaries != boundaries || old.peaks != peaks;
}

Widget _langChip(String label, bool selected, VoidCallback onTap) {
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
