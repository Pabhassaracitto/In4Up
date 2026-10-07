/// C-31 — STATE PRESERVATION QA
///
/// Bộ kiểm định 6 vùng bảo toàn trạng thái của UX shell (docs/ux/39 mục C-31):
///
/// ```text
/// C-31 — State preservation QA
///   source return      — handoff Đọc/Nghe/Xem → workspace khác giữ source
///   reading anchor     — mốc ngữ nghĩa khôi phục đúng, không highlight sai
///   draft              — nháp chưa lưu không bị sự kiện hệ thống xoá mất
///   playback           — đổi lớp hiển thị không đổi trạng thái phát
///   route return       — back/return đi đúng thứ tự lớp và trả đúng nguồn
///   offline event/conflict — log append-only, conflict không mất dữ liệu
/// ```
///
/// Cách dùng:
///
/// ```dart
/// final report = await const I4uStatePreservationQa().run();
/// report.isComplete;        // đủ 6 vùng + mọi kịch bản giữ đúng
/// report.toQualityRun();    // nối vào I4uQualityRun của UX freeze
/// print(report.toSummary()); // log cho QA tay / CI
/// ```
///
/// Nguyên tắc trung thực (C-31): harness chỉ nhận PASS cho thứ nó thật sự
/// chạy được. Vùng chưa có kịch bản ⇒ [I4uPreservationReport.uncoveredAreas]
/// khác rỗng ⇒ KHÔNG được coi là freeze-ready, thay vì pass rỗng. Việc phải
/// kết luận trên thiết bị thật nằm ở [kI4uPreservationManualChecks] và không
/// bao giờ tự động được tính là đạt.
///
/// File này thuần logic: không plugin, không mạng, không `BuildContext` —
/// chạy được bằng `flutter test` trên CI.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../knowledge/models/learning_state.dart' show SkillDimension;
import '../../knowledge/models/review_event.dart';
import '../../knowledge/review/review_event_store.dart';
import '../../models/audio_library_state.dart';
import '../../models/i4u_shell_contracts.dart';
import '../../models/mini_player_surface_state.dart';
import '../../models/reader_contextual_panel_state.dart';
import '../../models/reader_shell_state.dart';
import '../../models/remember_workspace_state.dart';
import '../../models/understand_workspace_state.dart';
import '../../models/watch_mode_state.dart';
import '../audio/audio_library_flow.dart';
import '../navigation/back_dismiss_coordinator.dart';
import '../reader/reader_contextual_flow.dart';
import '../reader/reader_note_contract.dart';
import '../reader/semantic_anchor_resolver.dart';
import '../remember/remember_flow.dart';
import '../understand/coach_flow.dart';
import '../watch/watch_mode_flow.dart';
import 'ux_quality_contract.dart';

/// Sáu vùng bảo toàn trạng thái bắt buộc của C-31.
enum I4uPreservationArea {
  sourceReturn,
  readingAnchor,
  draft,
  playback,
  routeReturn,
  offlineConflict,
}

extension I4uPreservationAreaInfo on I4uPreservationArea {
  /// Khoá ngắn dùng trong log/CI.
  String get slug => switch (this) {
        I4uPreservationArea.sourceReturn => 'source-return',
        I4uPreservationArea.readingAnchor => 'reading-anchor',
        I4uPreservationArea.draft => 'draft',
        I4uPreservationArea.playback => 'playback',
        I4uPreservationArea.routeReturn => 'route-return',
        I4uPreservationArea.offlineConflict => 'offline-conflict',
      };

  String get labelVi => switch (this) {
        I4uPreservationArea.sourceReturn => 'Giữ source context khi handoff',
        I4uPreservationArea.readingAnchor => 'Khôi phục mốc ngữ nghĩa, không highlight sai',
        I4uPreservationArea.draft => 'Nháp chưa lưu không bị xoá bởi sự kiện hệ thống',
        I4uPreservationArea.playback => 'Đổi lớp hiển thị không đổi trạng thái phát',
        I4uPreservationArea.routeReturn => 'Back/return đúng thứ tự lớp, trả đúng nguồn',
        I4uPreservationArea.offlineConflict => 'Log append-only, conflict không mất dữ liệu',
      };
}

/// Bất biến bị vi phạm ⇒ ném lỗi để harness ghi nhận là FAIL kèm lý do.
void i4uCheckHolds(bool condition, String message) {
  if (!condition) {
    throw StateError('[C-31] $message');
  }
}

typedef I4uPreservationScenarioBody = FutureOr<void> Function();

/// Một bất biến bảo toàn trạng thái, kiểm được bằng máy.
@immutable
class I4uPreservationScenario {
  const I4uPreservationScenario({
    required this.id,
    required this.area,
    required this.requirement,
    required this.body,
  });

  /// Mã kịch bản, ví dụ `C31-ANC-02`.
  final String id;
  final I4uPreservationArea area;

  /// Phát biểu bất biến — đọc lên là hiểu ngay QA đang giữ điều gì.
  final String requirement;

  final I4uPreservationScenarioBody body;
}

@immutable
class I4uPreservationCheckResult {
  const I4uPreservationCheckResult({
    required this.scenario,
    required this.passed,
    this.detail,
  });

  final I4uPreservationScenario scenario;
  final bool passed;
  final String? detail;

  bool get failed => !passed;
}

/// Kết quả một lượt chạy C-31.
@immutable
class I4uPreservationReport {
  const I4uPreservationReport({
    required this.results,
    this.manualChecks = kI4uPreservationManualChecks,
  });

  final List<I4uPreservationCheckResult> results;

  /// Việc chỉ kết luận được trên thiết bị thật — không tự động PASS.
  final Map<I4uPreservationArea, List<String>> manualChecks;

