// lib/features/media_tools/widgets/media_export_sheet.dart
//
// AVTOOL-003 (PLAN-046 P2) — MỘT sheet xuất media cho MỌI lối vào.
//
// Lý do gộp (không chép UI 6 lần): 6 bề mặt (đoạn A–B ở tab Nghe, menu file
// tab Nghe, âm mục, video, YouTube, TTS) đều cần đúng 4 quyết định: phạm vi,
// định dạng, chất lượng, đăng ký hay không. Chép tay 6 bản ⇒ 6 chỗ lệch nhau
// (bài học từ ADR-0024: cùng một nút nhưng 2 nơi gọi 2 setter khác nhau).
//
// Nguyên tắc UI:
//   - Ước lượng dung lượng hiện TRƯỚC khi bấm (không để bất ngờ 130 MB).
//   - Cảnh báo "phải mã hoá lại" hiện ngay khi chọn preset, không đợi lỗi.
//   - Mọi chuỗi đi qua `context.uiText` (luật #5) — không hard-code tiếng Việt
//     ra `Text` rồi hy vọng shim bắt (shim chỉ exact match).

import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/material.dart' show Icons, BorderRadius, BoxDecoration,
    Colors, EdgeInsets, FontWeight, LinearProgressIndicator, LinearGradient,
    Radius, SizedBox, TextStyle, CrossAxisAlignment, MainAxisAlignment,
    MainAxisSize, Divider, Icon, SwitchListTile, FilledButton,
    RoundedRectangleBorder, Material, InkWell, Alignment, Color;
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/media_export_models.dart';
import '../services/media_estimates.dart';
import '../services/media_export_diagnostics.dart';
import '../services/media_ffmpeg_engine.dart';
import 'media_export_progress_dialog.dart';
import 'media_export_follow_up.dart';
import 'ffmpeg_install_sheet.dart';

const _bg = Color(0xFF141D2E);
const _accent = Color(0xFF6C63FF);
const _accent2 = Color(0xFF26C6DA);

/// Mở sheet xuất media. Trả `MediaExportResult` khi thành công, null khi huỷ.
Future<MediaExportResult?> showMediaExportSheet(
  BuildContext context, {
  required MediaExportRequest initialRequest,

  /// Độ dài file nguồn (nếu đã biết) — dùng để ước lượng + hiển thị.
  Duration? knownDuration,

  /// Bitrate nguồn (kbps) nếu biết (từ probe) — cần cho preset "copy".
  int? sourceBitrateKbps,

  /// Có LRC nguồn không (quyết định hiện tuỳ chọn "kèm lời").
  bool hasSourceLrc = false,
}) {
  return showModalBottomSheet<MediaExportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MediaExportSheet(
      initialRequest: initialRequest,
      knownDuration: knownDuration,
      sourceBitrateKbps: sourceBitrateKbps,
      hasSourceLrc: hasSourceLrc,
    ),
  );
}

class _MediaExportSheet extends StatefulWidget {
  const _MediaExportSheet({
    required this.initialRequest,
    this.knownDuration,
    this.sourceBitrateKbps,
    this.hasSourceLrc = false,
  });

  final MediaExportRequest initialRequest;
  final Duration? knownDuration;
  final int? sourceBitrateKbps;
  final bool hasSourceLrc;

  @override
  State<_MediaExportSheet> createState() => _MediaExportSheetState();
}

