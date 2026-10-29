/// ═══════════════════════════════════════════════════════════════
/// CHAT GROUNDING — pipeline 6 bước theo mục 7 bàn giao
///
/// 1. Lấy excerpt hiện tại (đang đọc/nghe/từ đang xem)
/// 2. Query top-5 Evidence khác có cùng tag/topic + unit mastery thấp
/// 3. Đưa 2 nhóm trên vào prompt (KHÔNG đưa toàn bộ lịch sử/tài liệu)
/// 4. Model trả lời KÈM citations: [{evidenceId, quoteExcerpt}]
/// 5. Validator: quoteExcerpt phải là substring/near-match của
///    Evidence.excerpt — không khớp ⇒ cờ "unverified" + cảnh báo
/// 6. Citation hợp lệ luôn trỏ về evidenceId reopen được (locator)
///
/// TÊN GỌI (glossary mục 1): việc ghép ngữ cảnh này là "CONTEXT
/// INJECTION" — không phải RAG (không embedding, không vector DB).
///
/// Offline/mock (mục 7): OfflineQuoteFirstModel — chỉ trả lời bằng
/// quote trực tiếp từ evidence, KHÔNG tự sinh giải thích tự do.
///
/// Thuần chức năng, JSON-able; model là seam cắm được (GGUF/api sau này).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;

/// Số evidence liên quan tối đa đưa vào context (mục 7: "top-5").
const int kRelatedEvidenceLimit = 5;

/// Ngưỡng giao tháp từ cho near-match (validator bước 5).
const double kNearMatchWordOverlap = 0.8;

/// Topic của unit — seam cắm được (mục 7: "cùng tag/topic").
/// Trả null khi chưa có gán topic (fallback: cùng loại nguồn).
typedef TopicResolver = String? Function(String unitId);

/// Citation thô do model trả về (bước 4) — CHƯA được tin.
class RawCitation {
  final String evidenceId;
  final String quoteExcerpt;

  const RawCitation({
    required this.evidenceId,
    required this.quoteExcerpt,
  });

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'evidenceId': evidenceId, 'quoteExcerpt': quoteExcerpt};

  factory RawCitation.fromJson(Map<String, dynamic> json) => RawCitation(
        evidenceId: json['evidenceId'] as String,
        quoteExcerpt: json['quoteExcerpt'] as String,
      );
}

/// Mức độ xác minh của citation sau validator.
enum CitationVerdict { verified, nearMatch, unverified }

/// Citation đã xác minh — mang locator để UI nút "xem nguồn" (bước 6).
class VerifiedCitation {
  final String evidenceId;
  final String quoteExcerpt;
  final CitationVerdict verdict;
  final String note;

  /// Locator để reopen — có mặt khi verdict != unverified (bước 6, DoD).
  final EvidenceLocator locator;

  const VerifiedCitation({
    required this.evidenceId,
    required this.quoteExcerpt,
    required this.verdict,
    required this.note,
    required this.locator,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'evidenceId': evidenceId,
        'quoteExcerpt': quoteExcerpt,
        'verdict': verdict.name,
        'note': note,
        'locator': locator.toJson(),
      };
}

/// Vị ngữ cảnh được tiêm vào prompt (bước 3) — có chặn trên.
class GroundingContext {
  final Evidence current;
  final List<Evidence> related;

  const GroundingContext({
    required this.current,
    required this.related,
  });

  /// Dạng text tiêm vào prompt — CHỈ chứa các excerpt này (bước 3:
  /// không đưa toàn bộ lịch sử/tài liệu).
  String toInjectedPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('NGUỒN ĐANG MỞ [${current.evidenceId}]:');
    buffer.writeln('"${current.excerpt}"');
    buffer.writeln();
    if (related.isNotEmpty) {
      buffer.writeln('NGỮ CẢNH LIÊN QUAN:');
      for (final e in related) {
        buffer.writeln('- [${e.evidenceId}]: "${e.excerpt}"');
      }
    }
    buffer.writeln();
    buffer.write(
        'Trả lời câu hỏi dựa trên các nguồn trên. Mỗi ý phải kèm citation '
        'dạng [evidenceId] và quote gốc từ excerpt. Không bịa dẫn chứng.');
    return buffer.toString();
  }
}

