// lib/features/mascot/mascot_reply_parser.dart
//
// MASCOT-003 — Parser câu trả lời của model để bóc hành động (PLAN-050 §5,
// ADR-0036 D2). "Khoan dung": model free (openrouter/free) hay lệch format —
// parser chấp nhận 3 dạng, sai hết thì coi như CHỈ LỜI NÓI (không thực thi gì
// — an toàn là mặc định).
//
// Dạng được chấp nhận (ưu tiên từ trên xuống):
//   1. Dòng riêng `[[action:<id>]]` hoặc `<<action:<id>>>` — giao thức chính
//      (model nhỏ viết dòng này đáng tin hơn JSON đầy đủ).
//   2. JSON một khối `{"say": "...", "action": {"id": "..."}}` — fenced
//      ```json``` hoặc nguyên văn bắt đầu bằng `{` (kể cả without say).
//   3. Chỉ văn bản ⇒ say = nguyên văn, action = null.
//
// THUẦN DART — không import Flutter.

import 'dart:convert';

class MascotParsedReply {
  /// Phần lời nói hiển thị cho người dùng (đã bỏ dòng action/JSON wrapper).
  final String say;

  /// Id hành động model yêu cầu (CHƯA kiểm registry — caller phải tra
  /// `MascotIntentRegistry.byId` trước khi thực thi).
  final String? actionId;

  const MascotParsedReply(this.say, this.actionId);
}

final RegExp _directiveExp =
    RegExp(r'\[\[action:\s*([a-zA-Z0-9_]+)\s*\]\]|<<action:\s*([a-zA-Z0-9_]+)\s*>>');

MascotParsedReply parseMascotReply(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const MascotParsedReply('', null);

  // 1) Dòng directive [[action:id]] / <<action:id>>.
  final directive = _directiveExp.firstMatch(text);
  if (directive != null) {
    final id = directive.group(1) ?? directive.group(2);
    var say = text.replaceFirst(directive, '').trim();
    say = _stripJsonFence(say);
    return MascotParsedReply(_cleanSay(say), (id == null || id.isEmpty) ? null : id);
  }

  // 2) JSON fenced ```json ...``` hoặc nguyên văn object.
  final jsonCandidate = _extractJsonCandidate(text);
  if (jsonCandidate != null) {
    try {
      final decoded = jsonDecode(jsonCandidate);
      if (decoded is Map) {
        final say = (decoded['say'] ?? decoded['reply'] ?? decoded['text'] ?? '')
            .toString()
            .trim();
        final action = decoded['action'];
        String? actionId;
        if (action is Map) {
          actionId = (action['id'] ?? '').toString().trim();
        } else if (action is String) {
          actionId = action.trim();
        }
        if (say.isNotEmpty) {
          return MascotParsedReply(say, (actionId == null || actionId.isEmpty) ? null : actionId);
        }
        // JSON chỉ có action, không lời — nói rỗng, vẫn cho thực thi.
        if (actionId != null && actionId.isNotEmpty) {
          return const MascotParsedReply('', null).copyWith(actionId: actionId);
        }
      }
    } catch (_) {
      // JSON hỏng ⇒ rơi xuống coi là văn bản (không thực thi gì).
    }
  }

  // 3) Văn bản thuần.
  return MascotParsedReply(_cleanSay(_stripJsonFence(text)), null);
}

extension on MascotParsedReply {
  MascotParsedReply copyWith({String? actionId}) =>
      MascotParsedReply(say, actionId ?? this.actionId);
}

/// Bỏ fence ```json ... ``` nếu model bọc JSON trong fence nhưng parser đã
/// bóc directive trước đó.
String _stripJsonFence(String say) {
  final fence = RegExp(r'^```[a-zA-Z]*\s*|\s*```$');
  return say.replaceAll(fence, '').trim();
}

/// Bỏ phần giải thích quanh dòng action dư (model đôi khi lặp lại dòng
/// [[action:...]] nhiều lần — chỉ dòng ĐẦU là directive, phần sau là rác).
String _cleanSay(String say) {
  var cleaned = say.replaceAll(_directiveExp, '').trim();
  // Bỏ dòng JSON thô còn sót nếu model vừa nói vừa dán JSON.
  if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
    return cleaned;
  }
  return cleaned;
}

/// Trả về chuỗi JSON candidate nếu [text] "trông như" JSON: fenced block hoặc
/// bắt đầu bằng `{` và kết thúc bằng `}`.
String? _extractJsonCandidate(String text) {
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
  final m = fence.firstMatch(text);
  if (m != null) {
    final inner = m.group(1)?.trim() ?? '';
    if (inner.startsWith('{')) return inner;
  }
  if (text.startsWith('{') && text.endsWith('}')) return text;
  // JSON ở GIỮA lời nói (model nói rồi dán JSON) — thử khối {...} cuối cùng.
  final start = text.lastIndexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    final candidate = text.substring(start, end + 1);
    if (candidate.contains('"action"') || candidate.contains('"say"')) {
      return candidate;
    }
  }
  return null;
}
