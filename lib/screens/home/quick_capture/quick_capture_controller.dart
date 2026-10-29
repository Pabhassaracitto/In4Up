// lib/screens/home/quick_capture/quick_capture_controller.dart
//
// HOME-QUICK-001 — "Nạp tri thức nhanh" (tab Home).
//
// Controller của MỘT phiên ghi âm nhanh: bật engine STT hiện có của app
// (ưu tiên Sherpa offline khi đã import model), gom transcript realtime,
// dừng sạch và giao nội dung cho tầng lưu (WordList / ghi chú).
//
// Nguyên tắc:
//  * KHÔNG tạo STT singleton thứ hai — controller chỉ điều phối các
//    [QuickCaptureSttSource] (Sherpa engine / SttServiceFacade có sẵn).
//  * KHÔNG fire-and-forget mic: [start] chỉ chạy khi có owner, [stop]/
//    [dispose] luôn huỷ subscription + tắt engine + nhả recorder.
//  * Toàn bộ quyết định trạng thái nằm ở đây (không phụ thuộc widget)
//    nên test được bằng nguồn STT giả.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/models/stt_result.dart';

/// Trạng thái của một phiên nạp tri thức nhanh.
enum QuickCaptureStatus { idle, starting, listening, stopping, error }

/// Engine STT thật sự đang chạy (để UI hiển thị + chẩn đoán).
enum QuickCaptureEngineKind { sherpaOffline, system }

/// Nguyên nhân lỗi có cấu trúc — UI map sang chuỗi đã dịch.
enum QuickCaptureFailure {
  none,
  microphonePermission,
  noEngineAvailable,
  startFailed,
  streamFailed,
}

/// Seam tối thiểu cho một nguồn STT live dùng trong quick capture.
///
/// Hai implementation thật: `SherpaQuickCaptureSource` (Zipformer offline/
/// streaming qua sherpa-onnx) và `SystemQuickCaptureSource`
/// (`SttServiceFacade` — speech service của hệ thống).
abstract class QuickCaptureSttSource {
  /// Loại engine (thứ tự ưu tiên do caller sắp xếp — Sherpa trước).
  QuickCaptureEngineKind get kind;

  /// Mã ngôn ngữ engine này sẽ nhận diện ('vi', 'en', ...).
  String get language;

  /// Kiểm tra nhanh trước khi start (vd: model đã import chưa).
  /// Nguồn luôn sẵn sàng về mặt kỹ thuật (system STT) trả `true`;
  /// lỗi thật sẽ lộ ra ở [start].
  bool get isReady;

  /// Lý do [isReady] == `false` — gộp vào thông báo fallback cho user
  /// (`null` nếu nguồn không có lý do cụ thể).
  String? get unavailableReason;

  /// Bật phiên nghe. `false` = không khởi động được (xem [lastError]).
  Future<bool> start();

  /// Luồng kết quả từng phần / đã chốt.
  Stream<SttResult> get results;

  /// Lỗi gần nhất của engine (null = không có).
  String? get lastError;

  /// Dừng phiên nghe và nhả tài nguyên phiên (recorder, subscription).
  Future<void> stop();

  /// Giải phóng tài nguyên NẶNG của engine (recognizer native) khi phiên
  /// kết thúc hẳn. Nguồn không tự nạp model thì để thân rỗng.
  ///
  /// (Khai báo abstract, không có thân mặc định: Dart bắt class `implements`
  /// phải tự triển khai mọi member — thân mặc định ở interface sẽ thành bẫy
  /// "Missing concrete implementation" cho người thêm nguồn mới.)
  Future<void> release();
}

/// Controller một phiên "Nạp tri thức nhanh".
///
/// Vòng đời: tạo khi mở sheet → [start] → transcript realtime → [stop]
/// (hoặc lưu) → [dispose] khi sheet đóng.
class QuickCaptureController extends ChangeNotifier {
  QuickCaptureController({
    required List<QuickCaptureSttSource> sources,
    Future<bool> Function()? ensureMicrophonePermission,
  })  : _sources = List<QuickCaptureSttSource>.unmodifiable(sources),
        _ensureMicrophonePermission = ensureMicrophonePermission;

  final List<QuickCaptureSttSource> _sources;

