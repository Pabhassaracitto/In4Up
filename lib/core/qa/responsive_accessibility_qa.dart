/// C-30 — RESPONSIVE / ACCESSIBILITY QA
///
/// Bộ kiểm định 7 vùng của `docs/ux/39-capability-breakdown.vi.md` mục C-30:
///
/// ```text
/// C-30 — Responsive/accessibility QA
///   text scale        — chrome kẹp theo chính sách, không vỡ khi chữ to
///   keyboard          — dùng viewInsets thật, input không bị bàn phím che
///   screen reader labels — surface có nhãn đọc được (KHÔNG icon trần)
///   touch targets     — vùng chạm ≥ ngưỡng Material, không bị bóp
///   orientation       — đổi hướng chỉ đổi bố cục, không vỡ/không mất input
///   safe area         — không offset cứng; inset âm bị kẹp, không chồng navigation
///   overlay stacking  — thứ tự lớp tất định theo policy dùng chung
/// ```
///
/// **Hai nguồn bằng chứng (cố ý tách):**
///
/// 1. [kI4uResponsiveScenarios] — logic thuần Dart (chính sách responsive, safe-area,
///    overlay, ngưỡng chữ). Chạy được ở mọi nơi, không cần `BuildContext`.
/// 2. [I4uResponsiveEvidence] — bằng chứng đo được trên **widget thật** (nhãn
///    semantics, kích thước vùng chạm, không tràn khi chữ to, bàn phím che input).
///    Do test file `test/responsive_accessibility_qa_test.dart` cung cấp, vì chỉ ở
///    đó mới có `WidgetTester`.
///
/// **Cổng chặn trung thực:** `screenReaderLabels` và `touchTargets` KHÔNG có kịch bản
/// thuần nào — nếu test widget không cung cấp bằng chứng thì chúng nằm trong
/// [I4uResponsiveReport.uncoveredAreas] ⇒ [I4uResponsiveReport.isComplete] là `false`
/// ⇒ `toQualityRun()` trả blocker. Đây là chủ ý: "không đo được" không được tính là
/// "đạt", và một báo cáo C-30 xanh mà thiếu 2 vùng đó là báo cáo giả.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TextScaler;

import '../responsive/app_responsive.dart';
import '../responsive/safe_area_overlay_policy.dart';
import '../shortcuts/shortcut_registry.dart';
import 'ux_quality_contract.dart';

/// Bảy vùng bắt buộc của C-30.
enum I4uResponsiveArea {
  textScale,
  keyboard,
  screenReaderLabels,
  touchTargets,
  orientation,
  safeArea,
  overlayStacking,
}

extension I4uResponsiveAreaInfo on I4uResponsiveArea {
  String get slug => switch (this) {
        I4uResponsiveArea.textScale => 'text-scale',
        I4uResponsiveArea.keyboard => 'keyboard',
        I4uResponsiveArea.screenReaderLabels => 'screen-reader-labels',
        I4uResponsiveArea.touchTargets => 'touch-targets',
        I4uResponsiveArea.orientation => 'orientation',
        I4uResponsiveArea.safeArea => 'safe-area',
        I4uResponsiveArea.overlayStacking => 'overlay-stacking',
      };

  String get labelVi => switch (this) {
        I4uResponsiveArea.textScale => 'Chữ to: chrome kẹp theo chính sách, không vỡ',
        I4uResponsiveArea.keyboard => 'Bàn phím: dùng viewInsets thật, không che input',
        I4uResponsiveArea.screenReaderLabels => 'Nhãn đọc được cho screen reader',
        I4uResponsiveArea.touchTargets => 'Vùng chạm đủ lớn, không bị bóp',
        I4uResponsiveArea.orientation => 'Đổi hướng: đổi bố cục, không vỡ',
        I4uResponsiveArea.safeArea => 'Safe-area động, không offset cứng',
        I4uResponsiveArea.overlayStacking => 'Thứ tự lớp tất định theo policy chung',
      };

  /// Vùng chỉ kết luận được bằng đo trên widget thật.
  bool get requiresWidgetEvidence =>
      this == I4uResponsiveArea.screenReaderLabels ||
      this == I4uResponsiveArea.touchTargets;
}

