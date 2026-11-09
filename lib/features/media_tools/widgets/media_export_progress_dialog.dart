// lib/features/media_tools/widgets/media_export_progress_dialog.dart
//
// AVTOOL-003 (PLAN-047 P2) — HỘP TIẾN TRÌNH + HUỶ.
//
// Ba yêu cầu bắt buộc (thiếu cái nào cũng thành "app treo"):
//   1. Huỷ phải xuống tới native (FfmpegCancelToken) và xoá file dở.
//   2. Chặn đóng dialog bằng nút Back khi đang chạy (đóng mà tác vụ vẫn chạy
//      ⇒ người dùng tưởng đã huỷ, máy vẫn nóng, file vẫn ghi).
//   3. Không giữ BuildContext sau await (dùng `if (!mounted) return`).

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
// `show Text` từ material sẽ che shim `Text` của `localized_material.dart`
// (luật #5) ⇒ đã bỏ `Text` khỏi danh sách show.
import 'package:flutter/material.dart' show AlertDialog, BorderRadius,
    BoxDecoration, Colors, EdgeInsets, FontWeight, LinearProgressIndicator,
    SizedBox, TextStyle, RoundedRectangleBorder, TextButton, Icon, Icons,
    CrossAxisAlignment, MainAxisSize, MainAxisAlignment, Widget, ExpansionTile,
    PopScope, Container;

import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';

import '../models/media_export_models.dart';
import '../services/media_estimates.dart';
import '../services/media_export_service.dart';
import '../services/media_ffmpeg_engine.dart';

/// Chạy xuất file trong hộp thoại có tiến trình. Trả kết quả hoặc null nếu
/// huỷ/lỗi (lỗi đã hiển thị trong hộp thoại).
Future<MediaExportResult?> showMediaExportProgressDialog(
  BuildContext context, {
  required MediaExportRequest request,
  int? estimatedBytes,
}) {
  return showDialog<MediaExportResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MediaExportProgressDialog(
      request: request,
      estimatedBytes: estimatedBytes,
    ),
  );
}

enum _Phase { running, cancelRequested, failed, done }

class _MediaExportProgressDialog extends StatefulWidget {
  const _MediaExportProgressDialog({
    required this.request,
    this.estimatedBytes,
  });

  final MediaExportRequest request;
  final int? estimatedBytes;

  @override
  State<_MediaExportProgressDialog> createState() =>
      _MediaExportProgressDialogState();
}

