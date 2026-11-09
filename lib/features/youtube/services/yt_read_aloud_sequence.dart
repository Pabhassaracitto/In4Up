// YT-TTS-READ-001 — dựng THỨ TỰ đọc của "đọc bản dịch".
//
// Tách khỏi `yt_read_aloud_controller.dart` (file đó kéo theo `TtsService`,
// just_audio, shared_preferences…) để phần logic THUẦN này test được trong CI
// mà không cần plugin nào. Đây là chỗ dễ sai nhất (lặp, xen kẽ, bên nhiều bên
// ít, dòng thiếu bản dịch) nên phải có test.

import '../models/yt_learning_settings.dart';

/// Một bước đọc.
class YtReadAloudStep {
  const YtReadAloudStep({
    required this.line,
    required this.isTarget,
    required this.text,
  });

  /// Chỉ số dòng trong danh sách phụ đề (0-based).
  final int line;

  /// `true` = đọc bản dịch, `false` = đọc bản gốc.
  final bool isTarget;

  /// Nội dung thật sẽ đưa cho TTS.
  final String text;

  @override
  String toString() => 'step(line=$line, ${isTarget ? 'T' : 'S'}: $text)';
}

/// YT-READ-LOOP-LESSON-001 (#8) — số lượt đọc CẢ BÀI.
///
/// `passes == 0` ⇒ `null` = đọc mãi mãi (vòng tròn) tới khi bị `stop()`.
/// Trả `null` thay vì một số rất lớn để chỗ gọi biểu diễn được ý "vô hạn"
/// mà không phải đoán một trần tuỳ tiện.
int? ytPassCount(int passes) => passes == 0 ? null : (passes < 1 ? 1 : passes);

/// Một dòng phụ đề đã chuẩn bị để đọc.
class YtReadAloudLine {
  const YtReadAloudLine({required this.source, this.target});

  final String source;
  final String? target;

  bool get hasTarget => target != null && target!.trim().isNotEmpty;
}

/// Dựng danh sách bước đọc theo cài đặt.
///
/// Quy tắc (khớp đúng cách `YtReadAloudController` phát, nên test ở đây là
/// test hành vi thật):
///  * `sourceOnly`  → chỉ đọc gốc, bỏ qua `targetRepeats`.
///  * `targetOnly`  → chỉ đọc dịch; dòng nào KHÔNG có bản dịch thì đọc gốc
///    thay vì im lặng (im lặng trông như tính năng bị treo).
///  * `interleaved` → gốc (sourceRepeats lần) rồi dịch (targetRepeats lần),
///    từng dòng một, hết dòng này mới sang dòng kế.
///  * Bên nào đặt 0 lần thì bên đó bị bỏ.
///  * Dòng có nội dung rỗng bị bỏ (TTS không đọc được chuỗi rỗng).
List<YtReadAloudStep> buildYtReadAloudSequence({
  required List<YtReadAloudLine> lines,
  required YtLearningSettings settings,
  int startIndex = 0,
}) {
  final steps = <YtReadAloudStep>[];
  if (lines.isEmpty) return steps;

  final mode = settings.readAloudMode;
  final wantSource = mode != YtReadAloudMode.targetOnly;
  final wantTarget = mode != YtReadAloudMode.sourceOnly;
  final srcRepeats = wantSource ? settings.readAloudSourceRepeats : 0;
  final tgtRepeats = wantTarget ? settings.readAloudTargetRepeats : 0;

  final start = startIndex < 0
      ? 0
      : (startIndex >= lines.length ? lines.length - 1 : startIndex);

  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    final source = line.source.trim();
    final target = (line.target ?? '').trim();
    final hasTarget = target.isNotEmpty;

    for (var r = 0; r < srcRepeats; r++) {
      if (source.isEmpty) break;
      steps.add(YtReadAloudStep(line: i, isTarget: false, text: source));
    }

    if (hasTarget) {
      for (var r = 0; r < tgtRepeats; r++) {
        steps.add(YtReadAloudStep(line: i, isTarget: true, text: target));
      }
    } else if (tgtRepeats > 0 && srcRepeats == 0 && source.isNotEmpty) {
      // Chế độ "chỉ bản dịch" nhưng dòng chưa có dịch ⇒ đọc gốc.
      steps.add(YtReadAloudStep(line: i, isTarget: false, text: source));
    }
  }
  return steps;
}
