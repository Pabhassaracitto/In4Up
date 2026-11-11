// lib/models/read_chrome_layout.dart
//
// READ-UI-120 — cấu hình mức NHÓM cho chrome tab Đọc (audit v1.20.0).
//
// Trước đây tab Đọc chỉ có một cờ nhị phân `_readerChromeVisible`: ẩn TOÀN BỘ
// chrome (kể cả nút phát) hoặc hiện TOÀN BỘ (6 hàng icon). Trên điện thoại nhỏ
// cả hai trạng thái đều tệ. Model này thay cơ chế đó bằng progressive
// disclosure: Nguồn luôn ở trên, Công cụ gộp 1 hàng ở đáy, Thông tin/Hiển thị
// là một icon cạnh nút ⚡; bung từng nhóm khi cần.
//
// Thuần Dart (không import Flutter) để test được bằng `flutter test` lẫn chạy
// trong CI không có widget tree. Xem docs/adr/0021-doc-tab-chrome-va-tts.md.

import 'dart:convert';

/// Trạng thái hiển thị của một nhóm chrome.
enum ReadChromeGroupState {
  /// Chỉ icon / 1 hàng — MẶC ĐỊNH.
  collapsed,

  /// Bung panel chi tiết inline (không phải modal toàn màn hình).
  expanded,

  /// Ẩn hẳn; vẫn gọi lại được qua FAB «Công cụ đọc» / nút ⚡.
  hidden,
}

/// Vị trí nhóm Công cụ. `bottom` là mặc định mới; `top` giữ hành vi cũ cho
/// người dùng đã quen (không phá thói quen khi upgrade).
enum ReadToolsPlacement { bottom, top }

/// Phạm vi của nút «Đọc» duy nhất trong dock.
enum ReadPlaybackScope {
  /// Đọc dòng hiện tại (`TextProvider.speakCurrentLine`, owner = preview).
  currentLine,

  /// Phát cả bài (`PlaybackController` + `PlaybackEngine`, có recipe/anchor).
  wholeDocument,
}

/// Panel đang mở trong dock (chỉ một panel tại một thời điểm).
enum ReadDockPanel { audio, tools, display }

/// Ba nhóm chrome của tab Đọc. Mỗi nhóm có key lưu riêng
/// `read_chrome_group_<id>_v1` (xem `StorageService.readChromeGroupKey`) và
/// khả năng ẩn riêng: Nguồn KHÔNG BAO GIỜ được ẩn, nếu không người dùng mất
/// đường vào nội dung (owner chốt giữ 2 icon web/tipitaka ở trên cùng).
enum ReadChromeGroupId { source, tools, display }

extension ReadChromeGroupIdX on ReadChromeGroupId {
  String get storageKey => 'read_chrome_group_${name}_v1';

  /// `allowHide`: chỉ nhóm Công cụ và Thông tin/Hiển thị cho phép trạng thái
  /// `hidden`; Nguồn là lối vào nội dung nên khoá cứng.
  bool get allowHide => this != ReadChromeGroupId.source;

  /// Nhãn nguồn (đi qua `context.uiText`, quy tắc vàng #5).
  String get label => switch (this) {
        ReadChromeGroupId.source => 'Nguồn',
        ReadChromeGroupId.tools => 'Công cụ đọc',
        ReadChromeGroupId.display => 'Thông tin & Hiển thị',
      };

  ReadChromeGroupState stateOf(ReadChromeLayout layout) => switch (this) {
        ReadChromeGroupId.source => layout.sourceState,
        ReadChromeGroupId.tools => layout.toolsState,
        ReadChromeGroupId.display => layout.displayState,
      };

  ReadChromeLayout withState(
    ReadChromeLayout layout,
    ReadChromeGroupState state,
  ) {
    // Khoá cứng: dù dữ liệu cũ/hỏng có ghi `hidden` cho Nguồn, luôn ép về
    // `collapsed` thay vì làm mất source picker.
    final safe = (!allowHide && state == ReadChromeGroupState.hidden)
        ? ReadChromeGroupState.collapsed
        : state;
    return switch (this) {
      ReadChromeGroupId.source => layout.copyWith(sourceState: safe),
      ReadChromeGroupId.tools => layout.copyWith(toolsState: safe),
      ReadChromeGroupId.display => layout.copyWith(displayState: safe),
    };
  }
}

T readEnumFromName<T>(
  List<T> values,
  Object? name,
  T fallback, {
  required String Function(T) nameOf,
}) {
  if (name is String) {
    for (final value in values) {
      if (nameOf(value) == name) return value;
    }
  }
  return fallback;
}

bool _boolFrom(Object? value, bool fallback) =>
    value is bool ? value : fallback;

class ReadChromeLayout {
  const ReadChromeLayout({
    this.sourceState = ReadChromeGroupState.collapsed,
    this.toolsState = ReadChromeGroupState.collapsed,
    this.displayState = ReadChromeGroupState.collapsed,
    this.toolsPlacement = ReadToolsPlacement.bottom,
    this.rememberExpanded = true,
    this.autoTranslateOnBilingual = true,
    this.playbackScope = ReadPlaybackScope.wholeDocument,
    this.lastPanel = ReadDockPanel.audio,
  });

  /// Mặc định cho máy mới: tối giản, KHÔNG bắt dịch trước khi phát.
  static const ReadChromeLayout defaults = ReadChromeLayout();

  final ReadChromeGroupState sourceState;
  final ReadChromeGroupState toolsState;
  final ReadChromeGroupState displayState;
  final ReadToolsPlacement toolsPlacement;

  /// Ghi nhớ trạng thái bung/gộp giữa các lần mở tab.
  final bool rememberExpanded;