  /// Seam quyền microphone (permission_handler). Null = bỏ qua bước xin
  /// quyền (desktop/test) — engine tự báo lỗi nếu máy không có mic.
  final Future<bool> Function()? _ensureMicrophonePermission;

  bool _disposed = false;
  StreamSubscription<SttResult>? _subscription;
  QuickCaptureSttSource? _activeSource;

  QuickCaptureStatus _status = QuickCaptureStatus.idle;
  QuickCaptureFailure _failure = QuickCaptureFailure.none;
  String? _failureDetail;
  String? _unavailableDetail;

  QuickCaptureEngineKind? _engineKind;
  String? _engineLanguage;

  final List<String> _finalSegments = <String>[];
  String _partialText = '';
  String _lastFinalText = '';

  // ── Getters ─────────────────────────────────────────────────────────────

  QuickCaptureStatus get status => _status;
  bool get isListening => _status == QuickCaptureStatus.listening;
  bool get isBusy =>
      _status == QuickCaptureStatus.starting ||
      _status == QuickCaptureStatus.stopping;

  /// Engine của phiên hiện tại (hoặc phiên vừa dừng — để chip UI giữ nhãn).
  QuickCaptureEngineKind? get engineKind => _engineKind;
  String? get engineLanguage => _engineLanguage;

  QuickCaptureFailure get failure => _failure;

  /// Chi tiết lỗi từ engine (không dịch — chỉ dùng để chẩn đoán/log).
  String? get failureDetail => _failureDetail;

  /// Lý do một engine bị bỏ qua (vd: chưa import model Zipformer).
  String? get unavailableDetail => _unavailableDetail;

  /// Các câu đã chốt (VAD/native final).
  List<String> get finalSegments => List<String>.unmodifiable(_finalSegments);

  /// Câu đang nhận diện dở (chưa chốt).
  String get partialText => _partialText;

  /// Toàn bộ transcript: các câu đã chốt + câu đang nói dở.
  String get transcript {
    final parts = <String>[..._finalSegments];
    final partial = _partialText.trim();
    if (partial.isNotEmpty) parts.add(partial);
    return parts.join(' ').trim();
  }

  bool get hasTranscript => transcript.isNotEmpty;

  // ── Controls ────────────────────────────────────────────────────────────

  /// Bật phiên nghe. Trả `true` khi mic đang chạy.
  ///
  /// Thứ tự: xin quyền mic → chọn nguồn sẵn sàng ĐẦU TIÊN trong danh sách
  /// (caller đã xếp Sherpa offline trước system STT) → start → subscribe.
  Future<bool> start() async {
    if (_disposed) return false;
    if (_status == QuickCaptureStatus.listening ||
        _status == QuickCaptureStatus.starting) {
      return _status == QuickCaptureStatus.listening;
    }

    _failure = QuickCaptureFailure.none;
    _failureDetail = null;
    _unavailableDetail = null;
    _setStatus(QuickCaptureStatus.starting);

    if (_ensureMicrophonePermission != null) {
      var granted = false;
      try {
        granted = await _ensureMicrophonePermission!();
      } catch (e) {
        debugPrint('⚠️ QuickCapture: permission check error: $e');
        granted = true; // máy không có permission API → để engine tự xử
      }
      if (_disposed) return false;
      if (!granted) {
        _fail(QuickCaptureFailure.microphonePermission);
        return false;
      }
    }

    final readySources = _sources.where((s) => s.isReady).toList();
    final skipped = _sources.where((s) => !s.isReady).toList();
    if (skipped.isNotEmpty) {
      _unavailableDetail = skipped
          .map((s) => s.unavailableReason ?? s.kind.name)
          .join(' · ');
    }

    if (readySources.isEmpty) {
      _fail(
        QuickCaptureFailure.noEngineAvailable,
        detail: _unavailableDetail,
      );
      return false;
    }

    String? lastStartError;
    for (final source in readySources) {
      var started = false;
      try {
        started = await source.start();
      } catch (e) {
        lastStartError = '$e';
        debugPrint('❌ QuickCapture: ${source.kind.name} start error: $e');
      }
      if (_disposed) {
        await _stopSourceQuietly(source);
        return false;
      }
      if (!started) {
        lastStartError = source.lastError ?? lastStartError;
        await _stopSourceQuietly(source);
        continue;
      }

      _activeSource = source;
      _engineKind = source.kind;
      _engineLanguage = source.language;
      await _subscription?.cancel();
      _subscription = source.results.listen(
        _onResult,
        onError: (Object e) {
          debugPrint('❌ QuickCapture: stream error: $e');
          _fail(QuickCaptureFailure.streamFailed, detail: '$e');
        },
        cancelOnError: true,
      );
      _setStatus(QuickCaptureStatus.listening);
      debugPrint(
        '🎙️ QuickCapture listening via ${source.kind.name} '
        '(${source.language})',
      );
      return true;
    }

    _fail(
      QuickCaptureFailure.startFailed,
      detail: lastStartError ?? _unavailableDetail,
    );
    return false;
  }