class _MediaExportProgressDialogState
    extends State<_MediaExportProgressDialog> {
  final MediaExportService _service = MediaExportService();
  final FfmpegCancelToken _token = FfmpegCancelToken();

  MediaExportProgress _progress =
      const MediaExportProgress(phase: MediaExportPhase.preparing);
  _Phase _phase = _Phase.running;
  MediaExportError? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await _service.export(
        widget.request,
        token: _token,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      _cancelFallback?.cancel();
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
      Navigator.of(context).pop(result);
    } on MediaExportException catch (e) {
      _cancelFallback?.cancel();
      if (!mounted) return;
      setState(() {
        _phase = e.kind == MediaExportErrorKind.cancelled
            ? _Phase.cancelRequested
            : _Phase.failed;
        _error = e.toError();
      });
    } catch (e) {
      _cancelFallback?.cancel();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = MediaExportError(MediaExportErrorKind.failed, detail: '$e');
      });
    }
  }

  Future<void> _cancel() async {
    if (_phase != _Phase.running) return;
    // Đặt cờ TRƯỚC khi gọi native: service kiểm `token.isCancelled` ở mọi
    // bước, nên nếu đang ở bước chuẩn bị/probe thì lần kiểm kế tiếp sẽ ném
    // `cancelled` và dialog đóng — không phụ thuộc việc `cancel()` native có
    // trả lời hay không.
    setState(() => _phase = _Phase.cancelRequested);
    await _token.cancel();
    if (!mounted) return;
    // Nếu `_run()` không còn gì để chờ (ví dụ session chưa kịp tạo và native
    // không bao giờ trả lời) thì đóng sau 8 s để người dùng KHÔNG bị treo ở
    // "Đang huỷ…". Đóng với `null` = "không có kết quả", đúng nghĩa huỷ.
    _cancelFallback?.cancel();
    _cancelFallback = Timer(const Duration(seconds: 8), () {
      if (!mounted || _phase != _Phase.cancelRequested) return;
      Navigator.of(context).pop(null);
    });
  }

  Timer? _cancelFallback;

  @override
  void dispose() {
    _cancelFallback?.cancel();
    super.dispose();
  }

  String _title(BuildContext context) {
    switch (_phase) {
      case _Phase.done:
        return context.uiText('Đã xuất xong');
      case _Phase.failed:
        return context.uiText('Xuất thất bại');
      case _Phase.cancelRequested:
        return context.uiText('Đang huỷ…');
      case _Phase.running:
        return context.uiText('Đang xuất…');
    }
  }

  String _errorKey(BuildContext context, MediaExportError error) {
    switch (error.kind) {
      case MediaExportErrorKind.ffmpegMissing:
        return context.uiText('FFmpeg chưa có trên máy này');
      case MediaExportErrorKind.inputUnreadable:
        return context.uiText('Không đọc được file nguồn');
      case MediaExportErrorKind.noAudioTrack:
        return context.uiText('File nguồn không có âm thanh');
      case MediaExportErrorKind.unsupported:
        return context.uiText('Định dạng này chưa được hỗ trợ');
      case MediaExportErrorKind.noSpace:
        return context.uiText('Không đủ dung lượng trống');
      case MediaExportErrorKind.cancelled:
        return context.uiText('Đã huỷ');
      case MediaExportErrorKind.failed:
        return context.uiText('Có lỗi khi xuất file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _progress.totalSlices;
    final current = _progress.currentSlice + 1;

    return PopScope(
      canPop: _phase == _Phase.failed || _phase == _Phase.cancelRequested,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _title(context),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_phase == _Phase.running ||
                _phase == _Phase.cancelRequested) ...[
              LinearProgressIndicator(
                value: _progress.fraction <= 0 ? null : _progress.fraction,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFF26C6DA),
              ),
              const SizedBox(height: 10),
              Text(
                _statusLine(context),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (total > 1) ...[
                const SizedBox(height: 4),
                Text(
                  context.uiText('Phần $current/$total'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ],
            if (_phase == _Phase.failed && _error != null) ...[
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorKey(context, _error!),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if ((_error?.detail ?? '').isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: Colors.white54,
                  collapsedIconColor: Colors.white54,
                  title: Text(
                    context.uiText('Chi tiết kỹ thuật'),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!.detail!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
        actions: [
          if (_phase == _Phase.running)
            TextButton(
              onPressed: _cancel,
              child: Text(
                context.uiText('Huỷ'),
                style: const TextStyle(color: Color(0xFFEF5350)),
              ),
            ),
          if (_phase == _Phase.failed || _phase == _Phase.cancelRequested)
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(context.uiText('Đóng')),
            ),
        ],
      ),
    );
  }

  String _statusLine(BuildContext context) {
    switch (_progress.phase) {
      case MediaExportPhase.preparing:
        return context.uiText('Đang chuẩn bị…');
      case MediaExportPhase.running:
        final parts = <String>[];
        if (_progress.fraction > 0) {
          parts.add('${(_progress.fraction * 100).clamp(0, 100).toStringAsFixed(0)}%');
        }
        if (_progress.elapsedMs > 0) {
          parts.add(_fmt(_progress.elapsedMs));
        }
        if (widget.estimatedBytes != null) {
          parts.add('${context.uiText('Ước lượng')} '
              '${MediaEstimates.formatBytes(widget.estimatedBytes!)}');
        }
        return parts.isEmpty ? context.uiText('Đang xuất…') : parts.join(' · ');
      case MediaExportPhase.finalizing:
        return context.uiText('Đang gắn lời và đăng ký vào thư viện…');
      case MediaExportPhase.done:
        return context.uiText('Đã xuất xong');
      case MediaExportPhase.failed:
        return context.uiText('Xuất thất bại');
      case MediaExportPhase.cancelled:
        return context.uiText('Đã huỷ');
    }
  }

  static String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
