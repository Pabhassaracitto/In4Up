// YT-PREPARE-001 (#4 owner 2026-10-28) — "nút Tải" thành một KẾ HOẠCH có lựa
// chọn, không phải một nút mù.
//
// Owner nói: *"Không nạp sẵn, mà do người dùng nhấn vô tab tải có lựa chọn tải
// về, đồng bộ tab đọc, lưu luôn đám mây hay không. Nói chung bạn làm sao đó cho
// tinh tế, thông minh."*
//
// "Tinh tế" ở đây được hiện thực bằng ba thứ, và cả ba nằm trong file THUẦN này
// để test được:
//  1. **Không làm lại việc đã xong** — phụ đề/âm thanh đã có sẵn thì bỏ qua
//     bước đó (người dùng không phải chờ tải lại 30 MB chỉ để đồng bộ tab Đọc).
//  2. **Không hứa suông** — mỗi lựa chọn không thực hiện được thì trả về một
//     mã lý do (`sync_needs_captions`, `cloud_needs_captions`,
//     `cloud_up_to_date`) để UI nói rõ, thay vì lặng lẽ bỏ qua.
//  3. **Thứ tự đúng** — tải phụ đề trước, tải âm thanh sau (âm thanh nặng và
//     dễ hỏng mạng hơn), rồi mới đồng bộ tab Đọc và lưu đám mây (hai việc này
//     cần nội dung phụ đề đã nằm trên máy).

/// Một việc cần làm trong lượt "Tải & chuẩn bị".
enum YtPrepareStep {
  /// Tải phụ đề (.lrc) của video.
  downloadCaptions,

  /// Tải âm thanh.
  downloadAudio,

  /// Nạp phụ đề (+ âm thanh nếu có) vào tab Đọc.
  syncRead,

  /// Lưu bản sao phụ đề lên thư viện đám mây.
  cloudCopy,
}

class YtPreparePlan {
  const YtPreparePlan({
    required this.steps,
    required this.hasCaptions,
    required this.hasAudio,
    this.notes = const [],
  });

  final List<YtPrepareStep> steps;

  /// Trạng thái ĐÃ CÓ trên máy tại thời điểm lập kế hoạch (để UI hiện ✓).
  final bool hasCaptions;
  final bool hasAudio;

  /// Mã lý do những lựa chọn bị bỏ (UI tự dịch).
  final List<String> notes;

  bool get nothingToDo => steps.isEmpty;

  /// Trên máy đã đủ cả hai thứ để học (phụ đề + âm thanh).
  bool get alreadyComplete => hasCaptions && hasAudio;

  bool get willHaveCaptions =>
      hasCaptions || steps.contains(YtPrepareStep.downloadCaptions);
}

/// Lập kế hoạch từ lựa chọn của người dùng + trạng thái đã có trên máy.
YtPreparePlan buildYtPreparePlan({
  required bool hasCaptions,
  required bool hasAudio,
  required bool wantCaptions,
  required bool wantAudio,
  required bool wantSyncRead,
  required bool wantCloudCopy,

  /// Phụ đề hiện tại đã được lưu lên đám mây ở đúng phiên bản này.
  bool cloudUpToDate = false,
}) {
  final steps = <YtPrepareStep>[];
  final notes = <String>[];

  if (wantCaptions && !hasCaptions) {
    steps.add(YtPrepareStep.downloadCaptions);
  } else if (wantCaptions && hasCaptions) {
    notes.add('captions_already_saved');
  }

  if (wantAudio && !hasAudio) {
    steps.add(YtPrepareStep.downloadAudio);
  } else if (wantAudio && hasAudio) {
    notes.add('audio_already_saved');
  }

  // Hai việc sau đều cần nội dung phụ đề. Nếu người dùng KHÔNG chọn tải phụ
  // đề và máy cũng chưa có ⇒ nói rõ lý do thay vì đồng bộ một file rỗng.
  final captionsAvailable =
      hasCaptions || steps.contains(YtPrepareStep.downloadCaptions);

  if (wantSyncRead) {
    if (captionsAvailable) {
      steps.add(YtPrepareStep.syncRead);
    } else {
      notes.add('sync_needs_captions');
    }
  }

  if (wantCloudCopy) {
    if (!captionsAvailable) {
      notes.add('cloud_needs_captions');
    } else if (cloudUpToDate && !steps.contains(YtPrepareStep.downloadCaptions)) {
      notes.add('cloud_up_to_date');
    } else {
      steps.add(YtPrepareStep.cloudCopy);
    }
  }

  return YtPreparePlan(
    steps: steps,
    hasCaptions: hasCaptions,
    hasAudio: hasAudio,
    notes: notes,
  );
}

/// Đổi nội dung `.lrc` thành văn bản thường để lưu lên đám mây.
///
/// Vì sao bỏ mốc thời gian: thư viện đám mây (`TextLibraryService`) là văn bản
/// để đọc/dịch, không phải trình phát; `[01:23.45]` nằm trong câu sẽ bị đưa
/// vào bộ phân tích từ vựng và làm bẩn thống kê tần suất.
///
/// Dòng `[ti:...]`/`[ar:...]` (metadata LRC) cũng bị bỏ.
String ytPlainTextFromLrc(String lrc) {
  final out = <String>[];
  for (final raw in lrc.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    // Metadata: `[ti:Tên]`, `[ar:...]`, `[al:...]`, `[by:...]`
    if (RegExp(r'^\[(ti|ar|al|by|offset):').hasMatch(line)) continue;
    // Mốc thời gian: có thể có nhiều mốc liền nhau trên một dòng.
    var text = line;
    while (true) {
      final m = RegExp(r'^\[[0-9]{1,3}:[0-9]{2}(\.[0-9]{1,3})?\]').firstMatch(text);
      if (m == null) break;
      text = text.substring(m.end);
    }
    text = text.trim();
    if (text.isEmpty) continue;
    out.add(text);
  }
  return out.join('\n');
}