  /// Dừng sạch: huỷ subscription trước (không nhận thêm kết quả), tắt
  /// engine, nhả recorder. Transcript được GIỮ để user lưu.
  Future<void> stop() async {
    if (_disposed) return;
    final source = _activeSource;
    if (_status == QuickCaptureStatus.idle && source == null) return;

    _setStatus(QuickCaptureStatus.stopping);

    await _subscription?.cancel();
    _subscription = null;
    _activeSource = null;
    if (source != null) {
      try {
        await source.stop();
      } catch (e) {
        debugPrint('⚠️ QuickCapture: stop error (${source.kind.name}): $e');
      }
    }
    if (_disposed) return;
    _setStatus(QuickCaptureStatus.idle);
  }

  /// Xoá transcript (giữ phiên đang chạy nếu có).
  void clearTranscript() {
    _finalSegments.clear();
    _partialText = '';
    _lastFinalText = '';
    _notify();
  }

  /// Nạp lại một nội dung có sẵn (vd: ghi chú nói đã lưu) vào transcript
  /// để user sửa/lưu tiếp. Không đụng phiên mic đang chạy.
  void restoreTranscript(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _finalSegments
      ..clear()
      ..add(normalized);
    _partialText = '';
    _lastFinalText = normalized;
    _notify();
  }

  /// Bỏ trạng thái lỗi để user thử lại.
  void acknowledgeFailure() {
    if (_failure == QuickCaptureFailure.none) return;
    _failure = QuickCaptureFailure.none;
    _failureDetail = null;
    if (_status == QuickCaptureStatus.error) {
      _status = QuickCaptureStatus.idle;
    }
    _notify();
  }

  // ── Internals ───────────────────────────────────────────────────────────

  void _onResult(SttResult result) {
    if (_disposed) return;
    final text = result.fullText.trim();
    if (text.isEmpty) return;

    if (result.isFinal) {
      // Một số engine phát lại cùng một câu final (native + VAD flush khi
      // dừng) → bỏ trùng để transcript không lặp.
      if (text == _lastFinalText) {
        _partialText = '';
        _notify();
        return;
      }
      _lastFinalText = text;
      _finalSegments.add(text);
      _partialText = '';
    } else {
      _partialText = text;
    }
    _notify();
  }

  Future<void> _stopSourceQuietly(QuickCaptureSttSource source) async {
    try {
      await source.stop();
    } catch (e) {
      debugPrint('⚠️ QuickCapture: cleanup error (${source.kind.name}): $e');
    }
    try {
      await source.release();
    } catch (e) {
      debugPrint('⚠️ QuickCapture: release error (${source.kind.name}): $e');
    }
  }

  void _fail(QuickCaptureFailure failure, {String? detail}) {
    _failure = failure;
    _failureDetail = detail;
    _activeSource = null;
    _setStatus(QuickCaptureStatus.error);
    debugPrint('❌ QuickCapture failed: ${failure.name} ${detail ?? ''}');
  }

  void _setStatus(QuickCaptureStatus next) {
    if (_status == next) return;
    _status = next;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // An toàn cuối: dù UI quên gọi [stop], mic không được chạy tiếp.
    // stop → release chạy TUẦN TỰ để không free recognizer khi engine
    // còn đang flush câu cuối.
    final subscription = _subscription;
    _subscription = null;
    final source = _activeSource;
    _activeSource = null;

    unawaited(subscription?.cancel());
    if (source != null) {
      unawaited(_stopSourceQuietly(source));
    }
    super.dispose();
  }
}
