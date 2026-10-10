import 'package:flutter/foundation.dart';

import '../models/c27_cabin_live_state.dart';
import '../models/cabin_caption.dart';
import '../models/cabin_session.dart';

/// C-27 Cabin Live — flow/controller (doc 42 + doc 43).
///
/// Điều phối state machine (`C27CabinLiveStateMachine`), caption 3 giai đoạn,
/// Handoff Drawer và session cache snapshot. Thuần logic + ChangeNotifier —
/// không widget, không IO (cache thật do `CabinSessionStore` đảm nhận ở UI).
///
/// Dòng chảy: Nghe → Cabin Live → Hiểu → Nhớ → quay lại Cabin Live (returnPath).
class C27CabinLiveController extends ChangeNotifier {
  C27CabinLiveController({String Function()? sessionIdFactory})
      : _sessionIdFactory =
            sessionIdFactory ?? _defaultSessionIdFactory;

  static String _defaultSessionIdFactory() =>
      'c27-${DateTime.now().millisecondsSinceEpoch}';

  final String Function() _sessionIdFactory;

  /// State machine chính tắc (14 state).
  final C27CabinLiveStateMachine machine = C27CabinLiveStateMachine();

  /// Transcript theo thứ tự thời gian (partial/final/translated).
  final List<CabinCaption> captions = [];

  /// Handoff đang mở (khi ở state `handoffActive`).
  C27Handoff? activeHandoff;

  /// Snapshot của lần save/discard gần nhất (để test/cache kiểm chứng).
  C27SessionSnapshot? lastSnapshot;

  /// `true` sau khi discard — phiên hiện tại coi như bỏ, không còn dữ liệu.
  bool discarded = false;

  String _sessionTitle = '';
  String _sourceLang = 'vi';
  String _targetLang = 'en';
  String _engine = '';
  Duration _elapsed = Duration.zero;

  /// Đường quay lại Cabin Live — cố định trong chuỗi Nghe → Cabin → Hiểu → Nhớ
  /// (bất biến #6, doc 43 §4). Mặc định 'cabin' (từ Nghe vào Cabin).
  String returnPath = 'cabin';

  /// State hiện tại (tiện cho UI).
  C27CabinLiveState get state => machine.state;

  /// Bắt đầu phiên từ workspace Nghe.
  void startFromListen({
    String sessionTitle = '',
    String sourceLang = 'vi',
    String targetLang = 'en',
    String engine = '',
  }) {
    _sessionTitle = sessionTitle;
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    _engine = engine;
    _elapsed = Duration.zero;
    discarded = false;
    lastSnapshot = null;
    captions.clear();
    activeHandoff = null;
    machine.sessionId = _sessionIdFactory();
    machine.transition(C27CabinEvent.startRequested);
    machine.transition(C27CabinEvent.permissionsGranted);
    machine.transition(C27CabinEvent.engineConnect);
    machine.transition(C27CabinEvent.engineConnected);
    notifyListeners();
  }

  /// Cấp quyền thủ công (UI đã xin xong).
  void grantPermissions() {
    machine.transition(C27CabinEvent.permissionsGranted);
    notifyListeners();
  }

  /// Từ chối quyền.
  void denyPermissions() {
    machine.transition(C27CabinEvent.permissionsDenied);
    notifyListeners();
  }

  /// Kết nối engine thành công / thất bại.
  void engineConnected() {
    machine.transition(C27CabinEvent.engineConnected);
    notifyListeners();
  }

  void engineConnectFailed() {
    machine.transition(C27CabinEvent.engineConnectFailed);
    notifyListeners();
  }

  /// Engine lỗi vĩnh viễn (service unavailable / hết quota).
  void serviceUnavailable() {
    machine.transition(C27CabinEvent.serviceUnavailable);
    notifyListeners();
  }

  /// Caption tạm (STT interim) — cùng id cập nhật text, không tạo entry mới.
  void onPartialCaption(CabinCaption caption) {
    machine.transition(C27CabinEvent.partialCaption);
    _upsert(caption);
    notifyListeners();
  }

  /// Caption nguồn đã chốt.
  void onFinalCaption(CabinCaption caption) {
    machine.transition(C27CabinEvent.finalCaption);
    _upsert(caption);
    notifyListeners();
  }

  /// Bản dịch cho caption đã chốt (cùng id với final).
  void onTranslatedCaption(String captionId, String translatedText) {
    machine.transition(C27CabinEvent.translatedCaption);
    final existing = _find(captionId);
    if (existing != null) {
      _upsert(existing.copyWith(translatedText: translatedText));
    }
    notifyListeners();
  }

  /// Phát lại âm thanh gốc trong phiên.
  void startPlayback() {
    machine.transition(C27CabinEvent.playbackStarted);
    notifyListeners();
  }

  void endPlayback() {
    machine.transition(C27CabinEvent.playbackEnded);
    notifyListeners();
  }

  void pause() {
    machine.transition(C27CabinEvent.pause);
    notifyListeners();
  }

  void resume() {
    machine.transition(C27CabinEvent.resume);
    notifyListeners();
  }

  void connectionLost() {
    machine.transition(C27CabinEvent.connectionLost);
    notifyListeners();
  }