  Iterable<I4uPreservationCheckResult> get failures =>
      results.where((result) => result.failed);

  int get passedCount => results.where((result) => result.passed).length;

  /// Vùng C-31 không có kịch bản nào — thiếu máy bắt, không phải "đạt".
  List<I4uPreservationArea> get uncoveredAreas => <I4uPreservationArea>[
        for (final area in I4uPreservationArea.values)
          if (!results.any((result) => result.scenario.area == area)) area,
      ];

  int countFor(I4uPreservationArea area) =>
      results.where((result) => result.scenario.area == area).length;

  int failedCountFor(I4uPreservationArea area) =>
      results.where((result) => result.scenario.area == area && result.failed).length;

  bool get allHold => results.isNotEmpty && failures.isEmpty;

  /// Điều kiện để C-31 được coi là đóng: mọi kịch bản đạt VÀ đủ 6 vùng.
  bool get isComplete => allHold && uncoveredAreas.isEmpty;

  bool get _offlineAreaCovered =>
      countFor(I4uPreservationArea.offlineConflict) > 0;

  bool get offlineConflictHolds =>
      _offlineAreaCovered && failedCountFor(I4uPreservationArea.offlineConflict) == 0;

  /// Nối C-31 vào hợp đồng freeze dùng chung (C-30).
  I4uQualityRun toQualityRun() => I4uQualityRun(
        findings: <I4uQualityFinding>[
          I4uQualityFinding(
            check: I4uQualityCheck.statePreservation,
            status: isComplete ? I4uQualityStatus.pass : I4uQualityStatus.fail,
            details: '${passedCount}/${results.length} kịch bản đạt, '
                '${I4uPreservationArea.values.length - uncoveredAreas.length}/'
                '${I4uPreservationArea.values.length} vùng có máy bắt',
          ),
          I4uQualityFinding(
            check: I4uQualityCheck.offlineRecovery,
            status: offlineConflictHolds
                ? I4uQualityStatus.pass
                : I4uQualityStatus.fail,
            details: '${countFor(I4uPreservationArea.offlineConflict) - failedCountFor(I4uPreservationArea.offlineConflict)}/'
                '${countFor(I4uPreservationArea.offlineConflict)} kịch bản offline/conflict đạt',
          ),
        ],
      );

  /// Log dạng văn bản để dán vào QA tay hoặc đọc từ artifact CI.
  String toSummary() {
    final buffer = StringBuffer()
      ..writeln('C-31 state preservation — '
          '$passedCount/${results.length} kịch bản đạt, '
          '${I4uPreservationArea.values.length - uncoveredAreas.length}/'
          '${I4uPreservationArea.values.length} vùng có máy bắt');
    for (final area in I4uPreservationArea.values) {
      buffer.writeln('  ${area.slug.padRight(16)} '
          '${countFor(area) - failedCountFor(area)}/${countFor(area)} '
          '— ${area.labelVi}');
    }
    for (final failure in failures) {
      buffer.writeln('  FAIL ${failure.scenario.id} (${failure.scenario.area.slug}): '
          '${failure.detail ?? 'không rõ lỗi'}');
    }
    for (final area in uncoveredAreas) {
      buffer.writeln('  THIẾU MÁY BẮT ${area.slug}: ${area.labelVi}');
    }
    for (final entry in manualChecks.entries) {
      for (final step in entry.value) {
        buffer.writeln('  QA TAY ${entry.key.slug}: $step');
      }
    }
    return buffer.toString();
  }
}

/// Chạy bộ kịch bản C-31 (mặc định [kI4uPreservationScenarios]).
class I4uStatePreservationQa {
  const I4uStatePreservationQa({this.scenarios});

  /// Cho phép test bơm bộ kịch bản hẹp (âm tính) mà không đổi bộ chuẩn.
  final List<I4uPreservationScenario>? scenarios;

  List<I4uPreservationScenario> get effectiveScenarios =>
      scenarios ?? kI4uPreservationScenarios;

  Future<I4uPreservationReport> run() async {
    final results = <I4uPreservationCheckResult>[];
    for (final scenario in effectiveScenarios) {
      try {
        await scenario.body();
        results.add(I4uPreservationCheckResult(scenario: scenario, passed: true));
      } catch (error) {
        results.add(I4uPreservationCheckResult(
          scenario: scenario,
          passed: false,
          detail: '$error',
        ));
      }
    }
    return I4uPreservationReport(results: results);
  }
}

