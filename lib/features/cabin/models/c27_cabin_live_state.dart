import 'package:flutter/foundation.dart';

import 'cabin_caption.dart';
import 'cabin_session.dart';

/// C-27 Cabin Live — state contract v1 (xem docs/ux/43-c27-cabin-live-state-contract.vi.md).
///
/// Đây là nguồn chính tắc cho 14-state matrix của phiên Cabin Live (cross-workspace).
/// Machine thuần logic — không phụ thuộc widget, không IO; controller ở
/// `controllers/c27_cabin_live_controller.dart` điều phối.

/// 14 trạng thái của phiên Cabin Live (doc 42 §3, doc 43 §1).
enum C27CabinLiveState {
  /// Chưa có phiên; bubble ẩn.
  idle,

  /// Đang xin quyền micro (và overlay nếu bật bubble trên Android).
  permissionRequesting,

  /// Đủ quyền, sẵn sàng; chưa kết nối engine.
  ready,

  /// Đang kết nối engine STT/dịch.
  connecting,

  /// Đang thu âm; nhận partial captions.
  listening,

  /// Có final caption đang dịch.
  translating,

  /// Đang phát lại âm thanh gốc trong phiên.
  speaking,

  /// Tạm dừng: mic tắt, timer dừng, session giữ nguyên.
  paused,

  /// Mất kết nối engine; đang thử lại có backoff.
  reconnecting,

  /// Mất mạng; engine online không khả dụng.
  offline,

  /// Handoff Drawer đang mở; chuẩn bị chuyển ngữ cảnh.
  handoffActive,

  /// Đang kết thúc phiên; hỏi lưu nháp / bỏ.
  ending,

  /// Đã lưu vào local session cache.
  saved,

  /// Lỗi không tự phục hồi (service unavailable, quyền bị từ chối vĩnh viễn…).
  error,
}

/// Sự kiện dẫn chuyển state (doc 43 §2).
enum C27CabinEvent {
  startRequested,
  permissionsGranted,
  permissionsDenied,
  engineConnect,
  engineConnected,
  engineConnectFailed,
  partialCaption,
  finalCaption,
  translatedCaption,
  playbackStarted,
  playbackEnded,
  pause,
  resume,
  connectionLost,
  reconnected,
  reconnectFailed,
  networkLost,
  networkRestored,
  serviceUnavailable,
  handoffOpened,
  handoffClosed,
  endRequested,
  saveDraft,
  discardDraft,
  reset,
  dismissError,
  recoveryLoaded,
}

/// Machine 14 state — bảng chuyển chính tắc ở doc 43 §3.
///
/// Transition ngoài bảng ⇒ reject (trả `null`, state không đổi, không side effect).
class C27CabinLiveStateMachine {
  C27CabinLiveStateMachine({this.sessionId});

  /// Định danh phiên — ổn định từ `ready` tới `saved` (bất biến #2, doc 43 §4).
  String? sessionId;

  /// Số lượt kết nối lại thất bại liên tiếp (bất biến #4).
  int reconnectAttempts = 0;

  /// Tối đa 3 lượt trước khi xuống `offline`.
  static const int maxReconnectAttempts = 3;

  C27CabinLiveState _state = C27CabinLiveState.idle;

  /// State hiện tại (bất biến #1: luôn đúng một state, bắt đầu từ `idle`).
  C27CabinLiveState get state => _state;

  /// State trước khi mở Handoff Drawer (`listening` hoặc `paused`).
  C27CabinLiveState? get handoffOrigin => _handoffOrigin;
  C27CabinLiveState? _handoffOrigin;

  /// Event có hợp lệ ở state hiện tại không?
  bool canTransition(C27CabinEvent event) => _resolve(event) != null;

  /// Thực hiện chuyển state. Trả state mới nếu hợp lệ, `null` nếu reject.
  C27CabinLiveState? transition(C27CabinEvent event) {
    final target = _resolve(event);
    if (target == null) return null;
    if (event == C27CabinEvent.handoffOpened) {
      _handoffOrigin = _state;
    }
    if (event == C27CabinEvent.handoffClosed) {
      _handoffOrigin = null;
    }
    if (event == C27CabinEvent.engineConnectFailed ||
        event == C27CabinEvent.connectionLost) {
      reconnectAttempts++;
    }
    if (event == C27CabinEvent.reconnectFailed &&
        target == C27CabinLiveState.reconnecting) {
      reconnectAttempts++;
    }
    if (event == C27CabinEvent.engineConnected ||
        event == C27CabinEvent.reconnected) {
      reconnectAttempts = 0;
    }
    _state = target;
    return _state;
  }

