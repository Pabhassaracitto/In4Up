// lib/features/translation/mlkit_pack_downloads.dart
//
// PSRC-188 (owner 2026-11-11) — *"cho tải gói dịch offline tiếp tục khi đóng
// popup"*.
//
// Triệu chứng: bấm "Tải về" trong sheet "Engine dịch thuật" rồi ĐÓNG sheet ⇒
// gói dừng/không ai theo dõi. Mở lại sheet thì thấy nút "Tải về" như chưa từng
// tải (hoặc tệ hơn: model đang tải dở ở tầng native mà UI không biết) ⇒ user
// tưởng hỏng, bấm lại nhiều lần.
//
// Nguyên nhân: trạng thái `_downloading` / `_modelDownloaded` nằm trong
// `_TranslationEngineSettingsSheetState` — chết cùng sheet:
//   • `downloadModel()` là future gắn với State; đóng sheet ⇒ State dispose,
//     `mounted == false` ⇒ mất mọi cập nhật trạng thái.
//   • Mở lại sheet ⇒ `_loadModels()` đọc `isModelDownloaded()` = false (model
//     chưa tải xong) ⇒ hiện "Chưa tải" + nút "Tải về" ⇒ không có dấu hiệu nào
//     cho biết vẫn đang chạy ngầm.
//
// Cách sửa (một chỗ duy nhất, test được trên host VM): registry sống theo
// process, do **TranslationService** giữ (singleton sống suốt app, KHÔNG phải
// widget). Sheet chỉ *quan sát* registry. Luồng tải do registry sở hữu nên
// đóng sheet không huỷ gì cả.
//
// Luật phiên vẫn giữ nguyên: KHÔNG tự tải lúc bootstrap / ensureModel /
// mở sheet — chỉ tải khi user bấm. Registry này chỉ *theo dõi* một lượt tải
// do người dùng khởi động.
//
// Test: `test/translation/mlkit_pack_downloads_test.dart` (thuần Dart, inject
// hàm tải giả — không cần plugin/native).

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Trạng thái một gói ML Kit mà UI cần biết.
enum MlKitPackState {
  /// Chưa có gói, cũng không có lượt tải nào đang chạy.
  missing,

  /// Đang tải (do user bấm ở sheet — có thể sheet đã đóng).
  downloading,

  /// Đã tải xong, dùng được.
  ready,

  /// Lượt tải gần nhất THẤT BẠI (mất mạng, native từ chối...). User bấm lại
  /// được; trạng thái này KHÔNG tự chuyển về `missing` để UI báo được lý do
  /// trong một phiên xem.
  failed,
}

/// Một gói trong registry: trạng thái + lý do lỗi (nếu có).
@immutable
class MlKitPackStatus {
  const MlKitPackStatus({
    required this.bcpCode,
    required this.state,
    this.error,
  });

  /// Mã BCP-47 của ML Kit (`'en'`, `'vi'`, `'hi'`, ...).
  final String bcpCode;
  final MlKitPackState state;

  /// Lý do thất bại (chỉ có khi [state] == [MlKitPackState.failed]).
  final String? error;

  bool get isDownloading => state == MlKitPackState.downloading;
  bool get isReady => state == MlKitPackState.ready;
  bool get hasFailed => state == MlKitPackState.failed;