/// Việc QA tay trên thiết bị thật — harness KHÔNG tự nhận đạt.
const Map<I4uPreservationArea, List<String>> kI4uPreservationManualChecks =
    <I4uPreservationArea, List<String>>{
  I4uPreservationArea.sourceReturn: <String>[
    'Đọc → chọn đoạn → Hiểu → quay lại: đúng file, đúng trang/đoạn, đúng vị trí cuộn.',
    'Nghe/Xem → "Hiểu nội dung này" → quay lại nghe: audio vẫn đúng mốc thời gian.',
    'Xoay/khóa máy giữa handoff: quay lại không mất source context.',
  ],
  I4uPreservationArea.readingAnchor: <String>[
    'Mở lại tài liệu đã sửa ngoài app (revision đổi): KHÔNG highlight khi không đủ tin cậy.',
    'PDF re-flow/đổi cỡ chữ: mốc khôi phục lệch trong ngưỡng chấp nhận, không nhảy trang khác.',
    'Tài liệu bị xoá/di chuyển: hiện trạng thái nguồn không khả dụng thay vì màn hình trắng.',
  ],
  I4uPreservationArea.draft: <String>[
    'Đang gõ ghi chú → back/khoá app → mở lại: nháp còn nguyên, có chỉ báo đã lưu.',
    'Nguồn đổi revision khi đang gõ trả lời AI Coach: nháp không bị xoá, có băng "phiên cũ".',
    'Từ chối lưu nháp: hộp thoại xác nhận rõ, không mất im lặng.',
  ],
  I4uPreservationArea.playback: <String>[
    'Đang phát audio → mở Quick Actions/sheet lớn → audio KHÔNG dừng, không nhảy mốc.',
    'Đóng sheet lớn: Mini Player trở lại đúng trạng thái trước đó.',
    'Mở Expanded Player rồi đóng: trạng thái phát không đổi.',
    'Chuyển 5 workspace khi đang phát: audio tiếp tục, không restart từ đầu.',
  ],
  I4uPreservationArea.routeReturn: <String>[
    'Back từng lớp: overlay → panel → sheet → nháp → trả nguồn → lịch sử route → Home.',
    'Android back ở Home: thoát app, không nhảy tab lạ.',
    'Deep-link/tab switch giữa chừng rồi back: trả về đúng workspace gọi handoff.',
  ],
  I4uPreservationArea.offlineConflict: <String>[
    '2 thiết bị cùng ôn 1 thẻ trong 5 phút: event sau bị đánh dấu "không tính mastery" nhưng vẫn thấy trong log.',
    'Tắt mạng khi đang ôn: event xếp hàng, mở lại mạng không nhân đôi.',
    'Conflict ghi chú/vị trí đọc: hỏi người dùng, không tự ghi đè.',
  ],
};

ReviewEvent _event({
  required String id,
  required String unitId,
  required SkillDimension skill,
  required DateTime at,
  String device = 'device-a',
}) =>
    ReviewEvent(
      eventId: id,
      unitId: unitId,
      skill: skill,
      rating: SkillRating.good,
      timestamp: at,
      deviceId: device,
    );

Set<String> _ignoredIds(List<ReviewEvent> events) => <String>{
      for (final event in events)
        if (event.ignoredForMastery) event.eventId,
    };