/// Bước 2: chọn evidence liên quan — cùng topic (resolver) được ưu tiên,
/// kế đến unit mastery thấp; tie-break theo evidenceId (deterministic).
class GroundingContextBuilder {
  final TopicResolver? topicResolver;
  final Map<String, LearningState> learningStates;

  const GroundingContextBuilder({
    this.topicResolver,
    this.learningStates = const <String, LearningState>{},
  });

  bool _isLowMastery(String unitId) {
    final state = learningStates[unitId];
    if (state == null) return true; // chưa promote ⇒ mastery thấp
    return SkillDimension.values
        .any((d) => state.skill(d).interval < 7 || state.skill(d).repetitions < 2);
  }

  GroundingContext build({
    required Evidence current,
    required Iterable<Evidence> pool,
  }) {
    final resolver = topicResolver;
    final currentTopic =
        resolver == null ? null : resolver(current.unitId);
    final currentSource = current.sourceType;

    final candidates = <Evidence>[];
    for (final e in pool) {
      if (e.evidenceId == current.evidenceId) continue;
      candidates.add(e);
    }

    int affinity(Evidence e) {
      var score = 0;
      if (resolver != null &&
          currentTopic != null &&
          resolver(e.unitId) == currentTopic) {
        score += 2; // cùng tag/topic
      }
      if (e.sourceType == currentSource) {
        score += 1; // fallback: cùng loại nguồn
      }
      if (_isLowMastery(e.unitId)) {
        score += 1; // unit mastery thấp (mục 7)
      }
      return score;
    }

    candidates.sort((a, b) {
      final byAffinity = affinity(b).compareTo(affinity(a));
      if (byAffinity != 0) return byAffinity;
      return a.evidenceId.compareTo(b.evidenceId);
    });

    final related = candidates.take(kRelatedEvidenceLimit).toList();
    return GroundingContext(current: current, related: related);
  }
}

/// Bước 4: seam model. Cắm GGUF/api sau này; offline dùng bên dưới.
abstract class ChatModel {
  Future<ChatModelReply> reply({
    required GroundingContext context,
    required String question,
  });
}

class ChatModelReply {
  final String answerText;
  final List<RawCitation> citations;

  const ChatModelReply({
    required this.answerText,
    required this.citations,
  });
}

/// Offline/mock (mục 7): QUOTE-FIRST — chỉ dựng câu trả lời từ quote
/// thật trong context; KHÔNG tự sinh giải thích tự do.
class OfflineQuoteFirstModel implements ChatModel {
  const OfflineQuoteFirstModel();

  @override
  Future<ChatModelReply> reply({
    required GroundingContext context,
    required String question,
  }) async {
    final citations = <RawCitation>[
      RawCitation(
        evidenceId: context.current.evidenceId,
        quoteExcerpt: context.current.excerpt,
      ),
      for (final e in context.related)
        RawCitation(evidenceId: e.evidenceId, quoteExcerpt: e.excerpt),
    ];
    final buffer = StringBuffer();
    buffer.writeln('(Chế độ offline — chỉ trích dẫn nguyên văn nguồn.)');
    buffer.writeln('Ngữ cảnh cho câu hỏi "$question":');
    for (final c in citations) {
      buffer.writeln('- [${c.evidenceId}]: "${c.quoteExcerpt}"');
    }
    return ChatModelReply(
      answerText: buffer.toString(),
      citations: citations,
    );
  }
}

