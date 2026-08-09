// lib/features/translation/engines/dictionary_engine.dart
//
// STUB for Branch B — Hybrid Tier 1: Dictionary Tham chiếu (FTS)
// Branch B chỉ việc điền vào các TODO, không cần sửa TranslationService nhiều.
//
// Mục tiêu: tra chính xác 100% thuật ngữ Phật học trước khi fallback sang ML Kit / Gemma.
// Tham chiếu: docs/DICTIONARY_SPEC.md

import 'dart:async';
import 'translation_engine.dart';

/// Kết quả kèm nguồn tham chiếu (để UI hiện "Nguồn: MN 10 • Pali: satipaṭṭhāna")
class DictHit {
  final String term;
  final String translation;
  final String? pali;
  final String? han;
  final String? context;
  final String? source; // id canon hoặc glossary id, vd "mn10_satipatthana"
  final int priority; // 10 = core

  const DictHit({
    required this.term,
    required this.translation,
    this.pali,
    this.han,
    this.context,
    this.source,
    this.priority = 5,
  });
}

/// Tier 1 — Từ điển tham chiếu Phật học (Drift FTS5 hoặc Hive tạm)
/// Branch B implement theo spec docs/DICTIONARY_SPEC.md
class DictionaryEngine implements TranslationEngine {
  // TODO(Branch B): inject Drift/Hive loader
  // final DictionaryLoader _loader = DictionaryLoader();
  // final DictionaryFts _fts = DictionaryFts();

  @override
  String get name => 'Phật Học Từ Điển';

  @override
  String get id => 'dictionary';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => Duration.zero;

  @override
  Future<bool> isAvailable() async {
    // TODO(Branch B): return true khi Drift/Hive đã init và có >=1 entry
    // Ví dụ: return (await _loader.count()) > 0;
    return true; // stub: luôn available để TranslationService thử trước
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final sw = Stopwatch()..start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: name,
        responseTime: sw.elapsed,
      );
    }

    try {
      // ── 1. Exact match (ưu tiên) ───────────────────
      // TODO(Branch B): _fts.exactLookup(trimmed) hoặc Drift: SELECT * WHERE term_norm = ?
      final exact = await lookupExact(trimmed);
      if (exact != null) {
        sw.stop();
        // Trả kèm context để UI hiện tham chiếu, ví dụ: "niệm xứ (Tứ Niệm Xứ • MN 10)"
        final withRef = _formatWithRef(exact);
        return TranslationResult.success(
          original: text,
          translated: withRef,
          engine: name,
          responseTime: sw.elapsed,
        );
      }

      // ── 2. Trong câu: thay thế từng thuật ngữ (giữ cấu trúc câu) ───
      // TODO(Branch B): token hóa câu, thay thế token nào có trong dict
      // Ví dụ: "The nature of dukkha" → "The nature of khổ"
      // Nếu có thay thế, trả partial và để TranslationService quyết định có gọi tiếp Tier 2 không
      // Hiện tại stub: nếu không exact thì coi như miss để fallback
      final partial = await translateWithGlossaryTokens(trimmed);
      if (partial != null && partial != trimmed) {
        sw.stop();
        return TranslationResult.success(
          original: text,
          translated: partial,
          engine: name,
          responseTime: sw.elapsed,
        );
      }

      // ── 3. Miss → để TranslationService fallback sang ML Kit / Gemma ──
      sw.stop();
      return TranslationResult.failure(
        original: text,
        error: 'Dictionary miss: $trimmed',
        engine: name,
      );
    } catch (e) {
      sw.stop();
      return TranslationResult.failure(
        original: text,
        error: e.toString(),
        engine: name,
      );
    }
  }

  /// Tra chính xác 1 thuật ngữ (bỏ dấu, lower)
  /// Branch B: implement bằng Drift/Hive
  Future<DictHit?> lookupExact(String term) async {
    // TODO(Branch B): 
    // final norm = CanonTokenizer.stripDiacritics(term.toLowerCase().trim());
    // return await _loader.findByNorm(norm);
    
    // STUB tạm: dùng OfflineDictionary cũ để demo không vỡ build
    // Xóa khi đã có Drift
    // import '../data/offline_dictionary.dart';
    // return OfflineDictionary().lookup(term)?.let((t) => DictHit(term: term, translation: t));
    return null;
  }

  /// Thay thế từng token trong câu bằng glossary (giữ từ không có thì để nguyên)
  /// Trả null nếu không có token nào được thay
  Future<String?> translateWithGlossaryTokens(String sentence) async {
    // TODO(Branch B):
    // final tokens = CanonTokenizer.tokenizeKeepDiacritics(sentence);
    // var replaced = 0;
    // final out = tokens.map((tok) async {
    //   final hit = await lookupExact(tok);
    //   if (hit != null) { replaced++; return hit.translation; }
    //   return tok;
    // });
    // if (replaced == 0) return null;
    // return out.join(' ');
    return null;
  }

  /// Format kèm tham chiếu để UI hiện: "chánh niệm (sati • MN 10)"
  String _formatWithRef(DictHit hit) {
    // TODO(Branch B): có thể thêm toggle "hiện nguồn" trong settings
    // Hiện tại trả đơn giản: translation
    // Nếu muốn kèm nguồn: return "${hit.translation} (${hit.pali ?? ''} • ${hit.source ?? ''})".trim()
    return hit.translation;
  }

  /// Gợi ý autocomplete (cho UI search)
  Future<List<String>> suggest(String prefix, {int limit = 5}) async {
    // TODO(Branch B): _fts.suggest(prefix)
    return [];
  }

  /// Branch B: hàm helper để import csv/md vào Drift/Hive
  Future<void> importFromAssets() async {
    // TODO(Branch B): await DictionaryLoader.importFromAssets();
  }
}

// ── VÍ DỤ GLOSSARY (Branch B copy vào assets/dictionary/glossary_phathoc.csv) ──
// term,translation,pali,han,context,priority,source
// dukkha,khổ,dukkha,苦,Khổ đế,10,mn10
// satipatthana,niệm xứ,satipaṭṭhāna,念处,Tứ Niệm Xứ,10,mn10
// anicca,vô thường,anicca,無常,Tam pháp ấn,10,dhammapada_001
// mindfulness,chánh niệm,sati,正念,Bát Chánh Đạo,9,mn10
// samadhi,định,samādhi,定,Bát Chánh Đạo,9,sn56_11
