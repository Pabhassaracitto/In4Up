// lib/features/understand_ai/understand_ai_context.dart
//
// I4U — Prompt Agent 2: AI Coach trong tab Hiểu.
//
// Ngữ cảnh tối giản gửi cho AI khi người dùng bấm "Hỏi AI về đoạn này":
//   - selectedText   : câu người dùng đang hỏi (dòng hiện tại hoặc dòng họ chọn)
//   - surroundingText: vài dòng quanh câu đó (để AI hiểu ngữ cảnh)
//   - recentText     : cửa sổ "đoạn vừa nghe" (kết thúc ở dòng đang phát)
//   - currentLineIndex / focusLineIndex / sourceTitle / learningMode
//
// QUY TẮC RIÊNG TƯ (nói rõ cho người review):
//   - Context CHỈ chứa văn bản. Không có audio path, không có byte ghi âm,
//     không có lịch sử học — không gì để "tự động upload".
//   - Mọi cửa sổ văn bản đều bị cắt theo ngân sách ký tự để không bao giờ
//     gửi cả tài liệu.
//   - Class này không import provider hay Flutter — thuần dữ liệu, test được
//     bằng unit test thường.

/// Hai mode luyện tập chính của tab Hiểu. AI là *action*, không phải mode
/// thứ ba — enum này chỉ mô tả mode người dùng đang đứng để AI ctx kèm theo.
enum UnderstandLearningMode {
  /// Tab "Đồng bộ" — lyrics chạy theo audio.
  sync,

  /// Tab "Shadowing" — luyện nói theo đoạn loop.
  shadowing,
}

/// Ngữ cảnh gửi cho trợ lý AI hiểu bài.
class UnderstandAiContext {
  /// Câu người dùng đang hỏi. Null khi chưa phát/chọn dòng nào.
  final String? selectedText;

  /// Vài dòng quanh [selectedText] (không gồm chính câu đó).
  final String? surroundingText;

  /// "Đoạn vừa nghe" — tối đa [UnderstandAiContext.recentLineCount] dòng
  /// không rỗng tính ngược từ dòng đang phát.
  final String? recentText;

  /// Dòng audio đang phát (0-based). Null khi chưa phát.
  final int? currentLineIndex;

  /// Dòng người dùng đang tập trung hỏi (0-based) — có thể khác dòng đang
  /// phát nếu họ bấm ◀ ▶ trong sheet. Null khi không có.
  final int? focusLineIndex;

  /// Tên bài/tài liệu đang mở (nếu provider có).
  final String? sourceTitle;

  /// Mode Đồng bộ / Shadowing lúc mở trợ lý.
  final UnderstandLearningMode learningMode;

  /// Ngôn ngữ giải thích mong muốn — để trống nếu hệ thống chưa có cấu hình.
  final String? targetLanguage;

  /// Trình độ người học — để trống nếu hệ thống chưa có cấu hình.
  final String? learnerLevel;

  const UnderstandAiContext({
    this.selectedText,
    this.surroundingText,
    this.recentText,
    this.currentLineIndex,
    this.focusLineIndex,
    this.sourceTitle,
    this.learningMode = UnderstandLearningMode.sync,
    this.targetLanguage,
    this.learnerLevel,
  });

  /// Có văn bản để hỏi hay không (quick action nào cần text sẽ dựa vào đây).
  bool get hasText =>
      (selectedText != null && selectedText!.isNotEmpty) ||
      (recentText != null && recentText!.isNotEmpty);

  /// Ngân sách ký tự — chống gửi cả tài liệu xuống AI.
  static const int selectedTextMaxLength = 600;
  static const int surroundingTextMaxLength = 1200;
  static const int recentTextMaxLength = 1600;

  /// Số dòng quanh câu đang chọn đưa vào surroundingText.
  static const int surroundingSpan = 2;

  /// Số dòng tối đa của "đoạn vừa nghe".
  static const int recentLineCount = 5;

  /// Dựng context từ danh sách dòng lyric (chỉ text thuần).
  ///
  /// [currentLineIndex] là dòng audio đang phát; [focusLineIndex] là dòng
  /// người dùng chọn (mặc định -1 = theo dòng đang phát). Mọi index nằm
  /// ngoài [lines] đều được bỏ qua an toàn.
  factory UnderstandAiContext.fromLineTexts({
    required List<String> lines,
    int currentLineIndex = -1,
    int focusLineIndex = -1,
    String? sourceTitle,
    UnderstandLearningMode learningMode = UnderstandLearningMode.sync,
    String? targetLanguage,
    String? learnerLevel,
  }) {
    final lineCount = lines.length;
    final current = _validIndex(currentLineIndex, lineCount);
    final focus = _validIndex(focusLineIndex, lineCount) ?? current;

    final selectedText = _clip(
      focus == null ? null : _cleanLine(lines[focus]),
      selectedTextMaxLength,
    );
    final surroundingText = focus == null
        ? null
        : _clip(
            _joinLines(
              _window(
                lines,
                focus - surroundingSpan,
                focus + surroundingSpan,
                skipIndex: focus,
              ),
            ),
            surroundingTextMaxLength,
          );
    // "Đoạn vừa nghe" neo vào dòng đang phát; nếu audio chưa chạy thì neo
    // vào dòng người dùng đang chọn.
    final recentAnchor = current ?? focus;
    final recentText = recentAnchor == null
        ? null
        : _clip(
            _joinLines(
              _window(
                lines,
                recentAnchor - recentLineCount + 1,
                recentAnchor,
              ),
            ),
            recentTextMaxLength,
          );

    return UnderstandAiContext(
      selectedText: selectedText,
      surroundingText: surroundingText,
      recentText: recentText,
      currentLineIndex: current,
      focusLineIndex: focus,
      sourceTitle: _cleanLine(sourceTitle),
      learningMode: learningMode,
      targetLanguage: _cleanLine(targetLanguage),
      learnerLevel: _cleanLine(learnerLevel),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  static int? _validIndex(int index, int lineCount) {
    if (index < 0 || index >= lineCount) return null;
    return index;
  }

  static String? _cleanLine(String? text) {
    if (text == null) return null;
    final cleaned = text.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Lấy các dòng trong [start, end] (kể cả âm), bỏ dòng rỗng và dòng
  /// [skipIndex] (chính là câu đã nằm trong selectedText).
  static List<String> _window(
    List<String> lines,
    int start,
    int end, {
    int? skipIndex,
  }) {
    final result = <String>[];
    for (var i = start; i <= end; i++) {
      if (i < 0 || i >= lines.length) continue;
      if (skipIndex != null && i == skipIndex) continue;
      final cleaned = _cleanLine(lines[i]);
      if (cleaned != null) result.add(cleaned);
    }
    return result;
  }

  static String? _joinLines(List<String> lines) {
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  static String? _clip(String? text, int maxLength) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }
}