class _MediaExportSheetState extends State<_MediaExportSheet> {
  late MediaExportRequest _request;
  late MediaExportPreset _preset;
  bool _keepLrc = false;
  bool _registerInRecent = true;
  bool _ffmpegReady = true;
  bool _checkingFfmpeg = true;
  String? _ffmpegProblem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest;
    _preset = widget.initialRequest.preset;
    _keepLrc = widget.hasSourceLrc && widget.initialRequest.keepLrc;
    _registerInRecent = widget.initialRequest.registerInRecent;
    _checkFfmpeg();
  }

  Future<void> _checkFfmpeg() async {
    try {
      final available = await MediaFfmpegEngine().ensureAvailable();
      if (!mounted) return;
      setState(() {
        _ffmpegReady = available;
        _checkingFfmpeg = false;
        _ffmpegProblem = available
            ? null
            : 'FFmpeg chưa có trên máy này';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ffmpegReady = false;
        _checkingFfmpeg = false;
        _ffmpegProblem = 'FFmpeg chưa có trên máy này';
      });
    }
  }

  Duration? get _scopeDuration {
    final total = widget.knownDuration;
    switch (_request.scope) {
      case MediaExportScope.full:
        return total;
      case MediaExportScope.clip:
        return _request.duration ??
            (total == null ? null : total - _request.start);
      case MediaExportScope.chapters:
        if (_request.slices.isEmpty) return total;
        var sum = Duration.zero;
        for (final s in _request.slices) {
          sum += s.duration ?? Duration.zero;
        }
        return sum;
    }
  }

  int? get _estimateBytes => MediaEstimates.estimateBytes(
        preset: _preset,
        duration: _scopeDuration,
        sourceBitrateKbps: widget.sourceBitrateKbps,
      );

  bool get _needsReencode {
    // Cảnh báo trước khi chạy: preset copy mà nguồn có thể không phải AAC.
    if (!_preset.isCopy) return false;
    final name = widget.initialRequest.inputPath.toLowerCase();
    final looksAac = name.endsWith('.m4a') ||
        name.endsWith('.mp4') ||
        name.endsWith('.m4b') ||
        name.endsWith('.aac');
    if (!looksAac) return true;
    // Cắt đoạn bằng copy lệch frame ⇒ với clip nên mã hoá lại.
    return _request.scope == MediaExportScope.clip;
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final request = _request.copyWith(
      preset: _preset,
      keepLrc: _keepLrc,
      registerInRecent: _registerInRecent,
    );

    final result = await showMediaExportProgressDialog(
      context,
      request: request,
      estimatedBytes: _estimateBytes,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;

    // Đóng sheet, trả kết quả cho lối vào.
    Navigator.of(context).pop(result);
    await offerExportFollowUp(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimateBytes;
    final shownDuration = _scopeDuration;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.content_cut, color: _accent2, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.uiText(_sheetTitle(_request.scope)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _subtitle(shownDuration, estimate),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              if (_checkingFfmpeg)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (!_ffmpegReady)
                _FfmpegMissingCard(problem: _ffmpegProblem)
              else ...[
                _sectionLabel(context, 'Định dạng'),
                _presetList(context),
                if (_needsReencode)
                  _warning(context,
                      'Định dạng này cần mã hoá lại — sẽ chậm hơn nhưng đúng mốc thời gian.'),
                if (widget.hasSourceLrc) ...[
                  SwitchListTile.adaptive(
                    value: _keepLrc,
                    onChanged: (v) => setState(() => _keepLrc = v),
                    activeThumbColor: _accent2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(
                      context.uiText('Kèm lời (LRC) đã chỉnh mốc'),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      context.uiText(
                          'Giữ karaoke đúng mốc để nghe lại và lặp A–B.'),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ],
                SwitchListTile.adaptive(
                  value: _registerInRecent,
                  onChanged: (v) => setState(() => _registerInRecent = v),
                  activeThumbColor: _accent2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    context.uiText('Thêm vào tab Nghe (Gần đây)'),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(context.uiText('Bắt đầu xuất')),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _sheetTitle(MediaExportScope scope) {
    switch (scope) {
      case MediaExportScope.full:
        return 'Xuất file âm thanh';
      case MediaExportScope.clip:
        return 'Xuất đoạn đang chọn';
      case MediaExportScope.chapters:
        return 'Tách theo mục lục';
    }
  }

  String _subtitle(Duration? duration, int? estimate) {
    final parts = <String>[];
    if (duration != null && duration.inMilliseconds > 0) {
      parts.add('${context.uiText('Độ dài')}: ${_fmt(duration)}');
    }
    if (estimate != null) {
      parts.add('${context.uiText('Ước lượng')}: '
          '${MediaEstimates.formatBytes(estimate)}');
    }
    if (_request.scope == MediaExportScope.chapters &&
        _request.slices.isNotEmpty) {
      parts.add('${_request.slices.length} ${context.uiText('phần')}');
    }
    if (parts.isEmpty) return context.uiText('Chọn định dạng rồi bấm bắt đầu.');
    return parts.join(' · ');
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _sectionLabel(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: Text(
          context.uiText(key),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _presetList(BuildContext context) {
    final options = _availablePresets();
    return Column(
      children: [
        for (final preset in options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Material(
              color: _preset == preset
                  ? _accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _preset = preset),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        _preset == preset
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _preset == preset ? _accent2 : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.uiText(preset.labelKey),
                          style: TextStyle(
                            color: _preset == preset
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        preset.extension.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Preset gợi ý theo ngữ cảnh — không bày 7 lựa chọn cho người chỉ muốn
  /// "lấy câu này ra nghe".
  List<MediaExportPreset> _availablePresets() {
    if (_request.scope == MediaExportScope.clip) {
      return const [
        MediaExportPreset.mp3Standard,
        MediaExportPreset.mp3Voice,
        MediaExportPreset.wavPcm,
      ];
    }
    if (_request.inputKind == MediaExportInputKind.video) {
      return const [
        MediaExportPreset.m4aCopy,
        MediaExportPreset.mp3Standard,
        MediaExportPreset.m4aAac,
      ];
    }
    return const [
      MediaExportPreset.mp3Standard,
      MediaExportPreset.mp3Voice,
      MediaExportPreset.m4aCopy,
      MediaExportPreset.wavPcm,
      MediaExportPreset.opus,
    ];
  }

  Widget _warning(BuildContext context, String message) => Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.uiText(message),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      );
}

class _FfmpegMissingCard extends StatelessWidget {
  const _FfmpegMissingCard({this.problem});

  final String? problem;

  @override
  Widget build(BuildContext context) {
    final canInstall = !Platform.isAndroid && !Platform.isIOS;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFEF5350), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.uiText(problem ?? 'FFmpeg chưa có trên máy này'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canInstall
                ? context.uiText(
                    'Tải FFmpeg (~90 MB) một lần để dùng công cụ này. Không tải trước, app vẫn nhẹ như cũ.')
                : context.uiText(
                    'Bản cài này thiếu FFmpeg. Hãy cập nhật app hoặc dùng bản đầy đủ.'),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (canInstall) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showFfmpegInstallSheet(context),
                style: FilledButton.styleFrom(backgroundColor: _accent),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(context.uiText('Tải FFmpeg')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nhãn tiện dụng cho UI khác (giữ 1 nguồn).
String mediaExportScopeLabel(BuildContext context, MediaExportScope scope) {
  switch (scope) {
    case MediaExportScope.full:
      return context.uiText('Toàn bộ file');
    case MediaExportScope.clip:
      return context.uiText('Đoạn đang chọn');
    case MediaExportScope.chapters:
      return context.uiText('Theo mục lục');
  }
}

/// Divider mỏng dùng chung (giữ style đồng nhất).
Widget mediaSheetDivider() => const Divider(
      color: Colors.white12,
      height: 1,
      indent: 20,
      endIndent: 20,
    );

/// Gradient tiêu đề dùng chung.
LinearGradient get mediaSheetGradient => const LinearGradient(
      colors: [_accent, _accent2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