/// Bộ kịch bản chuẩn của C-31 — mỗi vùng có máy bắt riêng.
final List<I4uPreservationScenario> kI4uPreservationScenarios =
    <I4uPreservationScenario>[
  // ── source return ──────────────────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-SRC-01',
    area: I4uPreservationArea.sourceReturn,
    requirement: 'Chọn đoạn → capability → quay lại vẫn giữ source/block/offset',
    body: () {
      final flow = I4uReaderContextualFlowController();
      const selection = I4uReaderSelectionContext(
        text: 'tri giác',
        sourceId: 'book-1',
        blockId: 'para_014',
        characterOffset: 128,
      );
      flow.select(selection);
      flow.run(I4uReaderContextAction.explain);
      flow.returnToReader();
      final returned = flow.value.selection;
      i4uCheckHolds(returned != null, 'selection bị mất khi quay lại reader');
      i4uCheckHolds(returned!.sourceId == 'book-1', 'sourceId đổi sau khi quay lại');
      i4uCheckHolds(returned.blockId == 'para_014', 'blockId đổi sau khi quay lại');
      i4uCheckHolds(returned.characterOffset == 128, 'characterOffset đổi sau khi quay lại');
      i4uCheckHolds(returned.text == 'tri giác', 'đoạn chọn bị đổi nội dung');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-SRC-02',
    area: I4uPreservationArea.sourceReturn,
    requirement: 'Source fingerprint serialize/khôi phục nguyên vẹn mọi trường handoff',
    body: () {
      final source = I4uSourceFingerprint(
        sourceType: I4uSourceType.pdf,
        sourceId: 'pdf-9',
        sourceRevision: 'md5-1',
        page: 18,
        timestampMs: 84000,
        selectedText: 'dukkha',
        locale: 'pi',
        returnPath: '/read/pdf-9?page=18',
        createdAt: DateTime.utc(2026, 10, 7, 9, 30),
      );
      final restored = I4uSourceFingerprint.fromJson(source.toJson());
      i4uCheckHolds(restored.sourceType == I4uSourceType.pdf, 'sourceType mất khi serialize');
      i4uCheckHolds(restored.sourceId == 'pdf-9', 'sourceId mất khi serialize');
      i4uCheckHolds(restored.sourceRevision == 'md5-1', 'sourceRevision mất khi serialize');
      i4uCheckHolds(restored.page == 18, 'page mất khi serialize');
      i4uCheckHolds(restored.timestampMs == 84000, 'timestampMs mất khi serialize');
      i4uCheckHolds(restored.selectedText == 'dukkha', 'selectedText mất khi serialize');
      i4uCheckHolds(restored.locale == 'pi', 'locale mất khi serialize');
      i4uCheckHolds(restored.returnPath == '/read/pdf-9?page=18', 'returnPath mất khi serialize');
      i4uCheckHolds(
        restored.createdAt?.isAtSameMomentAs(DateTime.utc(2026, 10, 7, 9, 30)) ?? false,
        'createdAt đổi mốc thời gian khi serialize',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-SRC-03',
    area: I4uPreservationArea.sourceReturn,
    requirement: 'Xem → Hiểu giữ nguồn + mốc thời gian + phụ đề đang chọn',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.video,
        sourceId: 'video-1',
        returnPath: '/listen/video-1',
      );
      final watch = I4uWatchModeFlowController();
      watch.ready(source: source, transcriptAvailable: true);
      watch.setSubtitleMode(I4uSubtitleMode.bilingual);
      watch.setTimestamp(84000);

      final handoff = watch.handoffToUnderstand(selectedSubtitle: 'dukkha');
      i4uCheckHolds(handoff != null, 'handoff sang Hiểu bị chặn dù nguồn đã ready');
      i4uCheckHolds(handoff!.timestampMs == 84000, 'mốc video mất khi handoff');
      i4uCheckHolds(handoff.selectedSubtitle == 'dukkha', 'phụ đề đang chọn mất khi handoff');
      i4uCheckHolds(handoff.source.sourceId == 'video-1', 'sourceId mất khi handoff');
      i4uCheckHolds(handoff.source.returnPath == '/listen/video-1', 'returnPath mất khi handoff');

      final coach = I4uCoachFlowController();
      coach.loadSource(handoff.source);
      i4uCheckHolds(coach.value.source?.sourceId == 'video-1', 'Hiểu không nhận được nguồn từ Xem');
      i4uCheckHolds(coach.value.canStart, 'Hiểu không bắt đầu được sau handoff');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-SRC-04',
    area: I4uPreservationArea.sourceReturn,
    requirement: 'Mở panel cài đặt chữ (aA) không làm mất nguồn/mốc đang đọc',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.document,
        sourceId: 'book-1',
        returnPath: '/read/book-1',
      );
      const anchor = I4uSemanticReadingAnchor(
        sourceId: 'book-1',
        blockId: 'para_014',
        characterOffset: 128,
      );
      const shell = I4uReaderShellState(
        source: source,
        anchor: anchor,
        panel: I4uReaderPanel.typography,
      );
      i4uCheckHolds(shell.canReturnToSource, 'source mất khi mở panel aA');
      i4uCheckHolds(shell.source?.sourceId == 'book-1', 'sourceId mất khi mở panel aA');
      i4uCheckHolds(shell.anchor?.blockId == 'para_014', 'mốc đọc mất khi mở panel aA');
      i4uCheckHolds(shell.loadState == I4uReaderLoadState.idle, 'panel đổi trạng thái tải');
    },
  ),

  I4uPreservationScenario(
    id: 'C31-SRC-05',
    area: I4uPreservationArea.sourceReturn,
    requirement: 'Nguồn đang ôn sống suốt phiên Nhớ (start → reveal → rate → thẻ kế → pause)',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.document,
        sourceId: 'book-1',
        returnPath: '/read/book-1',
      );
      final review = I4uRememberFlowController();
      review.loadSource(source);
      review.load(totalCount: 2);
      review.startReview('card-1');
      review.reveal();
      review.rate(I4uReviewRating.remembered);
      review.nextCard('card-2');
      review.pause();
      i4uCheckHolds(
        review.value.source?.sourceId == 'book-1',
        'nguồn đang ôn mất khi phiên Nhớ chuyển bước (rule vàng #3: không mở lại đúng nguồn)',
      );
      i4uCheckHolds(
        review.value.source?.returnPath == '/read/book-1',
        'returnPath mất khi phiên Nhớ chuyển bước',
      );
    },
  ),

  // ── reading anchor ─────────────────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-ANC-01',
    area: I4uPreservationArea.readingAnchor,
    requirement: 'Cùng revision + cùng block: khôi phục đúng offset, tin cậy tuyệt đối',
    body: () {
      const resolver = I4uSemanticAnchorResolver();
      final result = resolver.resolve(
        anchor: const I4uSemanticReadingAnchor(
          sourceId: 'book-1',
          sourceRevision: 'r1',
          blockId: 'para_014',
          characterOffset: 128,
        ),
        currentSourceId: 'book-1',
        currentRevision: 'r1',
        currentBlockId: 'para_014',
        text: 'A' * 400,
      );
      i4uCheckHolds(result != null, 'mốc hợp lệ không khôi phục được');
      i4uCheckHolds(result!.offset == 128, 'offset khôi phục sai');
      i4uCheckHolds(result.strategy == 'block-id', 'không dùng đường block-id khi đủ dữ kiện');
      i4uCheckHolds(result.confidence == 1.0, 'độ tin cậy không tuyệt đối khi block khớp');
      i4uCheckHolds(result.isReliable, 'kết quả bị coi là không tin cậy');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-ANC-02',
    area: I4uPreservationArea.readingAnchor,
    requirement: 'Revision đổi + không còn dấu vết văn bản: KHÔNG highlight sai (trả null)',
    body: () {
      const resolver = I4uSemanticAnchorResolver();
      final result = resolver.resolve(
        anchor: const I4uSemanticReadingAnchor(
          sourceId: 'book-1',
          sourceRevision: 'old',
          blockId: 'old-block',
          characterOffset: 400,
        ),
        currentSourceId: 'book-1',
        currentRevision: 'new',
        currentBlockId: 'new-block',
        text: 'Toàn bộ văn bản đã bị viết lại, không còn đoạn cũ.',
      );
      i4uCheckHolds(result == null, 'khôi phục khi không đủ tin cậy ⇒ highlight sai vị trí');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-ANC-03',
    area: I4uPreservationArea.readingAnchor,
    requirement: 'Revision đổi nhưng còn từ đã chọn: fallback sang tìm từ, tin cậy ≥ 0.8',
    body: () {
      const resolver = I4uSemanticAnchorResolver();
      const text = 'Một đoạn nói về tri giác trong văn bản mới.';
      final result = resolver.resolve(
        anchor: const I4uSemanticReadingAnchor(
          sourceId: 'book-1',
          sourceRevision: 'old',
          blockId: 'old-block',
          characterOffset: 0,
          selectedTerm: 'Tri giác',
        ),
        currentSourceId: 'book-1',
        currentRevision: 'new',
        currentBlockId: 'new-block',
        text: text,
      );
      i4uCheckHolds(result != null, 'còn từ đã chọn mà không tìm lại được');
      i4uCheckHolds(result!.strategy == 'selected-term', 'không dùng đường tìm từ đã chọn');
      i4uCheckHolds(
        result.offset == text.toLowerCase().indexOf('tri giác'),
        'offset trỏ sai chỗ so với từ đã chọn',
      );
      i4uCheckHolds(result.isReliable, 'fallback từ đã chọn bị coi là không tin cậy');
      i4uCheckHolds(result.confidence < 1.0, 'fallback phải thấp hơn khớp block-id');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-ANC-04',
    area: I4uPreservationArea.readingAnchor,
    requirement: 'Mốc thuộc nguồn khác hoặc văn bản rỗng: không rò sang nguồn hiện tại',
    body: () {
      const resolver = I4uSemanticAnchorResolver();
      const anchor = I4uSemanticReadingAnchor(
        sourceId: 'book-1',
        blockId: 'para_014',
        characterOffset: 128,
      );
      i4uCheckHolds(
        resolver.resolve(anchor: anchor, currentSourceId: 'book-2', text: 'A' * 400) == null,
        'mốc của nguồn khác bị áp lên nguồn đang đọc',
      );
      i4uCheckHolds(
        resolver.resolve(anchor: anchor, currentSourceId: 'book-1', text: '') == null,
        'khôi phục trên văn bản rỗng',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-ANC-05',
    area: I4uPreservationArea.readingAnchor,
    requirement: 'Offset vượt độ dài văn bản bị kẹp; dữ liệu cũ thiếu revision vẫn đọc được',
    body: () {
      const resolver = I4uSemanticAnchorResolver();
      const text = 'A' * 200;
      final loaded = I4uSemanticReadingAnchor.fromJson(<String, Object?>{
        'sourceId': 'book-1',
        'blockId': 'para_014',
        'characterOffset': 5000,
        'viewportRelativeRatio': 4,
      });
      i4uCheckHolds(loaded.sourceRevision == null, 'dữ liệu cũ bị đọc hỏng khi thiếu revision');
      i4uCheckHolds(loaded.viewportRelativeRatio == 1.0, 'tỉ lệ viewport không bị kẹp về [0,1]');

      final result = resolver.resolve(
        anchor: loaded,
        currentSourceId: 'book-1',
        currentBlockId: 'para_014',
        text: text,
      );
      i4uCheckHolds(result != null, 'mốc thiếu revision nhưng cùng block không khôi phục được');
      i4uCheckHolds(
        result!.offset == text.length,
        'offset vượt độ dài văn bản không bị kẹp vào cuối văn bản',
      );
    },
  ),

  // ── draft ──────────────────────────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-DFT-01',
    area: I4uPreservationArea.draft,
    requirement: 'Nháp trả lời AI Coach sống qua gợi ý, submit và feedback',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.document,
        sourceId: 'book-1',
        returnPath: '/read/book-1',
      );
      final coach = I4uCoachFlowController();
      coach.loadSource(source);
      coach.start(I4uCoachTask.ask);
      coach.updateDraft('Nháp trả lời của tôi');
      coach.requestHint();
      coach.submit();
      coach.showFeedback();
      i4uCheckHolds(
        coach.value.answerDraft == 'Nháp trả lời của tôi',
        'nháp bị xoá khi qua gợi ý/submit/feedback',
      );
      i4uCheckHolds(coach.value.hintLevel == 1, 'mức gợi ý bị mất');
      i4uCheckHolds(
        coach.value.sessionState == I4uCoachSessionState.feedback,
        'trạng thái phiên sai sau feedback',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-DFT-02',
    area: I4uPreservationArea.draft,
    requirement: 'Nguồn đổi revision (sự kiện hệ thống) KHÔNG xoá nháp đang gõ',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.document,
        sourceId: 'book-1',
        returnPath: '/read/book-1',
      );
      final coach = I4uCoachFlowController();
      coach.loadSource(source);
      coach.start(I4uCoachTask.explain);
      coach.requestHint();
      coach.updateDraft('Đang viết dở thì nguồn bị sửa');
      coach.markStale();
      i4uCheckHolds(
        coach.value.sessionState == I4uCoachSessionState.stale,
        'không đánh dấu được phiên cũ',
      );
      i4uCheckHolds(
        coach.value.answerDraft == 'Đang viết dở thì nguồn bị sửa',
        'nháp bị xoá khi nguồn đổi revision (mất chữ người dùng đã gõ)',
      );
      i4uCheckHolds(coach.value.hintLevel == 1, 'mức gợi ý bị xoá khi nguồn đổi revision');
      i4uCheckHolds(
        coach.value.source?.sourceId == 'book-1',
        'nguồn đang học mất khi đánh dấu phiên cũ',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-DFT-03',
    area: I4uPreservationArea.draft,
    requirement: 'Đóng panel công cụ vẫn giữ ngữ cảnh đoạn đang ghi chú',
    body: () {
      const selection = I4uReaderSelectionContext(
        text: 'tri giác',
        sourceId: 'book-1',
        blockId: 'para_014',
        characterOffset: 128,
      );
      const panel = I4uReaderContextualPanelState(
        mode: I4uReaderContextPanelMode.desktopPanel,
        selection: selection,
        activeAction: I4uReaderContextAction.note,
      );
      final closed = panel.close();
      i4uCheckHolds(
        closed.mode == I4uReaderContextPanelMode.closed,
        'đóng panel không trả về trạng thái closed',
      );
      i4uCheckHolds(
        closed.selection?.blockId == 'para_014' && closed.selection?.characterOffset == 128,
        'ngữ cảnh đoạn bị mất khi đóng panel (nháp ghi chú mất chỗ neo)',
      );

      // Nháp ghi chú dựng từ ngữ cảnh đó phải mang đủ chỗ neo để lưu lại sau
      // (mở lại đúng đoạn của nguồn — rule vàng #3).
      final draft = I4uReaderNoteDraft(
        sourceId: closed.selection!.sourceId,
        text: closed.selection!.text,
        blockId: closed.selection!.blockId,
        characterOffset: closed.selection!.characterOffset,
        body: 'ghi chú đang gõ',
      );
      i4uCheckHolds(draft.blockId == 'para_014', 'nháp ghi chú mất blockId');
      i4uCheckHolds(draft.characterOffset == 128, 'nháp ghi chú mất characterOffset');
      i4uCheckHolds(draft.body == 'ghi chú đang gõ', 'nội dung nháp ghi chú bị đổi');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-DFT-04',
    area: I4uPreservationArea.draft,
    requirement: 'Back khi có nháp: hỏi/autosave TRƯỚC khi trả về nguồn',
    body: () {
      const coordinator = I4uBackDismissCoordinator();
      const state = I4uBackState(
        hasUnsavedDraft: true,
        sourceReturnPath: '/read/book-1',
      );
      i4uCheckHolds(
        coordinator.decide(state).action == I4uBackAction.confirmDraft,
        'back bỏ qua nháp chưa lưu để nhảy thẳng về nguồn',
      );
      i4uCheckHolds(
        coordinator.decide(state, draftAutosaveSucceeded: true).action ==
            I4uBackAction.saveDraft,
        'autosave thành công nhưng không đi đường lưu nháp',
      );
    },
  ),

  I4uPreservationScenario(
    id: 'C31-DFT-05',
    area: I4uPreservationArea.draft,
    requirement: 'Tạm dừng phiên ôn giữ thẻ đang mở, tầng học thuộc, rating đã chọn và nguồn',
    body: () {
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.document,
        sourceId: 'book-1',
        returnPath: '/read/book-1',
      );
      final review = I4uRememberFlowController();
      review.loadSource(source);
      review.load(totalCount: 3);
      review.startStage(I4uMemorizationStage.recall, 'card-1');
      review.reveal();
      review.rate(I4uReviewRating.difficult);
      review.pause();

      i4uCheckHolds(
        review.value.currentCardId == 'card-1',
        'pause làm mất thẻ đang mở',
      );
      i4uCheckHolds(
        review.value.stage == I4uMemorizationStage.recall,
        'pause làm mất tầng học thuộc (UI quên người học đang ở tầng nào)',
      );
      i4uCheckHolds(
        review.value.rating == I4uReviewRating.difficult,
        'pause làm mất rating người học vừa chọn',
      );
      i4uCheckHolds(
        review.value.completedCount == 0 && review.value.totalCount == 3,
        'pause làm sai tiến độ phiên',
      );

      review.nextCard('card-2');
      i4uCheckHolds(
        review.value.stage == I4uMemorizationStage.recall,
        'sang thẻ kế tiếp tự rơi mất tầng học thuộc của phiên',
      );
      i4uCheckHolds(
        review.value.rating == null,
        'rating của thẻ cũ bị mang sang thẻ mới',
      );
    },
  ),

  // ── playback continuity ────────────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-PLY-01',
    area: I4uPreservationArea.playback,
    requirement: 'Quick Actions thu gọn Mini Player mà KHÔNG đổi trạng thái phát; đóng ra thì trả lại',
    body: () {
      const playing = I4uMiniPlayerSurfaceState(
        visualMode: I4uMiniPlayerVisualMode.mini,
        playbackStatus: I4uPlaybackStatus.playing,
      );
      final collapsed = playing.forQuickActions(opened: true);
      i4uCheckHolds(
        collapsed.visualMode == I4uMiniPlayerVisualMode.collapsed,
        'Quick Actions không thu gọn Mini Player',
      );
      i4uCheckHolds(
        collapsed.playbackStatus == I4uPlaybackStatus.playing,
        'mở Quick Actions làm đổi trạng thái phát',
      );
      i4uCheckHolds(
        collapsed.isAudioContinuingInBackground,
        'audio không được đánh dấu là tiếp tục khi Quick Actions mở',
      );

      final restored = collapsed.forQuickActions(opened: false);
      i4uCheckHolds(
        restored.visualMode == I4uMiniPlayerVisualMode.mini,
        'đóng Quick Actions không trả Mini Player về trạng thái trước đó',
      );
      i4uCheckHolds(
        restored.playbackStatus == I4uPlaybackStatus.playing,
        'đóng Quick Actions làm đổi trạng thái phát',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-PLY-02',
    area: I4uPreservationArea.playback,
    requirement: 'Sheet lớn ẩn foreground nhưng audio tiếp tục; đóng sheet khôi phục Mini Player',
    body: () {
      const playing = I4uMiniPlayerSurfaceState(
        visualMode: I4uMiniPlayerVisualMode.mini,
        playbackStatus: I4uPlaybackStatus.playing,
      );
      final hidden = playing.forLargeSheet(opened: true);
      i4uCheckHolds(
        hidden.visualMode == I4uMiniPlayerVisualMode.hidden,
        'sheet lớn không ẩn Mini Player khỏi foreground',
      );
      i4uCheckHolds(
        hidden.playbackStatus == I4uPlaybackStatus.playing &&
            hidden.isAudioContinuingInBackground,
        'mở sheet lớn làm dừng/mất trạng thái phát',
      );

      // docs/ux/36 §2: `largeSheetClosed → restore previous mini state`.
      final restored = hidden.forLargeSheet(opened: false);
      i4uCheckHolds(
        restored.visualMode == I4uMiniPlayerVisualMode.mini,
        'đóng sheet lớn không khôi phục Mini Player (mất điều khiển phát)',
      );
      i4uCheckHolds(
        restored.playbackStatus == I4uPlaybackStatus.playing,
        'khôi phục Mini Player làm đổi trạng thái phát',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-PLY-03',
    area: I4uPreservationArea.playback,
    requirement: 'Expanded Player là ngoại lệ full-screen: đóng ra về mini, mốc phát giữ nguyên',
    body: () {
      const playing = I4uMiniPlayerSurfaceState(
        visualMode: I4uMiniPlayerVisualMode.mini,
        playbackStatus: I4uPlaybackStatus.playing,
      );
      final expanded = playing.forExpandedPlayer(opened: true);
      i4uCheckHolds(
        expanded.visualMode == I4uMiniPlayerVisualMode.expanded,
        'không mở được Expanded Player',
      );
      i4uCheckHolds(
        expanded.playbackStatus == I4uPlaybackStatus.playing,
        'mở Expanded Player làm đổi trạng thái phát',
      );
      final closed = expanded.forExpandedPlayer(opened: false);
      i4uCheckHolds(
        closed.visualMode == I4uMiniPlayerVisualMode.mini,
        'đóng Expanded Player không trả về Mini Player',
      );
      i4uCheckHolds(
        closed.playbackStatus == I4uPlaybackStatus.playing,
        'đóng Expanded Player làm đổi trạng thái phát',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-PLY-04',
    area: I4uPreservationArea.playback,
    requirement: 'Mở/đóng player của Thư viện nghe không mất mục đang chọn',
    body: () {
      final flow = I4uAudioLibraryFlowController();
      flow.beginLoading();
      flow.completeLoading(hasItems: true);
      flow.select('audio-1');
      flow.expandPlayer();
      i4uCheckHolds(flow.value.selectedAudioId == 'audio-1', 'mất mục đang chọn khi mở player');
      i4uCheckHolds(
        flow.value.loadState == I4uAudioLibraryLoadState.ready,
        'mở player làm đổi trạng thái tải của thư viện',
      );
      flow.collapsePlayer();
      i4uCheckHolds(flow.value.selectedAudioId == 'audio-1', 'mất mục đang chọn khi đóng player');
      i4uCheckHolds(flow.value.isPlayerExpanded == false, 'player không đóng được');
    },
  ),
  I4uPreservationScenario(
    id: 'C31-PLY-05',
    area: I4uPreservationArea.playback,
    requirement: 'Đổi chế độ phụ đề trong Xem không nhảy mốc thời gian đang phát',
    body: () {
      final watch = I4uWatchModeFlowController();
      const source = I4uSourceFingerprint(
        sourceType: I4uSourceType.video,
        sourceId: 'video-1',
        returnPath: '/listen/video-1',
      );
      watch.ready(source: source, transcriptAvailable: true);
      watch.setTimestamp(84000);
      watch.setSubtitleMode(I4uSubtitleMode.bilingual);
      watch.setSubtitleMode(I4uSubtitleMode.original);
      i4uCheckHolds(
        watch.value.currentTimestampMs == 84000,
        'đổi chế độ phụ đề làm nhảy mốc thời gian',
      );
      i4uCheckHolds(
        watch.value.source?.sourceId == 'video-1',
        'đổi chế độ phụ đề làm mất nguồn đang xem',
      );
    },
  ),

  // ── route return ───────────────────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-RTN-01',
    area: I4uPreservationArea.routeReturn,
    requirement: 'Back đi đúng thứ tự lớp: overlay → panel → sheet → nháp → nguồn → route → Home',
    body: () {
      const coordinator = I4uBackDismissCoordinator();
      i4uCheckHolds(
        coordinator
                .decide(const I4uBackState(
                  overlays: <String>['quick-actions', 'chat'],
                  panel: 'context-panel',
                  sheet: 'note-sheet',
                  hasUnsavedDraft: true,
                  sourceReturnPath: '/read/book-1',
                  hasRouteHistory: true,
                ))
                .id ==
            'chat',
        'overlay trên cùng không được đóng trước',
      );
      i4uCheckHolds(
        coordinator
                .decide(const I4uBackState(panel: 'context-panel', sheet: 'note-sheet'))
                .action ==
            I4uBackAction.closePanel,
        'panel phải đóng trước sheet',
      );
      i4uCheckHolds(
        coordinator.decide(const I4uBackState(sheet: 'note-sheet')).action ==
            I4uBackAction.closeSheet,
        'sheet phải đóng trước khi trả nguồn',
      );
      i4uCheckHolds(
        coordinator
                .decide(const I4uBackState(sourceReturnPath: '/read/book-1'))
                .action ==
            I4uBackAction.returnToSource,
        'không trả về nguồn khi hết lớp phủ',
      );
      i4uCheckHolds(
        coordinator.decide(const I4uBackState(hasRouteHistory: true)).action ==
            I4uBackAction.popRoute,
        'không pop route khi không còn nguồn để trả',
      );
      i4uCheckHolds(
        coordinator.decide(const I4uBackState()).action == I4uBackAction.goHome,
        'không rơi về Home khi hết lịch sử',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-RTN-02',
    area: I4uPreservationArea.routeReturn,
    requirement: 'Trả nguồn mang đúng returnPath; ở Home thì nhường thoát cho nền tảng',
    body: () {
      const coordinator = I4uBackDismissCoordinator();
      final decision = coordinator.decide(
        const I4uBackState(sourceReturnPath: '/read/pdf-9?page=18'),
      );
      i4uCheckHolds(
        decision.action == I4uBackAction.returnToSource,
        'không trả về nguồn',
      );
      i4uCheckHolds(
        decision.id == '/read/pdf-9?page=18',
        'returnPath bị mất/biến dạng khi trả nguồn',
      );
      i4uCheckHolds(
        coordinator.decideAtRoot(const I4uBackState(), homeIsCurrent: true).action ==
            I4uBackAction.allowSystemExit,
        'Home không nhường quyền thoát cho nền tảng',
      );
    },
  ),

  // ── offline event / conflict ───────────────────────────────────────────
  I4uPreservationScenario(
    id: 'C31-OFF-01',
    area: I4uPreservationArea.offlineConflict,
    requirement: 'Conflict 2 thiết bị < 5 phút: event muộn không tính mastery nhưng KHÔNG bị xoá khỏi log',
    body: () {
      final base = DateTime.utc(2026, 10, 7, 9, 0);
      final early = _event(
        id: 'ev-early',
        unitId: 'unit-1',
        skill: SkillDimension.reading,
        at: base,
        device: 'phone',
      );
      final late = _event(
        id: 'ev-late',
        unitId: 'unit-1',
        skill: SkillDimension.reading,
        at: base.add(const Duration(minutes: 2)),
        device: 'tablet',
      );
      final input = <ReviewEvent>[late, early];
      final resolved = ReviewEventConflictResolver.resolveForMastery(input);

      i4uCheckHolds(
        resolved.length == input.length,
        'giải conflict làm mất event khỏi log (append-only bị vi phạm)',
      );
      i4uCheckHolds(
        resolved.first.eventId == 'ev-late' && resolved.first.ignoredForMastery,
        'event muộn không được đánh dấu "không tính mastery"',
      );
      i4uCheckHolds(
        resolved.last.eventId == 'ev-early' && !resolved.last.ignoredForMastery,
        'event sớm bị loại khỏi mastery',
      );
      i4uCheckHolds(
        !input.first.ignoredForMastery && !input.last.ignoredForMastery,
        'input bị đột biến khi giải conflict',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-OFF-02',
    area: I4uPreservationArea.offlineConflict,
    requirement: 'Hai thiết bị nhận event theo thứ tự khác nhau vẫn ra cùng kết quả; chạy lại không đổi',
    body: () {
      final base = DateTime.utc(2026, 10, 7, 9, 0);
      final events = <ReviewEvent>[
        _event(id: 'ev-a', unitId: 'unit-1', skill: SkillDimension.reading, at: base),
        _event(
          id: 'ev-b',
          unitId: 'unit-1',
          skill: SkillDimension.reading,
          at: base.add(const Duration(minutes: 1)),
          device: 'tablet',
        ),
        _event(
          id: 'ev-c',
          unitId: 'unit-1',
          skill: SkillDimension.reading,
          at: base.add(const Duration(minutes: 1)),
          device: 'laptop',
        ),
      ];
      final forward = ReviewEventConflictResolver.resolveForMastery(events);
      final backward =
          ReviewEventConflictResolver.resolveForMastery(events.reversed.toList());
      i4uCheckHolds(
        setEquals(_ignoredIds(forward), _ignoredIds(backward)),
        'hai thứ tự sync cho kết quả mastery khác nhau (không deterministic)',
      );
      final rerun = ReviewEventConflictResolver.resolveForMastery(forward);
      i4uCheckHolds(
        setEquals(_ignoredIds(rerun), _ignoredIds(forward)),
        'chạy lại resolver làm đổi kết quả (không idempotent)',
      );
      i4uCheckHolds(
        forward.length == events.length,
        'resolver không giữ đủ event (mất dấu vết conflict)',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-OFF-03',
    area: I4uPreservationArea.offlineConflict,
    requirement: 'Log review append-only: eventId trùng bị từ chối, nén (retire) không xoá dấu vết',
    body: () async {
      final base = DateTime.utc(2026, 10, 7, 9, 0);
      final store = InMemoryReviewEventStore();
      await store.append(_event(
        id: 'ev-1',
        unitId: 'unit-1',
        skill: SkillDimension.listening,
        at: base,
      ));

      var duplicateRejected = false;
      try {
        await store.append(_event(
          id: 'ev-1',
          unitId: 'unit-1',
          skill: SkillDimension.listening,
          at: base.add(const Duration(minutes: 1)),
          device: 'tablet',
        ));
      } on StateError {
        duplicateRejected = true;
      }
      i4uCheckHolds(
        duplicateRejected,
        'append eventId trùng không bị từ chối (nguy cơ nhân đôi khi sync)',
      );
      i4uCheckHolds(
        await store.activeCountOfUnit('unit-1') == 1,
        'append trùng vẫn ghi thêm event',
      );

      await store.retire(<String>{'ev-1'});
      i4uCheckHolds(
        await store.activeCountOfUnit('unit-1') == 0,
        'retire không gỡ event khỏi tập active',
      );
      i4uCheckHolds(
        store.totalAppended == 1 && store.totalRetired == 1,
        'nén event làm mất dấu vết kiểm kê (audit trail)',
      );
    },
  ),
  I4uPreservationScenario(
    id: 'C31-OFF-04',
    area: I4uPreservationArea.offlineConflict,
    requirement: 'Conflict chỉ áp cho cùng unit + cùng skill: skill khác không bị vạ lây',
    body: () {
      final base = DateTime.utc(2026, 10, 7, 9, 0);
      final resolved = ReviewEventConflictResolver.resolveForMastery(<ReviewEvent>[
        _event(id: 'ev-u', unitId: 'unit-1', skill: SkillDimension.understanding, at: base),
        _event(
          id: 'ev-r',
          unitId: 'unit-1',
          skill: SkillDimension.reading,
          at: base.add(const Duration(minutes: 1)),
          device: 'tablet',
        ),
      ]);
      i4uCheckHolds(
        _ignoredIds(resolved).isEmpty,
        'hai skill khác nhau bị coi là conflict (gộp skill trái vùng bảo vệ mục 0)',
      );
    },
  ),
];
