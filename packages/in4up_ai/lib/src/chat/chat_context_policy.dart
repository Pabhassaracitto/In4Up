// packages/in4up_ai/lib/src/chat/chat_context_policy.dart
// Giới hạn context chat gửi xuống native (llama.cpp/GGUF).
//
// Vì sao cần lớp này (root cause AI-CHAT-01 #3):
//   * `in4up_ai_create` tạo context CỐ ĐỊNH 2048 token
//     (`AiNativeBindings.create(contextSize: 2048)`; C++
//     `context_params.n_ctx = max(512, n_ctx)`). Prompt dài hơn context ⇒
//     `llama_tokenize`/`llama_decode` fail ⇒ C++ trả chuỗi RỖNG ⇒ UI hiện
//     "Mình chưa tạo được câu trả lời cho tin nhắn này." — càng chat lâu càng
//     dễ dính vì lịch sử chat được nhét TOÀN BỘ vào prompt.
//   * `maxTokens` cố định (512) trên prompt dài cũng ăn hết chỗ trống còn lại
//     ⇒ JSON trả về bị cắt giữa chừng ⇒ parse fail.
//
// Cách xử lý: chỉ gửi vài tin MỚI NHẤT (không phải tin cũ nhất — bản cũ dùng
// `take(10)` nên context mãi là 10 tin đầu hội thoại), cắt mỗi tin quá dài,
// giới hạn tổng ký tự, rồi tính lại `maxTokens` theo chỗ còn trống.

import '../models/chat_message.dart';

class ChatContextPolicy {
  const ChatContextPolicy({
    this.maxHistoryMessages = 8,
    this.maxHistoryChars = 1500,
    this.maxMessageChars = 600,
    this.maxQuestionChars = 1500,
    this.contextTokens = 2048,
    this.reservedTokens = 96,
    this.charsPerToken = 3,
    this.minMaxTokens = 96,
    this.defaultMaxTokens = 512,
  });

  /// Policy mặc định cho chat Gemma trên máy yếu (context 2048 token).
  static const ChatContextPolicy defaults = ChatContextPolicy();

  /// Số tin tối đa lấy từ lịch sử (không tính tin đang hỏi).
  final int maxHistoryMessages;

  /// Tổng số ký tự tối đa của phần lịch sử trong prompt.
  final int maxHistoryChars;

  /// Cắt bớt một tin quá dài (một tin dán vào không được ăn hết context).
  final int maxMessageChars;

  /// Cắt bớt câu hỏi quá dài (dán cả đoạn văn vào ô chat).
  final int maxQuestionChars;

  /// Context native cố định (token) — xem `in4up_ai_create`.
  final int contextTokens;

  /// Chừa chỗ cho prompt schema + sai số tokenize.
  final int reservedTokens;

  /// Ước lượng thô: hỗn hợp Việt/Anh tokenize ~3 ký tự/token (tiếng Việt có
  /// thể tệ hơn, ~2 ký tự/token — [reservedTokens] + trần ký tự bên dưới đã
  /// chừa cho trường hợp xấu nhất).
  ///
  /// Kiểm tra ngân sách worst-case (2 ký tự/token):
  ///   maxHistoryChars 1500 + maxQuestionChars 1500 + schema ~260 = 3260 ký tự
  ///   ≈ 1630 token + reserved 96 + minMaxTokens 96 = 1822 < 2048 token ✓
  /// Với tỉ lệ 3 ký tự/token: ≈ 1087 token ⇒ còn 865 token trống, `maxTokens`
  /// được cấp tới trần 512 ⇒ tổng ≈ 1695 token ✓ không tràn context native.
  final int charsPerToken;

  /// Sàn cho `maxTokens`: prompt dài tới mức nào thì câu trả lời cũng phải đủ
  /// dài để viết JSON tối thiểu (không cắt giữa chừng).
  final int minMaxTokens;

  /// Trần `maxTokens` cho chat.
  final int defaultMaxTokens;

  /// Cắt bớt câu hỏi quá dài trước khi đưa vào prompt — prompt dài hơn
  /// context native ⇒ `llama_decode` fail ⇒ model trả về RỖNG.
  String clipQuestion(String text) {
    if (text.length <= maxQuestionChars) return text;
    return '${text.substring(0, maxQuestionChars)}…';
  }

  int estimateTokens(int chars) {
    if (chars <= 0) return 0;
    final divisor = charsPerToken <= 0 ? 3 : charsPerToken;
    return (chars / divisor).ceil();
  }

  /// Lấy các tin gần nhất (giữ thứ tự thời gian) vừa đủ số tin vừa đủ ký tự.
  ///
  /// Bỏ qua tin lỗi (bubble "AI xử lý quá lâu…" không phải ngữ cảnh hội thoại)
  /// và tin [current] (câu hỏi được gửi riêng trong trường text của prompt).
  List<ChatMessage> selectHistory(
    List<ChatMessage> messages, {
    ChatMessage? current,
  }) {
    final selected = <ChatMessage>[];
    var usedChars = 0;
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (current != null && identical(message, current)) continue;
      if (message.isError) continue;
      final text = message.text.trim();
      if (text.isEmpty) continue;
      if (selected.length >= maxHistoryMessages) break;
      final line = _line(message, text);
      if (usedChars + line.length > maxHistoryChars) {
        // Tin MỚI NHẤT không vừa ngân sách: giữ bản cắt ngắn của chính nó rồi
        // dừng — thà ngữ cảnh ngắn còn hơn không có ngữ cảnh nào.
        if (selected.isEmpty) {
          selected.add(_truncated(message, text, maxHistoryChars - usedChars));
        }
        break;
      }
      usedChars += line.length;
      selected.add(message);
    }
    return selected.reversed.toList(growable: false);
  }

  /// Ghép lịch sử thành chuỗi context cho prompt (định dạng cũ `ROLE: text`).
  String build(List<ChatMessage> messages, {ChatMessage? current}) {
    final history = selectHistory(messages, current: current);
    return history
        .map((m) {
          final text = m.text.trim();
          return _line(m, text.length > maxMessageChars
              ? _clip(text, maxMessageChars)
              : text);
        })
        .join('\n');
  }

  /// Số token còn trống cho phần sinh, theo ước lượng prompt.
  ///
  /// Trả về trong [minMaxTokens, requested] — không bao giờ vượt quá
  /// [defaultMaxTokens] để phần decode không tràn context native.
  int resolveMaxTokens({required int promptChars, int? requested}) {
    final want = requested ?? defaultMaxTokens;
    final capped = want > defaultMaxTokens ? defaultMaxTokens : want;
    final promptTokens = estimateTokens(promptChars);
    final room = contextTokens - reservedTokens - promptTokens;
    if (room <= minMaxTokens) return minMaxTokens;
    return room < capped ? room : capped;
  }

  String _line(ChatMessage message, String text) =>
      '${message.role.name.toUpperCase()}: $text';

  ChatMessage _truncated(ChatMessage message, String text, int budget) {
    // budget là số ký tự cho cả dòng "ROLE: text".
    final prefixLength = _line(message, '').length;
    final room = budget - prefixLength;
    return message.copyWith(text: _clip(text, room < 16 ? 16 : room));
  }

  String _clip(String text, int maxChars) {
    if (maxChars <= 0) return '';
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}…';
  }
}
