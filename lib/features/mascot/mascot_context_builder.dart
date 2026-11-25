// lib/features/mascot/mascot_context_builder.dart
//
// MASCOT-003 — Builder ngữ cảnh theo tab cho linh vật Sara (PLAN-050 §5/§8,
// khuôn `UnderstandAiContext`: bó ký tự, cắt ở biên câu).
//
// THUẦN DART — `MascotContextData` là dữ liệu phẳng do caller (main_shell) thu
// từ provider thật (Player/Text/Vocabulary/Focus); builder chỉ ghép chuỗi và
// cắt theo ngân sách. Prompt là NỘI DUNG gửi cho AI (giống prompt coach Hiểu)
// — KHÔNG đưa vào catalog i18n (rule #5 AGENTS.md).

/// Ngân sách ký tự cho KHỐI NGỮ CẢNH APP (không gồm system prompt) — THẤP
/// hơn coach Hiểu vì mascot hỏi đáp ngắn, không cần cả tài liệu (PLAN-050 §11).
const int kMascotContextMaxChars = 1200;

/// Ngân sách riêng cho phần trích tài liệu đang mở.
const int kMascotExcerptMaxChars = 500;

/// Trần TỔNG của oneShotContext gửi model = system prompt (persona + danh
/// sách hành động — nội dung AI, dài ~2k) + khối ngữ cảnh. Trần này chỉ là
/// cầu an toàn: nếu prompt một mình đã vượt trần thì giữ nguyên prompt và bỏ
/// khối ngữ cảnh (persona quan trọng hơn dữ liệu).
const int kMascotOneShotMaxChars = 3600;

/// Dữ liệu ngữ cảnh một phiên chat với Sara — caller thu từ provider thật,
/// không hardcode (PLAN-050 §6.1).
class MascotContextData {
  /// Nhãn bề mặt đang đứng (đÃ dịch ở tầng UI) — vd 'Trang chủ',
  /// 'Nghe · Nói', 'Đọc · Viết'.
  final String surface;

  final String? documentTitle;

  /// Trích đoạn tài liệu đang mở — caller cắt sẵn hay gửi nguyên văn đều được
  /// (builder cắt lại theo [kMascotExcerptMaxChars] ở biên câu).
  final String? documentExcerpt;

  final String? audioTitle;

  final int dueWordCount;

  final int streakDays;

  /// Đang phát audio hay không — Sara tránh gợi ý khi đang phát (§6.1).
  final bool isPlaying;

  const MascotContextData({
    required this.surface,
    this.documentTitle,
    this.documentExcerpt,
    this.audioTitle,
    this.dueWordCount = 0,
    this.streakDays = 0,
    this.isPlaying = false,
  });
}

/// Cắt [text] tối đa [maxChars] ký tự, ưu tiên kết thúc ở BIÊN CÂU (dấu . ! ?
/// xuống dòng). Không bao giờ cắt giữa từ: nếu không tìm thấy biên câu trong
/// cửa sổ nhìn lùi, cắt ở khoảng trắng gần nhất.
String truncateAtSentenceBoundary(String text, int maxChars) {
  final cleaned = text.trim();
  if (cleaned.length <= maxChars) return cleaned;
  final window = cleaned.substring(0, maxChars);
  for (var i = maxChars - 1; i >= maxChars - 80 && i > 0; i--) {
    final c = window[i];
    if (c == '.' || c == '!' || c == '?' || c == '\n') {
      return window.substring(0, i + 1).trim();
    }
  }
  final space = window.lastIndexOf(' ');
  if (space > 0) return window.substring(0, space).trim();
  return window.trim();
}

/// Khối ngữ cảnh «hiện tại» — chỉ dữ liệu thật, mục không có thì bỏ hẳn.
String buildMascotContextBlock(MascotContextData data) {
  final buffer = StringBuffer();
  buffer.writeln('[NGỮ CẢNH APP HIỆN TẠI]');
  buffer.writeln('- Bề mặt người dùng đang đứng: ${data.surface}');
  if (data.documentTitle != null && data.documentTitle!.trim().isNotEmpty) {
    buffer.writeln('- Tài liệu đang mở: ${data.documentTitle!.trim()}');
  }
  final excerpt = data.documentExcerpt?.trim() ?? '';
  if (excerpt.isNotEmpty) {
    final cut = truncateAtSentenceBoundary(excerpt, kMascotExcerptMaxChars);
    buffer.writeln('- Trích tài liệu (có thể cắt cụt): "$cut"');
  }
  if (data.audioTitle != null && data.audioTitle!.trim().isNotEmpty) {
    buffer.writeln('- Bài nghe hiện tại: ${data.audioTitle!.trim()}');
  }
  buffer.writeln('- Số từ đến hạn ôn: ${data.dueWordCount}');
  buffer.writeln('- Chuỗi ngày học liên tiếp: ${data.streakDays}');
  buffer.writeln('- Audio đang phát: ${data.isPlaying ? "có" : "không"}');
  return buffer.toString().trim();
}

/// Ghép ngữ cảnh đầy đủ gửi kèm MỘT lượt hỏi (dùng `oneShotContext` của
/// `AiServiceFacade.sendMessage` — PSRC-264: không tái đính các lượt sau).
///
/// Trần: tổng ≤ [kMascotOneShotMaxChars]; khối ngữ cảnh tự giới hạn ≤
/// [kMascotContextMaxChars]. Prompt một mình vượt trần ⇒ giữ prompt, bỏ khối
/// (không bao giờ cắt persona giữa chừng).
String buildMascotOneShotContext(
  MascotContextData data, {
  required String systemPrompt,
}) {
  final block = buildMascotContextBlock(data);
  if (systemPrompt.length > kMascotOneShotMaxChars - 2) {
    return systemPrompt;
  }
  final combined = '$systemPrompt\n\n$block';
  if (combined.length <= kMascotOneShotMaxChars) return combined;
  final budget =
      (kMascotOneShotMaxChars - systemPrompt.length - 2)
          .clamp(0, kMascotContextMaxChars);
  if (budget <= 0) return systemPrompt;
  final cut = truncateAtSentenceBoundary(block, budget);
  return '$systemPrompt\n\n$cut';
}