/// Bất biến bị vi phạm ⇒ ném lỗi để harness ghi nhận FAIL kèm lý do.
void i4uCheckResponsive(bool condition, String message) {
  if (!condition) {
    throw StateError('[C-30] $message');
  }
}

typedef I4uResponsiveScenarioBody = FutureOr<void> Function();

@immutable
class I4uResponsiveScenario {
  const I4uResponsiveScenario({
    required this.id,
    required this.area,
    required this.requirement,
    required this.body,
  });

  /// Mã kịch bản, ví dụ `C30-KBD-02`.
  final String id;
  final I4uResponsiveArea area;

  /// Phát biểu bất biến — đọc lên là hiểu QA đang giữ điều gì.
  final String requirement;

  final I4uResponsiveScenarioBody body;
}

@immutable
class I4uResponsiveCheckResult {
  const I4uResponsiveCheckResult({
    required this.id,
    required this.area,
    required this.requirement,
    required this.passed,
    this.detail,
  });

  final String id;
  final I4uResponsiveArea area;
  final String requirement;
  final bool passed;
  final String? detail;

  bool get failed => !passed;
}

/// Bằng chứng đo trên widget thật (do `flutter_test` cung cấp).
@immutable
class I4uResponsiveEvidence {
  const I4uResponsiveEvidence({
    required this.id,
    required this.area,
    required this.requirement,
    required this.passed,
    this.detail,
  });

  final String id;
  final I4uResponsiveArea area;
  final String requirement;
  final bool passed;
  final String? detail;

  I4uResponsiveCheckResult get asResult => I4uResponsiveCheckResult(
        id: id,
        area: area,
        requirement: requirement,
        passed: passed,
        detail: detail,
      );
}

@immutable
class I4uResponsiveReport {
  const I4uResponsiveReport({
    required this.results,
    this.manualChecks = kI4uResponsiveManualChecks,
  });

  final List<I4uResponsiveCheckResult> results;

  /// Việc chỉ kết luận được trên thiết bị thật — không tự động PASS.
  final Map<I4uResponsiveArea, List<String>> manualChecks;

  Iterable<I4uResponsiveCheckResult> get failures =>
      results.where((result) => result.failed);

  int get passedCount => results.where((result) => result.passed).length;

  List<I4uResponsiveArea> get uncoveredAreas => <I4uResponsiveArea>[
        for (final area in I4uResponsiveArea.values)
          if (!results.any((result) => result.area == area)) area,
      ];

  int countFor(I4uResponsiveArea area) =>
      results.where((result) => result.area == area).length;

  int failedCountFor(I4uResponsiveArea area) =>
      results.where((result) => result.area == area && result.failed).length;

  bool get allHold => results.isNotEmpty && failures.isEmpty;

  /// Đóng được C-30 chỉ khi: mọi kiểm định đạt VÀ đủ 7 vùng (kể cả 2 vùng cần
  /// bằng chứng widget). Thiếu bằng chứng widget ⇒ KHÔNG đạt.
  bool get isComplete => allHold && uncoveredAreas.isEmpty;

  /// Vùng nào đang chỉ có bằng chứng widget (không có kịch bản thuần).
  List<I4uResponsiveArea> get widgetEvidenceAreas => <I4uResponsiveArea>[
        for (final area in I4uResponsiveArea.values)
          if (area.requiresWidgetEvidence && countFor(area) > 0) area,
      ];