  void reconnected() {
    machine.transition(C27CabinEvent.reconnected);
    notifyListeners();
  }

  void reconnectFailed() {
    machine.transition(C27CabinEvent.reconnectFailed);
    notifyListeners();
  }

  void networkLost() {
    machine.transition(C27CabinEvent.networkLost);
    notifyListeners();
  }

  void networkRestored() {
    machine.transition(C27CabinEvent.networkRestored);
    notifyListeners();
  }

  /// Mở Handoff Drawer — chọn caption để chuyển ngữ cảnh sang Hiểu/Nhớ.
  ///
  /// `target` là workspace đích; `sourceType` trong schema luôn là `cabin`
  /// (nguồn của handoff này là phiên Cabin). `returnPath` giữ nguyên (bất biến #6).
  void openHandoff({
    required C27SourceType target,
    String? captionId,
    String speakerTag = '',
  }) {
    final caption = captionId == null ? _latestTranslated() : _find(captionId);
    final resolved = caption ?? _latestTranslated();
    activeHandoff = C27Handoff(
      sourceType: C27SourceType.cabin,
      sessionId: machine.sessionId ?? '',
      timestamp: DateTime.now(),
      originalCaption: resolved?.sourceText ?? '',
      translatedCaption: resolved?.translatedText ?? '',
      sourceLanguage: _sourceLang,
      targetLanguage: _targetLang,
      speakerTag: speakerTag,
      sessionTitle: _sessionTitle,
      returnPath: returnPath,
    );
    machine.transition(C27CabinEvent.handoffOpened);
    notifyListeners();
  }

  /// Đóng Handoff Drawer — về đúng state trước đó (listening hoặc paused).
  void closeHandoff() {
    machine.transition(C27CabinEvent.handoffClosed);
    activeHandoff = null;
    notifyListeners();
  }

  /// Kết thúc phiên. `save = true` ⇒ lưu nháp (snapshot chỉ final/translated);
  /// `save = false` ⇒ bỏ nháp.
  void endSession({required bool save}) {
    machine.transition(C27CabinEvent.endRequested);
    if (save) {
      lastSnapshot = _buildSnapshot(saved: true);
      machine.transition(C27CabinEvent.saveDraft);
    } else {
      discarded = true;
      lastSnapshot = null;
      machine.transition(C27CabinEvent.discardDraft);
    }
    notifyListeners();
  }

  /// Xoá phiên đã lưu để bắt đầu phiên mới.
  void reset() {
    machine.transition(C27CabinEvent.reset);
    captions.clear();
    activeHandoff = null;
    lastSnapshot = null;
    discarded = false;
    notifyListeners();
  }

  /// Bỏ qua lỗi (giữ session để còn save draft).
  void dismissError() {
    machine.transition(C27CabinEvent.dismissError);
    notifyListeners();
  }

  /// Khôi phục phiên bị ngắt (app tắt lúc đang ghi).
  void loadRecovered({required String sessionId, String sessionTitle = ''}) {
    machine.sessionId = sessionId;
    _sessionTitle = sessionTitle;
    machine.transition(C27CabinEvent.recoveryLoaded);
    notifyListeners();
  }

  /// Đường quay lại Cabin Live từ chuỗi Hiểu/Nhớ (theo returnPath).
  String returnToCabinPath() => activeHandoff?.returnPath ?? returnPath;

  /// Caption mới nhất đã có bản dịch (ưu tiên cho handoff).
  CabinCaption? get latestTranslated => _latestTranslated();

  void _upsert(CabinCaption caption) {
    final index = captions.indexWhere((c) => c.id == caption.id);
    if (index >= 0) {
      captions[index] = caption;
    } else {
      captions.add(caption);
    }
  }

  CabinCaption? _find(String id) {
    for (final c in captions) {
      if (c.id == id) return c;
    }
    return null;
  }

  CabinCaption? _latestTranslated() {
    for (var i = captions.length - 1; i >= 0; i--) {
      if (stageOfCabinCaption(captions[i]) == C27CaptionStage.translated) {
        return captions[i];
      }
    }
    return captions.isEmpty ? null : captions.last;
  }

  C27SessionSnapshot _buildSnapshot({required bool saved}) {
    final entries = <CabinTranscriptEntry>[];
    // Offset tính từ caption đầu tiên của phiên (mốc bắt đầu phiên).
    final base = captions.isEmpty ? null : captions.first.timestamp;
    for (final caption in captions) {
      final stage = stageOfCabinCaption(caption);
      if (stage == C27CaptionStage.partial) continue; // bất biến #8
      final offset = base == null
          ? Duration.zero
          : caption.timestamp.difference(base);
      entries.add(CabinTranscriptEntry(
        offset: offset,
        sourceText: caption.sourceText,
        translatedText: caption.translatedText,
      ));
    }
    return C27SessionSnapshot(
      sessionId: machine.sessionId ?? '',
      title: _sessionTitle,
      sourceLang: _sourceLang,
      targetLang: _targetLang,
      engine: _engine,
      entries: entries,
      saved: saved,
    );
  }

  /// Tiêu đề phiên (đọc cho UI).
  String get sessionTitle => _sessionTitle;

  /// Thời lượng ước tính của phiên (tính tới caption cuối).
  Duration get elapsed => _elapsed;
}