  C27CabinLiveState? _resolve(C27CabinEvent event) {
    // handoffClosed về đúng state cũ (bất biến #5).
    if (event == C27CabinEvent.handoffClosed) {
      if (_state != C27CabinLiveState.handoffActive) return null;
      return _handoffOrigin ?? C27CabinLiveState.listening;
    }
    // reconnectFailed: quá 3 lượt thì xuống offline, trước đó ở lại reconnecting.
    if (event == C27CabinEvent.reconnectFailed) {
      if (_state != C27CabinLiveState.reconnecting) return null;
      return reconnectAttempts >= maxReconnectAttempts
          ? C27CabinLiveState.offline
          : C27CabinLiveState.reconnecting;
    }
    return _transitions[_state]?[event];
  }

  /// Bảng chuyển chính tắc (doc 43 §3, 48 dòng; self-loop = cập nhật dữ liệu).
  static const Map<C27CabinLiveState, Map<C27CabinEvent, C27CabinLiveState>>
      _transitions = {
    C27CabinLiveState.idle: {
      C27CabinEvent.startRequested: C27CabinLiveState.permissionRequesting,
      C27CabinEvent.recoveryLoaded: C27CabinLiveState.ready,
    },
    C27CabinLiveState.permissionRequesting: {
      C27CabinEvent.permissionsGranted: C27CabinLiveState.ready,
      C27CabinEvent.permissionsDenied: C27CabinLiveState.error,
    },
    C27CabinLiveState.ready: {
      C27CabinEvent.engineConnect: C27CabinLiveState.connecting,
      // Khôi phục phiên cũ rồi kết thúc ngay (để save draft / discard).
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.connecting: {
      C27CabinEvent.engineConnected: C27CabinLiveState.listening,
      C27CabinEvent.engineConnectFailed: C27CabinLiveState.reconnecting,
      C27CabinEvent.connectionLost: C27CabinLiveState.reconnecting,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
    },
    C27CabinLiveState.listening: {
      C27CabinEvent.partialCaption: C27CabinLiveState.listening,
      C27CabinEvent.finalCaption: C27CabinLiveState.translating,
      C27CabinEvent.playbackStarted: C27CabinLiveState.speaking,
      C27CabinEvent.pause: C27CabinLiveState.paused,
      C27CabinEvent.connectionLost: C27CabinLiveState.reconnecting,
      C27CabinEvent.networkLost: C27CabinLiveState.offline,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.handoffOpened: C27CabinLiveState.handoffActive,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.translating: {
      C27CabinEvent.translatedCaption: C27CabinLiveState.listening,
      C27CabinEvent.connectionLost: C27CabinLiveState.reconnecting,
      C27CabinEvent.networkLost: C27CabinLiveState.offline,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.speaking: {
      C27CabinEvent.playbackEnded: C27CabinLiveState.listening,
      C27CabinEvent.connectionLost: C27CabinLiveState.reconnecting,
      C27CabinEvent.networkLost: C27CabinLiveState.offline,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.paused: {
      C27CabinEvent.resume: C27CabinLiveState.listening,
      C27CabinEvent.networkLost: C27CabinLiveState.offline,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.handoffOpened: C27CabinLiveState.handoffActive,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.reconnecting: {
      C27CabinEvent.reconnected: C27CabinLiveState.listening,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.offline: {
      C27CabinEvent.networkRestored: C27CabinLiveState.connecting,
      C27CabinEvent.serviceUnavailable: C27CabinLiveState.error,
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.handoffActive: {
      C27CabinEvent.endRequested: C27CabinLiveState.ending,
    },
    C27CabinLiveState.ending: {
      C27CabinEvent.saveDraft: C27CabinLiveState.saved,
      C27CabinEvent.discardDraft: C27CabinLiveState.idle,
    },
    C27CabinLiveState.saved: {
      C27CabinEvent.reset: C27CabinLiveState.idle,
    },
    C27CabinLiveState.error: {
      C27CabinEvent.dismissError: C27CabinLiveState.idle,
    },
  };
}

/// Ba giai đoạn của một caption (doc 43 §5): partial → finalStage → translated.
/// (`final` là từ khóa của Dart nên tên enum phải là `finalStage`.)
enum C27CaptionStage { partial, finalStage, translated }

/// Suy stage từ `CabinCaption` hiện có (ánh xạ 1-1, không đổi dữ liệu).
C27CaptionStage stageOfCabinCaption(CabinCaption caption) {
  if (!caption.isFinal) return C27CaptionStage.partial;
  return caption.translatedText.isEmpty
      ? C27CaptionStage.finalStage
      : C27CaptionStage.translated;
}

/// Workspace nguồn của ngữ cảnh handoff (doc 43 §6).
enum C27SourceType { home, read, listen, understand, remember, cabin }

/// Source context handoff schema — đúng 10 trường bắt buộc (doc 43 §6).
@immutable
class C27Handoff {
  final C27SourceType sourceType;
  final String sessionId;
  final DateTime timestamp;
  final String originalCaption;
  final String translatedCaption;
  final String sourceLanguage;
  final String targetLanguage;
  final String speakerTag;
  final String sessionTitle;
  final String returnPath;

  const C27Handoff({
    required this.sourceType,
    required this.sessionId,
    required this.timestamp,
    required this.originalCaption,
    required this.translatedCaption,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.speakerTag = '',
    required this.sessionTitle,
    required this.returnPath,
  });

  /// Đúng 10 trường, đúng tên — máy bắt dựa vào đây (doc 43 §6).
  static const List<String> fieldNames = [
    'sourceType',
    'sessionId',
    'timestamp',
    'originalCaption',
    'translatedCaption',
    'sourceLanguage',
    'targetLanguage',
    'speakerTag',
    'sessionTitle',
    'returnPath',
  ];

  Map<String, dynamic> toJson() => {
        'sourceType': sourceType.name,
        'sessionId': sessionId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'originalCaption': originalCaption,
        'translatedCaption': translatedCaption,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'speakerTag': speakerTag,
        'sessionTitle': sessionTitle,
        'returnPath': returnPath,
      };

  factory C27Handoff.fromJson(Map<String, dynamic> json) => C27Handoff(
        sourceType: C27SourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => C27SourceType.cabin,
        ),
        sessionId: (json['sessionId'] as String?) ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num?)?.toInt() ?? 0,
        ),
        originalCaption: (json['originalCaption'] as String?) ?? '',
        translatedCaption: (json['translatedCaption'] as String?) ?? '',
        sourceLanguage: (json['sourceLanguage'] as String?) ?? '',
        targetLanguage: (json['targetLanguage'] as String?) ?? '',
        speakerTag: (json['speakerTag'] as String?) ?? '',
        sessionTitle: (json['sessionTitle'] as String?) ?? '',
        returnPath: (json['returnPath'] as String?) ?? '',
      );

  /// Validate theo hợp đồng: trả `null` nếu hợp lệ, trả chuỗi lỗi nếu không.
  /// Schema kín v1: đúng 10 trường, `speakerTag` được rỗng, còn lại không rỗng.
  static String? validateJson(Map<String, dynamic> json) {
    if (json.length != fieldNames.length) {
      return 'field count ${json.length} != ${fieldNames.length}';
    }
    for (final name in fieldNames) {
      if (!json.containsKey(name)) return 'missing field $name';
    }
    const nonEmpty = [
      'sourceType',
      'sessionId',
      'originalCaption',
      'translatedCaption',
      'sourceLanguage',
      'targetLanguage',
      'sessionTitle',
      'returnPath',
    ];
    for (final name in nonEmpty) {
      final value = json[name];
      if (value is! String || value.isEmpty) return 'empty field $name';
    }
    final timestamp = json['timestamp'];
    if (timestamp is! num || timestamp <= 0) return 'bad timestamp';
    final sourceType = json['sourceType'] as String;
    if (!C27SourceType.values.map((e) => e.name).contains(sourceType)) {
      return 'bad sourceType $sourceType';
    }
    final returnPath = json['returnPath'] as String;
    if (!RegExp(r'^[a-z0-9/-]+$').hasMatch(returnPath)) {
      return 'bad returnPath $returnPath';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is C27Handoff &&
          other.sourceType == sourceType &&
          other.sessionId == sessionId &&
          other.timestamp == timestamp &&
          other.originalCaption == originalCaption &&
          other.translatedCaption == translatedCaption &&
          other.sourceLanguage == sourceLanguage &&
          other.targetLanguage == targetLanguage &&
          other.speakerTag == speakerTag &&
          other.sessionTitle == sessionTitle &&
          other.returnPath == returnPath;

  @override
  int get hashCode => Object.hash(
        sourceType,
        sessionId,
        timestamp,
        originalCaption,
        translatedCaption,
        sourceLanguage,
        targetLanguage,
        speakerTag,
        sessionTitle,
        returnPath,
      );
}

/// Dữ liệu sẽ ghi vào local session cache (doc 43 §7).
///
/// Nhà cung cấp cache (ở đây là `CabinSessionStore`) tự lo IO; contract chỉ định
/// nội dung: chỉ caption ở stage `final`/`translated` (bất biến #8).
@immutable
class C27SessionSnapshot {
  final String sessionId;
  final String title;
  final String sourceLang;
  final String targetLang;
  final String engine;
  final List<CabinTranscriptEntry> entries;
  final bool saved;

  const C27SessionSnapshot({
    required this.sessionId,
    required this.title,
    required this.sourceLang,
    required this.targetLang,
    required this.engine,
    required this.entries,
    required this.saved,
  });
}