  /// Nối C-30 vào hợp đồng freeze dùng chung (C-31 / `I4uQualityRun`).
  I4uQualityRun toQualityRun() => I4uQualityRun(
        findings: <I4uQualityFinding>[
          I4uQualityFinding(
            check: I4uQualityCheck.responsive,
            status: _statusFor(<I4uResponsiveArea>[
              I4uResponsiveArea.textScale,
              I4uResponsiveArea.orientation,
            ]),
            details: _detailsFor(<I4uResponsiveArea>[
              I4uResponsiveArea.textScale,
              I4uResponsiveArea.orientation,
            ]),
          ),
          I4uQualityFinding(
            check: I4uQualityCheck.accessibility,
            status: _statusFor(<I4uResponsiveArea>[
              I4uResponsiveArea.screenReaderLabels,
              I4uResponsiveArea.touchTargets,
            ]),
            details: _detailsFor(<I4uResponsiveArea>[
              I4uResponsiveArea.screenReaderLabels,
              I4uResponsiveArea.touchTargets,
            ]),
          ),
          I4uQualityFinding(
            check: I4uQualityCheck.keyboard,
            status: _statusFor(<I4uResponsiveArea>[I4uResponsiveArea.keyboard]),
            details: _detailsFor(<I4uResponsiveArea>[I4uResponsiveArea.keyboard]),
          ),
          I4uQualityFinding(
            check: I4uQualityCheck.safeArea,
            status: _statusFor(<I4uResponsiveArea>[
              I4uResponsiveArea.safeArea,
              I4uResponsiveArea.overlayStacking,
            ]),
            details: _detailsFor(<I4uResponsiveArea>[
              I4uResponsiveArea.safeArea,
              I4uResponsiveArea.overlayStacking,
            ]),
          ),
        ],
      );

  I4uQualityStatus _statusFor(List<I4uResponsiveArea> areas) {
    for (final area in areas) {
      if (countFor(area) == 0) return I4uQualityStatus.fail; // chưa đo được
      if (failedCountFor(area) > 0) return I4uQualityStatus.fail;
    }
    return I4uQualityStatus.pass;
  }

  String _detailsFor(List<I4uResponsiveArea> areas) =>
      areas.map((area) => '${area.slug} '
          '${countFor(area) - failedCountFor(area)}/${countFor(area)}').join(', ');

  /// Log dạng văn bản để dán vào QA tay hoặc đọc từ artifact CI.
  String toSummary() {
    final buffer = StringBuffer()
      ..writeln('C-30 responsive/accessibility — '
          '$passedCount/${results.length} kiểm định đạt, '
          '${I4uResponsiveArea.values.length - uncoveredAreas.length}/'
          '${I4uResponsiveArea.values.length} vùng có bằng chứng');
    for (final area in I4uResponsiveArea.values) {
      final source = area.requiresWidgetEvidence ? 'widget' : 'logic';
      buffer.writeln('  ${area.slug.padRight(20)} '
          '${countFor(area) - failedCountFor(area)}/${countFor(area)} '
          '($source) — ${area.labelVi}');
    }
    for (final failure in failures) {
      buffer.writeln('  FAIL ${failure.id} (${failure.area.slug}): '
          '${failure.detail ?? 'không rõ lỗi'}');
    }
    for (final area in uncoveredAreas) {
      buffer.writeln('  THIẾU BẰNG CHỨNG ${area.slug}: ${area.labelVi}');
    }
    for (final entry in manualChecks.entries) {
      for (final step in entry.value) {
        buffer.writeln('  QA TAY ${entry.key.slug}: $step');
      }
    }
    return buffer.toString();
  }
}

/// Chạy C-30: logic thuần ([scenarios]) + bằng chứng widget ([evidence]).
class I4uResponsiveQa {
  const I4uResponsiveQa({this.scenarios, this.evidence = const <I4uResponsiveEvidence>[]});

  /// Cho phép test bơm bộ kịch bản hẹp (âm tính) mà không đổi bộ chuẩn.
  final List<I4uResponsiveScenario>? scenarios;

  /// Bằng chứng từ `flutter_test` (nhãn semantics, kích thước chạm, …).
  final List<I4uResponsiveEvidence> evidence;

  List<I4uResponsiveScenario> get effectiveScenarios =>
      scenarios ?? kI4uResponsiveScenarios;

  Future<I4uResponsiveReport> run() async {
    final results = <I4uResponsiveCheckResult>[];
    for (final scenario in effectiveScenarios) {
      try {
        await scenario.body();
        results.add(I4uResponsiveCheckResult(
          id: scenario.id,
          area: scenario.area,
          requirement: scenario.requirement,
          passed: true,
        ));
      } catch (error) {
        results.add(I4uResponsiveCheckResult(
          id: scenario.id,
          area: scenario.area,
          requirement: scenario.requirement,
          passed: false,
          detail: '$error',
        ));
      }
    }
    for (final item in evidence) {
      results.add(item.asResult);
    }
    return I4uResponsiveReport(results: results);
  }
}

