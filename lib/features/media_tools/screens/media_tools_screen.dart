// lib/features/media_tools/screens/media_tools_screen.dart
//
// AVTOOL-002 (PLAN-047 P1) — MÀN "Công cụ media": chẩn đoán + lối vào chuyển đổi.
//
// Vì sao cần màn riêng (không chỉ nhét vào sheet):
//   - Trên DESKTOP, "có FFmpeg hay không" là câu hỏi đầu tiên. Phải có chỗ trả
//     lời rõ (phiên bản, đường dẫn binary, kết quả tự kiểm encode mp3) + nút
//     tải, thay vì để người dùng gặp lỗi mơ hồ ở giữa luồng.
//   - Là nơi duy nhất để báo "bản build này có encoder mp3 hay không" (bản
//     `audio`/`min` của ffmpeg-kit có thể thiếu libmp3lame).
//   - Cũng là lối vào tổng: chọn 1 file → chuyển định dạng (không cần mở player).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';
// KHÔNG `show Text` từ material: shim `Text` của `localized_material.dart` là
// thứ dịch chuỗi (luật #5). `show Text` ở đây sẽ che shim ⇒ chuỗi không dịch.
import 'package:flutter/material.dart' hide Text;

import '../models/media_export_models.dart';
import '../services/media_export_diagnostics.dart';
import '../widgets/ffmpeg_install_sheet.dart';
import '../widgets/media_export_sheet.dart';

class MediaToolsScreen extends StatefulWidget {
  const MediaToolsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<MediaToolsScreen> createState() => _MediaToolsScreenState();
}

class _MediaToolsScreenState extends State<MediaToolsScreen> {
  static const _accent = Color(0xFF26C6DA);

  MediaDiagnosticsReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _loading = true);
    final report = await const MediaExportDiagnostics().run();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _pickAndConvert() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(type: FileType.media);
    } catch (e) {
      debugPrintMediaTools('pickFiles error: $e');
      return;
    }
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final name = picked!.files.single.name;
    await showMediaExportSheet(
      context,
      initialRequest: MediaExportRequest(
        inputPath: path,
        preset: MediaExportPreset.recommended(
          inputExtension: name.contains('.')
              ? name.substring(name.lastIndexOf('.'))
              : '',
        ),
        inputKind: _looksLikeVideo(name)
            ? MediaExportInputKind.video
            : MediaExportInputKind.audio,
        title: name,
      ),
    );
  }

  static bool _looksLikeVideo(String name) {
    final lower = name.toLowerCase();
    const videoExt = [
      '.mp4', '.mkv', '.webm', '.mov', '.avi', '.m4v', '.3gp', '.ts',
    ];
    return videoExt.any(lower.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        toolbarHeight: widget.showBackButton ? kToolbarHeight : 40,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _accent),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          context.uiText('Công cụ media'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loading ? null : _runDiagnostics,
            tooltip: context.uiText('Kiểm tra lại'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _diagnosticsCard(context),
              const SizedBox(height: 14),
              Text(
                context.uiText('Chuyển đổi & cắt'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              _actionTile(
                context,
                icon: Icons.swap_horiz_rounded,
                titleKey: 'Chuyển định dạng file',
                subtitleKey: 'MP4/M4A → MP3, WAV, Opus… (giữ file gốc)',
                onTap: _pickAndConvert,
              ),
              _actionTile(
                context,
                icon: Icons.content_cut,
                titleKey: 'Cắt một đoạn',
                subtitleKey: 'Từ tab Nghe: đặt A–B rồi bấm «Xuất đoạn»',
                onTap: null,
              ),
              _actionTile(
                context,
                icon: Icons.video_library_outlined,
                titleKey: 'Tách âm thanh từ video',
                subtitleKey: 'Mở video → menu ⋮ → Tách âm thanh',
                onTap: null,
              ),
              _actionTile(
                context,
                icon: Icons.menu_book_outlined,
                titleKey: 'Tách theo mục lục',
                subtitleKey: 'Cần file đã có Âm mục/chương',
                onTap: null,
              ),
              const SizedBox(height: 10),
              Text(
                context.uiText(
                  'Mẹo: mọi bản xuất đều được thêm vào tab Nghe (nếu bật) và giữ lời (LRC) đã chỉnh mốc — nhờ vậy vẫn karaoke và lặp A–B được.',
                ),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diagnosticsCard(BuildContext context) {
    final report = _report;
    final ready = report?.isReady ?? false;
    return Card(
      color: const Color(0xFF141D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _loading
                      ? Icons.hourglass_empty
                      : (ready ? Icons.check_circle : Icons.error_outline),
                  color: _loading
                      ? Colors.white54
                      : (ready ? const Color(0xFF00E676) : const Color(0xFFEF5350)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loading
                        ? context.uiText('Đang kiểm tra FFmpeg…')
                        : (ready
                            ? context.uiText('FFmpeg sẵn sàng')
                            : context.uiText('Chưa dùng được FFmpeg')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (!_loading && report != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    context,
                    report.available
                        ? 'FFmpeg: có'
                        : 'FFmpeg: không có',
                    ok: report.available,
                  ),
                  if (report.mp3EncoderFound != null)
                    _chip(
                      context,
                      report.mp3EncoderFound!
                          ? 'MP3 encoder: có'
                          : 'MP3 encoder: thiếu',
                      ok: report.mp3EncoderFound!,
                    ),
                  if (report.selfTestPassed != null)
                    _chip(
                      context,
                      report.selfTestPassed!
                          ? 'Tự kiểm: đạt'
                          : 'Tự kiểm: lỗi',
                      ok: report.selfTestPassed!,
                    ),
                ],
              ),
              if (report.versionLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  report.versionLine!,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
              if (report.binaryPath != null) ...[
                const SizedBox(height: 2),
                Text(
                  report.binaryPath!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
              if (!report.available) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!Platform.isAndroid && !Platform.isIOS)
                      ElevatedButton.icon(
                        onPressed: () async {
                          await showFfmpegInstallSheet(context);
                          await _runDiagnostics();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(context.uiText('Tải FFmpeg')),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _runDiagnostics,
                      child: Text(context.uiText('Kiểm tra lại')),
                    ),
                  ],
                ),
              ],
              if (report.selfTestDetail != null) ...[
                const SizedBox(height: 8),
                Text(
                  report.selfTestDetail!,
                  style:
                      const TextStyle(color: Color(0xFFEF5350), fontSize: 10),
                ),
              ],
              if (report.platformNote != null) ...[
                const Divider(color: Colors.white12, height: 16),
                Text(
                  context.uiText(report.platformNote!),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String key, {required bool ok}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (ok ? const Color(0xFF00E676) : const Color(0xFFEF5350))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.uiText(key),
          style: TextStyle(
            color: ok ? const Color(0xFF00E676) : const Color(0xFFEF5350),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String subtitleKey,
    required void Function()? onTap,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, color: onTap == null ? Colors.white24 : _accent),
        title: Text(
          context.uiText(titleKey),
          style: TextStyle(
            color: onTap == null ? Colors.white38 : Colors.white,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          context.uiText(subtitleKey),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      );
}

/// Log nhỏ (tránh phụ thuộc `dart:developer` ở tầng UI, giữ test nhẹ).
void debugPrintMediaTools(String message) {
  // ignore: avoid_print
  assert(() {
    // ignore: avoid_print
    print('[MediaTools] $message');
    return true;
  }());
}