  MlKitPackStatus copyWith({
    MlKitPackState? state,
    String? error,
    bool clearError = false,
  }) {
    return MlKitPackStatus(
      bcpCode: bcpCode,
      state: state ?? this.state,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() => 'MlKitPackStatus($bcpCode, ${state.name}'
      '${error == null ? '' : ', $error'})';
}

/// Sổ theo dõi tải gói ML Kit — SỐNG NGOÀI WIDGET TREE.
///
/// Không tự quyết định tải gì: mọi lượt tải đều bắt đầu từ [start] sau một
/// cú bấm của user. Registry chỉ lo (a) giữ future tải không phụ thuộc sheet,
/// (b) phát trạng thái cho mọi nơi đang xem (kể cả mở lại sheet sau này),
/// (c) hỏi lại trạng thái THẬT của máy khi được yêu cầu ([refresh]).
class MlKitPackDownloads extends ChangeNotifier {
  MlKitPackDownloads({
    required Future<bool> Function(String bcpCode) download,
    required Future<bool> Function(String bcpCode) isDownloaded,
    required bool Function() platformSupported,
  })  : _download = download,
        _isDownloaded = isDownloaded,
        _platformSupported = platformSupported;

  /// Hàm tải thật (`MlKitEngine.downloadModel`).
  final Future<bool> Function(String bcpCode) _download;

  /// Hàm đọc trạng thái thật (`MlKitEngine.isModelDownloaded`).
  final Future<bool> Function(String bcpCode) _isDownloaded;

  /// `MlKitEngine.platformSupported` — máy không hỗ trợ thì không tải gì.
  final bool Function() _platformSupported;

  final Map<String, MlKitPackStatus> _status = <String, MlKitPackStatus>{};
  final Map<String, Future<MlKitPackStatus>> _inFlight =
      <String, Future<MlKitPackStatus>>{};

  /// Toàn bộ trạng thái đã biết (chỉ đọc — dùng cho test/log).
  Map<String, MlKitPackStatus> get snapshot =>
      Map<String, MlKitPackStatus>.unmodifiable(_status);

  /// Số gói đang tải — dùng cho badge/toast "vẫn đang tải ngầm".
  int get downloadingCount =>
      _status.values.where((s) => s.isDownloading).length;

  /// Đang có lượt tải nào chạy không (kể cả khi đã đóng sheet).
  bool get hasActiveDownloads => downloadingCount > 0;

  MlKitPackStatus statusOf(String bcpCode) =>
      _status[bcpCode] ??
      MlKitPackStatus(bcpCode: bcpCode, state: MlKitPackState.missing);

  /// Đọc lại trạng thái THẬT của từng gói.
  ///
  /// Gói đang tải thì KHÔNG ghi đè (nếu không, mở lại sheet giữa chừng sẽ
  /// thấy "Chưa tải" và user bấm tải lần nữa). Gói đã xong thì cập nhật
  /// `ready` để hàng UI khớp máy (PSRC-182).
  Future<void> refresh(Iterable<String> bcpCodes) async {
    if (!_platformSupported()) {
      for (final code in bcpCodes) {
        _put(MlKitPackStatus(bcpCode: code, state: MlKitPackState.missing));
      }
      return;
    }
    for (final code in bcpCodes) {
      if (_inFlight.containsKey(code)) continue;
      bool downloaded;
      try {
        downloaded = await _isDownloaded(code);
      } catch (_) {
        downloaded = false;
      }
      final current = _status[code];
      // Đừng xoá cờ THẤT BẠI ngay sau lượt tải vừa lỗi (UI cần báo lý do);
      // nhưng nếu máy báo đã có gói thì `ready` luôn đúng.
      if (downloaded) {
        _put(MlKitPackStatus(bcpCode: code, state: MlKitPackState.ready));
        continue;
      }
      // Máy báo CHƯA có: giữ nguyên cờ THẤT BẠI của lượt vừa rồi (UI còn lý
      // do để báo), mọi trạng thái khác ⇒ `missing` (bấm tải lại được).
      if (current != null && current.hasFailed) continue;
      _put(MlKitPackStatus(bcpCode: code, state: MlKitPackState.missing));
    }
  }

  /// Bắt đầu tải [bcpCode]. Trả về trạng thái CUỐI của lượt tải.
  ///
  /// • Gọi lại khi đang tải ⇒ trả về chính future đang chạy (KHÔNG tải 2 lần,
  ///   không ném lỗi) — nhờ vậy bấm lại sau khi mở lại sheet là vô hại.
  /// • Gói đã có ⇒ trả `ready` ngay, không gọi native.
  /// • Lượt tải KHÔNG bị huỷ khi sheet đóng: future do registry giữ.
  Future<MlKitPackStatus> start(String bcpCode) {
    final running = _inFlight[bcpCode];
    if (running != null) return running;
    if (!_platformSupported()) {
      return Future<MlKitPackStatus>.value(
        _fail(bcpCode, 'ML Kit chỉ chạy trên Android/iOS'),
      );
    }
    if (_status[bcpCode]?.isReady ?? false) {
      return Future<MlKitPackStatus>.value(_status[bcpCode]!);
    }
    // Đặt `downloading` NGAY, đồng bộ — trước khi chờ platform channel. Nếu
    // để `_run` làm (sau `isDownloaded`), hàng UI còn hiện "Tải về" thêm một
    // nhịp và user dễ bấm lại.
    _put(MlKitPackStatus(bcpCode: bcpCode, state: MlKitPackState.downloading));
    final future = _run(bcpCode);
    _inFlight[bcpCode] = future;
    // Dọn `_inFlight` khi xong — `unawaited` để không ai phải chờ dọn dẹp.
    unawaited(future.whenComplete(() => _inFlight.remove(bcpCode)));
    return future;
  }

  Future<MlKitPackStatus> _run(String bcpCode) async {
    if (!_platformSupported()) {
      return _fail(bcpCode, 'ML Kit chỉ chạy trên Android/iOS');
    }
    // Đã có sẵn (user vừa tải xong ở phiên trước / gói cài theo máy): không
    // gọi native lần nữa, nhưng ĐÁNH DẤU ready để hàng UI đúng ngay.
    bool alreadyThere;
    try {
      alreadyThere = await _isDownloaded(bcpCode);
    } catch (_) {
      alreadyThere = false;
    }
    if (alreadyThere) {
      return _put(MlKitPackStatus(bcpCode: bcpCode, state: MlKitPackState.ready));
    }

    try {
      final ok = await _download(bcpCode);
      // PSRC-182: đừng tin tuyệt đối giá trị trả về — `downloadModel()` có
      // thể trả `false` khi gói ĐÃ có sẵn. Hỏi lại trạng thái THẬT.
      var downloaded = ok;
      if (!downloaded) {
        try {
          downloaded = await _isDownloaded(bcpCode);
        } catch (_) {
          downloaded = false;
        }
      }
      return downloaded
          ? _put(MlKitPackStatus(
              bcpCode: bcpCode, state: MlKitPackState.ready))
          : _fail(bcpCode, null);
    } catch (e) {
      return _fail(bcpCode, e.toString());
    }
  }

  /// Xoá gói (user bấm thùng rác) rồi ghi lại trạng thái THẬT.
  Future<MlKitPackStatus> removed(
    String bcpCode,
    Future<void> Function(String bcpCode) deleteModel,
  ) async {
    try {
      await deleteModel(bcpCode);
    } catch (_) {
      // Xoá lỗi ⇒ đọc lại trạng thái bên dưới, không đoán.
    }
    var stillThere = false;
    try {
      stillThere = await _isDownloaded(bcpCode);
    } catch (_) {
      stillThere = false;
    }
    return _put(MlKitPackStatus(
      bcpCode: bcpCode,
      state: stillThere ? MlKitPackState.ready : MlKitPackState.missing,
    ));
  }

  MlKitPackStatus _fail(String bcpCode, String? error) => _put(
        MlKitPackStatus(
          bcpCode: bcpCode,
          state: MlKitPackState.failed,
          error: error,
        ),
      );

  MlKitPackStatus _put(MlKitPackStatus status) {
    final previous = _status[status.bcpCode];
    _status[status.bcpCode] = status;
    // Chỉ notify khi THỰC SỰ đổi — `refresh()` gọi mỗi lần mở sheet, notify
    // vô điều kiện sẽ rebuild vô ích (và làm test khó đọc).
    if (previous == null ||
        previous.state != status.state ||
        previous.error != status.error) {
      notifyListeners();
    }
    return status;
  }
}