/// Việc QA tay trên thiết bị thật — harness KHÔNG tự nhận đạt.
const Map<I4uResponsiveArea, List<String>> kI4uResponsiveManualChecks =
    <I4uResponsiveArea, List<String>>{
  I4uResponsiveArea.textScale: <String>[
    'Cài đặt hệ thống: cỡ chữ Lớn nhất (Android) / Larger Text (iOS) — chrome không vỡ, không cắt nút.',
    'Trong app: cỡ chữ riêng (nếu có) kết hợp cỡ hệ thống — kiểm màn Đọc/Ghi chú/AI Coach.',
    'Nội dung đọc giữ nguyên cỡ người dùng chọn, KHÔNG bị kẹp như chrome.',
  ],
  I4uResponsiveArea.keyboard: <String>[
    'Mở bàn phím ở ô nhập ghi chú + ô chat: input luôn nằm trên bàn phím.',
    'Bàn phím hệ thống có thanh gợi ý/emoji (chiều cao khác nhau) — không che nút gửi.',
    'Xoay máy khi bàn phím đang mở — không nhảy layout, không mất chữ đang gõ.',
  ],
  I4uResponsiveArea.screenReaderLabels: <String>[
    'TalkBack/VoiceOver: đọc đúng tên nút + trạng thái (đang chọn/chưa chọn) cho 5 tab.',
    'Player: nút play/pause đọc đúng trạng thái phát; không đọc "button" trần.',
    'Dialog/sheet: tiêu đề được đọc, focus vào phần tử đầu và trả focus khi đóng.',
  ],
  I4uResponsiveArea.touchTargets: <String>[
    'Vùng chạm thật ≥ 48dp cho icon nút (đo bằng TalkBack/VoiceOver "hiển thị ranh giới").',
    'Nút sát mép dưới (Mini Player, thanh dưới) không bị safe-area/gesture bar nuốt.',
  ],
  I4uResponsiveArea.orientation: <String>[
    'Xoay dọc ↔ ngang ở Đọc/Nghe/Xem/Hiểu/Nhớ: bố cục đổi, KHÔNG mất vị trí đang đọc.',
    'Xoay khi đang phát audio: âm thanh không ngắt, Mini Player không nhảy trạng thái.',
    'Cửa sổ nhỏ (desktop/web): kéo nhỏ hơn 1024 ⇒ sidebar thu về bottom nav, không tràn.',
  ],
  I4uResponsiveArea.safeArea: <String>[
    'Máy có notch/gesture bar: surface nổi không bị che, bottom nav không chồng.',
    'Khi bàn phím mở: surface nổi dùng inset lớn hơn (không cộng dồn sai).',
  ],
  I4uResponsiveArea.overlayStacking: <String>[
    'Mở Command Palette khi sheet đang mở: đúng 1 lớp trên cùng nhận input.',
    'Mini Player + Quick Actions + bottom nav: không lớp nào che vùng chạm của lớp khác.',
  ],
};

const double _kEpsilon = 0.001;