  /// Khi phát song ngữ mà chưa có bản dịch: tự dịch nền (KHÔNG chặn nút
  /// Play). Tắt để tôn trọng offline / dữ liệu / chi phí API.
  final bool autoTranslateOnBilingual;

  final ReadPlaybackScope playbackScope;
  final ReadDockPanel lastPanel;

  bool get useBottomDock => toolsPlacement == ReadToolsPlacement.bottom;
  bool get sourceExpanded =>
      sourceState == ReadChromeGroupState.expanded;
  bool get toolsExpanded => toolsState == ReadChromeGroupState.expanded;
  bool get toolsHidden => toolsState == ReadChromeGroupState.hidden;
  bool get displayHidden => displayState == ReadChromeGroupState.hidden;
  bool get displayExpanded => displayState == ReadChromeGroupState.expanded;
  bool get readsWholeDocument =>
      playbackScope == ReadPlaybackScope.wholeDocument;

  /// Dock đáy LUÔN có 1 hàng (kể cả khi cuộn) — khác với chrome phía trên
  /// vốn chịu smart-hide. Đây là điểm mấu chốt của audit: đừng để nút phát
  /// biến mất khi người dùng cuộn chữ.
  bool get dockAlwaysVisible => useBottomDock && !toolsHidden;

  ReadChromeLayout copyWith({
    ReadChromeGroupState? sourceState,
    ReadChromeGroupState? toolsState,
    ReadChromeGroupState? displayState,
    ReadToolsPlacement? toolsPlacement,
    bool? rememberExpanded,
    bool? autoTranslateOnBilingual,
    ReadPlaybackScope? playbackScope,
    ReadDockPanel? lastPanel,
  }) =>
      ReadChromeLayout(
        sourceState: sourceState ?? this.sourceState,
        toolsState: toolsState ?? this.toolsState,
        displayState: displayState ?? this.displayState,
        toolsPlacement: toolsPlacement ?? this.toolsPlacement,
        rememberExpanded: rememberExpanded ?? this.rememberExpanded,
        autoTranslateOnBilingual:
            autoTranslateOnBilingual ?? this.autoTranslateOnBilingual,
        playbackScope: playbackScope ?? this.playbackScope,
        lastPanel: lastPanel ?? this.lastPanel,
      );

  /// Trạng thái "đóng" khi người dùng thu gọn panel: nếu không ghi nhớ thì
  /// luôn về `collapsed`, nếu ghi nhớ thì giữ panel đã chọn cho lần sau.
  ReadChromeLayout collapsedTools({
    required ReadDockPanel panel,
    bool open = false,
  }) {
    final nextPanel = rememberExpanded ? panel : ReadDockPanel.audio;
    return copyWith(
      toolsState: open
          ? ReadChromeGroupState.expanded
          : ReadChromeGroupState.collapsed,
      lastPanel: nextPanel,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'sourceState': sourceState.name,
        'toolsState': toolsState.name,
        'displayState': displayState.name,
        'toolsPlacement': toolsPlacement.name,
        'rememberExpanded': rememberExpanded,
        'autoTranslateOnBilingual': autoTranslateOnBilingual,
        'playbackScope': playbackScope.name,
        'lastPanel': lastPanel.name,
      };

  factory ReadChromeLayout.fromJson(Map<String, Object?> json) {
    final layout = ReadChromeLayout(
      sourceState: readEnumFromName(
        ReadChromeGroupState.values,
        json['sourceState'],
        ReadChromeGroupState.collapsed,
        nameOf: (v) => v.name,
      ),
      toolsState: readEnumFromName(
        ReadChromeGroupState.values,
        json['toolsState'],
        ReadChromeGroupState.collapsed,
        nameOf: (v) => v.name,
      ),
      displayState: readEnumFromName(
        ReadChromeGroupState.values,
        json['displayState'],
        ReadChromeGroupState.collapsed,
        nameOf: (v) => v.name,
      ),
      toolsPlacement: readEnumFromName(
        ReadToolsPlacement.values,
        json['toolsPlacement'],
        ReadToolsPlacement.bottom,
        nameOf: (v) => v.name,
      ),
      rememberExpanded: _boolFrom(json['rememberExpanded'], true),
      autoTranslateOnBilingual:
          _boolFrom(json['autoTranslateOnBilingual'], true),
      playbackScope: readEnumFromName(
        ReadPlaybackScope.values,
        json['playbackScope'],
        ReadPlaybackScope.wholeDocument,
        nameOf: (v) => v.name,
      ),
      lastPanel: readEnumFromName(
        ReadDockPanel.values,
        json['lastPanel'],
        ReadDockPanel.audio,
        nameOf: (v) => v.name,
      ),
    );
    // Nguồn không bao giờ được ẩn (allowHide = false).
    return ReadChromeGroupId.source.withState(layout, layout.sourceState);
  }

  String encode() => jsonEncode(toJson());

  /// Giải mã an toàn: dữ liệu cũ/hỏng không bao giờ làm crash màn Đọc.
  static ReadChromeLayout decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ReadChromeLayout.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Fallback cố ý: preference hỏng ⇒ về mặc định tối giản.
    }
    return defaults;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadChromeLayout &&
      other.sourceState == sourceState &&
      other.toolsState == toolsState &&
      other.displayState == displayState &&
      other.toolsPlacement == toolsPlacement &&
      other.rememberExpanded == rememberExpanded &&
      other.autoTranslateOnBilingual == autoTranslateOnBilingual &&
      other.playbackScope == playbackScope &&
      other.lastPanel == lastPanel;

  @override
  int get hashCode => Object.hash(
        sourceState,
        toolsState,
        displayState,
        toolsPlacement,
        rememberExpanded,
        autoTranslateOnBilingual,
        playbackScope,
        lastPanel,
      );
}