/// Chuẩn hóa để so near-match: thường hóa hoa, gộp khoảng trắng,
/// bỏ dấu câu đầu/cuối từ.
String _normalizeQuote(String raw) {
  final lowered = raw.toLowerCase();
  final collapsed = lowered.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.replaceAll(RegExp(r"[.,;:!?()'\[\]]"), '');
}

bool _isNearMatch(String quote, String excerpt) {
  final q = _normalizeQuote(quote);
  final e = _normalizeQuote(excerpt);
  if (q.isEmpty) return false;
  if (e.contains(q)) return true;
  final qWords = q.split(' ').toSet();
  final eWords = e.split(' ').toSet();
  var hits = 0;
  for (final w in qWords) {
    if (eWords.contains(w)) hits++;
  }
  return qWords.isNotEmpty && hits / qWords.length >= kNearMatchWordOverlap;
}

/// Bước 5: validator citation.
class CitationValidator {
  final Evidence Function(String evidenceId) lookup;

  const CitationValidator({required this.lookup});

  VerifiedCitation validate(RawCitation raw) {
    final Evidence evidence;
    try {
      evidence = lookup(raw.evidenceId);
    } catch (_) {
      return _unverified(raw, 'evidenceId không tồn tại');
    }
    final excerpt = evidence.excerpt;
    if (excerpt.contains(raw.quoteExcerpt) &&
        raw.quoteExcerpt.trim().isNotEmpty) {
      return VerifiedCitation(
        evidenceId: raw.evidenceId,
        quoteExcerpt: raw.quoteExcerpt,
        verdict: CitationVerdict.verified,
        note: 'khớp nguyên văn',
        locator: evidence.locator,
      );
    }
    if (_isNearMatch(raw.quoteExcerpt, excerpt)) {
      return VerifiedCitation(
        evidenceId: raw.evidenceId,
        quoteExcerpt: raw.quoteExcerpt,
        verdict: CitationVerdict.nearMatch,
        note: 'khớp gần đúng (chuẩn hóa khoảng trắng/dấu câu/hoa thường)',
        locator: evidence.locator,
      );
    }
    return _unverified(
        raw, 'quote không có trong excerpt của evidence này');
  }

  VerifiedCitation _unverified(RawCitation raw, String why) {
    return VerifiedCitation(
      evidenceId: raw.evidenceId,
      quoteExcerpt: raw.quoteExcerpt,
      verdict: CitationVerdict.unverified,
      note: why,
      locator: const EvidenceLocator(),
    );
  }
}

/// Kết quả bước 6 — sẵn sàng cho UI (nút "xem nguồn" theo locator).
class GroundedAnswer {
  final String answerText;
  final List<VerifiedCitation> citations;

  const GroundedAnswer({
    required this.answerText,
    required this.citations,
  });

  /// UI phải hiển thị cảnh báo khi true (mục 7 bước 5).
  bool get hasUnverified =>
      citations.any((c) => c.verdict == CitationVerdict.unverified);

  /// DoD Task 8: mọi citation ĐƯỢC TIN trỏ về evidenceId reopen được.
  List<VerifiedCitation> get reopenableCitations => [
        for (final c in citations)
          if (c.verdict != CitationVerdict.unverified) c
      ];
}

/// Orchestrator pipeline 6 bước.
class GroundedChatService {
  final ChatModel model;
  final GroundingContextBuilder contextBuilder;
  final CitationValidator validator;

  const GroundedChatService({
    required this.model,
    required this.contextBuilder,
    required this.validator,
  });

  Future<GroundedAnswer> answer({
    required Evidence current,
    required Iterable<Evidence> pool,
    required String question,
  }) async {
    final context =
        contextBuilder.build(current: current, pool: pool); // bước 1+2+3
    final reply = await model.reply(
      context: context,
      question: question,
    ); // bước 4
    final citations = [
      for (final raw in reply.citations) validator.validate(raw) // bước 5
    ]; // bước 6: citations gắn locator để reopen
    return GroundedAnswer(answerText: reply.answerText, citations: citations);
  }
}