/// Bộ kịch bản logic thuần của C-30 (5/7 vùng; 2 vùng còn lại cần widget).
final List<I4uResponsiveScenario> kI4uResponsiveScenarios = <I4uResponsiveScenario>[
  // ── text scale ─────────────────────────────────────────────────────────
  I4uResponsiveScenario(
    id: 'C30-TXT-01',
    area: I4uResponsiveArea.textScale,
    requirement: 'Cỡ chữ chrome bị kẹp đúng dải chính sách (0.95–1.15) ở cả API số lẫn TextScaler',
    body: () {
      i4uCheckResponsive(AppResponsive.clampTextScale(1.0) == 1.0,
          'cỡ chữ 1.0 bị đổi (mặc định phải giữ nguyên)');
      i4uCheckResponsive(AppResponsive.clampTextScale(0.5) == 0.95,
          'cỡ chữ quá nhỏ không được nâng lên sàn 0.95');
      i4uCheckResponsive(AppResponsive.clampTextScale(3.0) == 1.15,
          'cỡ chữ quá lớn không bị kẹp trần 1.15');

      final enlarged = AppResponsive.clampTextScaler(TextScaler.linear(3.0)).scale(14);
      final shrunk = AppResponsive.clampTextScaler(TextScaler.linear(0.5)).scale(14);
      i4uCheckResponsive((enlarged - 1.15 * 14).abs() < _kEpsilon,
          'TextScaler trần: 14sp ở scale 3.0 phải thành ${1.15 * 14}, nhận $enlarged');
      i4uCheckResponsive((shrunk - 0.95 * 14).abs() < _kEpsilon,
          'TextScaler sàn: 14sp ở scale 0.5 phải thành ${0.95 * 14}, nhận $shrunk');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-TXT-02',
    area: I4uResponsiveArea.textScale,
    requirement: 'Số cột lưới tăng đơn điệu theo bề rộng (không nhảy ngược khi màn rộng hơn)',
    body: () {
      final columns = <int>[
        AppResponsive.adaptiveGridColumns(360),
        AppResponsive.adaptiveGridColumns(800),
        AppResponsive.adaptiveGridColumns(1200),
        AppResponsive.adaptiveGridColumns(1600),
      ];
      i4uCheckResponsive(columns.toString() == '[1, 2, 3, 4]',
          'số cột mặc định theo lớp cửa sổ phải là 1/2/3/4, nhận $columns');
      for (var i = 1; i < columns.length; i++) {
        i4uCheckResponsive(columns[i] >= columns[i - 1],
            'số cột giảm khi bề rộng tăng: $columns');
      }
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-TXT-03',
    area: I4uResponsiveArea.textScale,
    requirement: 'Bề rộng nội dung không vượt màn hình và không kéo dài vô hạn trên màn rộng',
    body: () {
      i4uCheckResponsive(AppResponsive.pageMaxContentWidth(320) <= 320,
          'màn hẹp: bề rộng nội dung vượt quá màn hình');
      i4uCheckResponsive(AppResponsive.pageMaxContentWidth(1600) == 1360,
          'màn rộng: không giới hạn độ dài dòng đọc theo chính sách 1360');
      final paddings = <double>[
        AppResponsive.pageHorizontalPadding(320),
        AppResponsive.pageHorizontalPadding(360),
        AppResponsive.pageHorizontalPadding(800),
        AppResponsive.pageHorizontalPadding(1600),
      ];
      i4uCheckResponsive(paddings.toString() == '[12.0, 16.0, 20.0, 32.0]',
          'padding ngang theo lớp cửa sổ sai: $paddings');
      for (var i = 1; i < paddings.length; i++) {
        i4uCheckResponsive(paddings[i] >= paddings[i - 1],
            'padding ngang giảm khi màn rộng hơn: $paddings');
      }
    },
  ),

  // ── keyboard ───────────────────────────────────────────────────────────
  I4uResponsiveScenario(
    id: 'C30-KBD-01',
    area: I4uResponsiveArea.keyboard,
    requirement: 'Inset hiệu dụng = max(safe-area, viewInsets), không âm',
    body: () {
      i4uCheckResponsive(
          I4uSafeAreaPolicy.effectiveBottomInset(safeAreaBottom: 0, viewInsetBottom: 0) == 0,
          'không inset mà trả về khác 0');
      i4uCheckResponsive(
          I4uSafeAreaPolicy.effectiveBottomInset(safeAreaBottom: 34, viewInsetBottom: 0) == 34,
          'safe-area bị bỏ khi bàn phím đóng');
      i4uCheckResponsive(
          I4uSafeAreaPolicy.effectiveBottomInset(safeAreaBottom: 0, viewInsetBottom: 300) == 300,
          'viewInsets không được dùng khi bàn phím mở');
      i4uCheckResponsive(
          I4uSafeAreaPolicy.effectiveBottomInset(safeAreaBottom: 34, viewInsetBottom: 300) == 300,
          'bàn phím mở phải lấy max (không cộng dồn sai)');
      i4uCheckResponsive(
          I4uSafeAreaPolicy.effectiveBottomInset(safeAreaBottom: -5, viewInsetBottom: -10) == 0,
          'inset âm không bị kẹp về 0');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-KBD-02',
    area: I4uResponsiveArea.keyboard,
    requirement: 'Offset surface nổi = inset hiệu dụng + chiều cao navigation + spacing',
    body: () {
      i4uCheckResponsive(
          I4uSafeAreaPolicy.floatingBottomOffset(
                safeAreaBottom: 34,
                viewInsetBottom: 0,
                navigationHeight: 64,
                spacing: 12,
              ) ==
              110,
          'công thức offset (bàn phím đóng) sai');
      final withKeyboard = I4uSafeAreaPolicy.floatingBottomOffset(
        safeAreaBottom: 34,
        viewInsetBottom: 300,
        navigationHeight: 64,
        spacing: 12,
      );
      i4uCheckResponsive(withKeyboard == 376, 'công thức offset (bàn phím mở) sai: $withKeyboard');
      i4uCheckResponsive(withKeyboard > 110,
          'mở bàn phím không đẩy surface nổi lên (input sẽ bị che)');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-KBD-03',
    area: I4uResponsiveArea.keyboard,
    requirement: 'Offset không bao giờ thấp hơn chiều cao navigation + spacing (không chồng thanh dưới)',
    body: () {
      const navigation = 64.0;
      const spacing = 12.0;
      final cases = <List<double>>[
        <double>[-50, -50],
        <double>[0, 0],
        <double>[34, 0],
        <double>[0, 300],
        <double>[34, 300],
      ];
      for (final item in cases) {
        final offset = I4uSafeAreaPolicy.floatingBottomOffset(
          safeAreaBottom: item[0],
          viewInsetBottom: item[1],
          navigationHeight: navigation,
          spacing: spacing,
        );
        i4uCheckResponsive(offset >= navigation + spacing - _kEpsilon,
            'offset ${item} = $offset < ${navigation + spacing} ⇒ surface đè lên navigation');
      }
    },
  ),

  // ── safe area ──────────────────────────────────────────────────────────
  I4uResponsiveScenario(
    id: 'C30-SAF-01',
    area: I4uResponsiveArea.safeArea,
    requirement: 'Inset âm/rác bị kẹp, không tạo padding âm',
    body: () {
      i4uCheckResponsive(
          I4uSafeAreaPolicy.floatingBottomOffset(
                safeAreaBottom: -100,
                viewInsetBottom: -100,
                navigationHeight: 0,
                spacing: 0,
              ) >=
              0,
          'inset âm tạo offset âm');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-SAF-02',
    area: I4uResponsiveArea.safeArea,
    requirement: 'Offset theo giá trị runtime (3 bối cảnh khác nhau ⇒ 3 offset khác nhau), không hard-code',
    body: () {
      double offset(double safe, double view) => I4uSafeAreaPolicy.floatingBottomOffset(
            safeAreaBottom: safe,
            viewInsetBottom: view,
            navigationHeight: 64,
          );
      final values = <double>{offset(0, 0), offset(34, 0), offset(0, 300)};
      i4uCheckResponsive(values.length == 3,
          'offset không phản ánh inset runtime (nhóm giá trị: $values) — nghi hard-code');
      i4uCheckResponsive(offset(0, 0) == 76, 'offset mặc định phải là navigation 64 + spacing 12');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-SAF-03',
    area: I4uResponsiveArea.safeArea,
    requirement: 'Công thức offset khớp tài liệu trên toàn lưới giá trị (không lệch từng trường hợp)',
    body: () {
      for (final safe in <double>[0, 20, 34, 48]) {
        for (final view in <double>[0, 120, 300]) {
          for (final navigation in <double>[0, 56, 64]) {
            final expected = (safe > view ? safe : view) + navigation + 12;
            final actual = I4uSafeAreaPolicy.floatingBottomOffset(
              safeAreaBottom: safe,
              viewInsetBottom: view,
              navigationHeight: navigation,
            );
            i4uCheckResponsive((actual - expected).abs() < _kEpsilon,
                'safe=$safe view=$view nav=$navigation: mong $expected, nhận $actual');
          }
        }
      }
    },
  ),

  // ── overlay stacking ───────────────────────────────────────────────────
  I4uResponsiveScenario(
    id: 'C30-OVL-01',
    area: I4uResponsiveArea.overlayStacking,
    requirement: 'Thứ tự lớp tăng nghiêm ngặt: content < navigation < miniPlayer < panel < sheet < dialog < fullScreenModal',
    body: () {
      const chain = <I4uOverlayLayer>[
        I4uOverlayLayer.content,
        I4uOverlayLayer.navigation,
        I4uOverlayLayer.miniPlayer,
        I4uOverlayLayer.panel,
        I4uOverlayLayer.sheet,
        I4uOverlayLayer.dialog,
        I4uOverlayLayer.fullScreenModal,
      ];
      for (var i = 1; i < chain.length; i++) {
        i4uCheckResponsive(I4uOverlayPolicy.isAbove(chain[i], chain[i - 1]),
            '${chain[i]} phải nằm trên ${chain[i - 1]}');
        i4uCheckResponsive(!I4uOverlayPolicy.isAbove(chain[i - 1], chain[i]),
            'quan hệ trên/dưới không đối xứng ở ${chain[i - 1]}/${chain[i]}');
      }
      i4uCheckResponsive(I4uOverlayPolicy.order(I4uOverlayLayer.dialog) >
              I4uOverlayPolicy.order(I4uOverlayLayer.sheet),
          'dialog phải trên sheet');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-OVL-02',
    area: I4uResponsiveArea.overlayStacking,
    requirement: 'Mini Player không chen vào foreground khi có lớp phủ đang mở',
    body: () {
      i4uCheckResponsive(
          I4uOverlayPolicy.miniPlayerVisibleInForeground(
              quickActionsOpen: false, largeSheetOpen: false, expandedPlayerOpen: false),
          'trạng thái nghỉ: Mini Player phải hiện foreground');
      i4uCheckResponsive(
          !I4uOverlayPolicy.miniPlayerVisibleInForeground(
              quickActionsOpen: true, largeSheetOpen: false, expandedPlayerOpen: false),
          'Quick Actions mở mà Mini Player vẫn foreground (tranh vùng chạm)');
      i4uCheckResponsive(
          !I4uOverlayPolicy.miniPlayerVisibleInForeground(
              quickActionsOpen: false, largeSheetOpen: true, expandedPlayerOpen: false),
          'sheet lớn mở mà Mini Player vẫn foreground');
      i4uCheckResponsive(
          !I4uOverlayPolicy.miniPlayerVisibleInForeground(
              quickActionsOpen: false, largeSheetOpen: false, expandedPlayerOpen: true),
          'Expanded Player mở mà Mini Player vẫn foreground');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-OVL-03',
    area: I4uResponsiveArea.overlayStacking,
    requirement: 'Audio chỉ tiếp tục nền khi sheet lớn ẩn player (không phải mọi trường hợp)',
    body: () {
      i4uCheckResponsive(
          I4uOverlayPolicy.audioContinuesInBackground(largeSheetOpen: true, expandedPlayerOpen: false),
          'sheet lớn phải giữ audio tiếp tục');
      i4uCheckResponsive(
          !I4uOverlayPolicy.audioContinuesInBackground(largeSheetOpen: true, expandedPlayerOpen: true),
          'Expanded Player là ngoại lệ full-screen, không tính "tiếp tục nền"');
      i4uCheckResponsive(
          !I4uOverlayPolicy.audioContinuesInBackground(largeSheetOpen: false, expandedPlayerOpen: false),
          'không có sheet mà vẫn báo audio tiếp tục nền');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-OVL-04',
    area: I4uResponsiveArea.overlayStacking,
    requirement: 'Shortcut scope ánh xạ đúng lớp (modal → dialog, player → miniPlayer, workspace/global → content)',
    body: () {
      i4uCheckResponsive(
          I4uOverlayPolicy.layerForShortcutScope(I4uShortcutScope.modal) == I4uOverlayLayer.dialog,
          'scope modal phải ánh xạ lên lớp dialog');
      i4uCheckResponsive(
          I4uOverlayPolicy.layerForShortcutScope(I4uShortcutScope.player) ==
              I4uOverlayLayer.miniPlayer,
          'scope player phải ánh xạ lên lớp miniPlayer');
      i4uCheckResponsive(
          I4uOverlayPolicy.layerForShortcutScope(I4uShortcutScope.workspace) ==
              I4uOverlayLayer.content,
          'scope workspace phải nằm ở lớp content');
      i4uCheckResponsive(
          I4uOverlayPolicy.layerForShortcutScope(I4uShortcutScope.global) ==
              I4uOverlayLayer.content,
          'scope global phải nằm ở lớp content');
    },
  ),

  // ── orientation ────────────────────────────────────────────────────────
  I4uResponsiveScenario(
    id: 'C30-ORI-01',
    area: I4uResponsiveArea.orientation,
    requirement: 'Phân lớp cửa sổ đúng theo bề rộng và không nhảy ngược (dọc/ngang/tablet/desktop)',
    body: () {
      i4uCheckResponsive(AppResponsive.classify(360) == AppWindowClass.compact,
          'điện thoại dọc (360) phải là compact');
      i4uCheckResponsive(AppResponsive.classify(640) == AppWindowClass.medium,
          'điện thoại ngang (640) phải là medium');
      i4uCheckResponsive(AppResponsive.classify(1200) == AppWindowClass.expanded,
          'tablet ngang (1200) phải là expanded');
      i4uCheckResponsive(AppResponsive.classify(1600) == AppWindowClass.large,
          'desktop (1600) phải là large');

      var previous = -1;
      for (var width = 320.0; width <= 2000; width += 20) {
        final index = AppResponsive.classify(width).index;
        i4uCheckResponsive(index >= previous, 'phân lớp nhảy ngược tại width=$width');
        previous = index;
      }
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-ORI-02',
    area: I4uResponsiveArea.orientation,
    requirement: 'Đổi hướng ⇒ bố cục đổi theo (cột/padding), không chỉ ẩn hiện tuỳ tiện',
    body: () {
      i4uCheckResponsive(
          AppResponsive.adaptiveGridColumns(360) < AppResponsive.adaptiveGridColumns(1200),
          'số cột không đổi giữa dọc và ngang');
      i4uCheckResponsive(
          AppResponsive.pageHorizontalPadding(360) <= AppResponsive.pageHorizontalPadding(1200),
          'padding ngang nghịch giữa dọc và ngang');
      i4uCheckResponsive(
          AppResponsive.pageMaxContentWidth(1200) < 1200,
          'màn ngang không giới hạn bề rộng nội dung (dòng đọc quá dài)');
    },
  ),
  I4uResponsiveScenario(
    id: 'C30-ORI-03',
    area: I4uResponsiveArea.orientation,
    requirement: 'Ngưỡng breakpoint là một nguồn duy nhất và classify khớp đúng tại biên',
    body: () {
      i4uCheckResponsive(
          AppResponsive.compactWidth < AppResponsive.mediumWidth &&
              AppResponsive.mediumWidth < AppResponsive.expandedWidth &&
              AppResponsive.expandedWidth < AppResponsive.largeWidth,
          'các ngưỡng breakpoint không tăng dần');
      i4uCheckResponsive(AppResponsive.classify(AppResponsive.mediumWidth) == AppWindowClass.medium,
          'tại biên mediumWidth, phân lớp phải là medium');
      i4uCheckResponsive(
          AppResponsive.classify(AppResponsive.expandedWidth) == AppWindowClass.expanded,
          'tại biên expandedWidth, phân lớp phải là expanded');
      i4uCheckResponsive(AppResponsive.classify(AppResponsive.largeWidth) == AppWindowClass.large,
          'tại biên largeWidth, phân lớp phải là large');
      i4uCheckResponsive(AppResponsive.isCompact(AppResponsive.compactWidth - 1),
          'isCompact sai dưới ngưỡng compact');
      i4uCheckResponsive(!AppResponsive.isCompact(AppResponsive.mediumWidth),
          'isCompact sai tại ngưỡng medium');
    },
  ),
];
