/// ═══════════════════════════════════════════════════════════════
/// TEXT PIPELINE — normalize + tokenize + segment (4 profile)
///
/// Handoff MVA v2.0 — Task 4:
///   "TextPipeline trong Background Isolate: normalize + tokenize
///    (Trie cho Việt) + 4 segment profile".
///
/// 4 profile: paragraph / sentence / clause / phrase (nhỏ dần granularity).
///
/// Toàn bộ hàm THUẦN (pure) — chạy được trong isolate lẫn main.
/// `kTextSplitterVersion` là nguồn cho `ProducerVersion.splitterVersion`
/// của Evidence (schema mục 2.2) — đổi hành vi tách ⇒ bump version.
///
/// Thuần dart:core + dart:convert — không import ngoài module text/.
/// ═══════════════════════════════════════════════════════════════
library;

import 'segmenter.dart';
import 'tokenizer.dart';
import 'vietnamese_trie.dart';

/// Version của bộ tách — ghi vào Evidence.producerVersion.splitterVersion.
const String kTextSplitterVersion = 'text-pipeline-v1';

/// 4 segment profile — mức granularity nhỏ dần.
enum SegmentProfile { paragraph, sentence, clause, phrase }

class PipelineRequest {
  final String text;
  final SegmentProfile profile;

  const PipelineRequest({required this.text, required this.profile});

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'text': text, 'profile': profile.name};

  factory PipelineRequest.fromJson(Map<String, dynamic> json) =>
      PipelineRequest(
        text: json['text'] as String,
        profile: SegmentProfile.values.firstWhere(
          (p) => p.name == json['profile'],
          orElse: () => throw FormatException(
              'SegmentProfile không hợp lệ: ${json['profile']}'),
        ),
      );
}

class PipelineResult {
  final String normalized;
  final String splitterVersion;
  final SegmentProfile profile;
  final List<Segment> segments;
  final List<Token> tokens;

  const PipelineResult({
    required this.normalized,
    required this.splitterVersion,
    required this.profile,
    required this.segments,
    required this.tokens,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'normalized': normalized,
        'splitterVersion': splitterVersion,
        'profile': profile.name,
        'segments': [for (final s in segments) s.toJson()],
        'tokens': [for (final t in tokens) t.toJson()],
      };

  factory PipelineResult.fromJson(Map<String, dynamic> json) =>
      PipelineResult(
        normalized: json['normalized'] as String,
        splitterVersion: json['splitterVersion'] as String,
        profile: SegmentProfile.values
            .firstWhere((p) => p.name == json['profile']),
        segments: [
          for (final s in (json['segments'] as List<dynamic>)
              .whereType<Map<String, dynamic>>())
            Segment.fromJson(s)
        ],
        tokens: [
          for (final t in (json['tokens'] as List<dynamic>)
              .whereType<Map<String, dynamic>>())
            Token.fromJson(t)
        ],
      );
}

class TextPipeline {
  TextPipeline._();

  /// Chuẩn hóa: NFC-safe, gộp space/tab TRONG dòng + trim MỖI DÒNG
  /// (không để space cuối dòng/đầu dòng), \n trở thành tối đa một dòng
  /// trống (\n\n giữ nguyên làm ranh giới đoạn), trim hai đầu.
  /// Offset của mọi Segment/Token tính trên KẾT QUẢ của hàm này.
  static String normalize(String raw) {
    final noSoftHyphen = raw.replaceAll(String.fromCharCode(0x00AD), '');
    final perLine = noSoftHyphen
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n');
    return perLine.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Xử lý toàn pipeline. [trie] nullable để test; mặc định dùng seed Việt.
  static PipelineResult process(
    PipelineRequest request, {
    VietnameseTrie? trie,
  }) {
    final normalized = normalize(request.text);
    final effectiveTrie = trie ?? VietnameseTrie.fromWords(kSeedVietnameseCompoundWords);

    final segments = switch (request.profile) {
      SegmentProfile.paragraph => TextSegmenter.paragraphs(normalized),
      SegmentProfile.sentence => TextSegmenter.sentences(normalized),
      SegmentProfile.clause => TextSegmenter.clauses(normalized),
      SegmentProfile.phrase => TextSegmenter.phrases(normalized),
    };

    return PipelineResult(
      normalized: normalized,
      splitterVersion: kTextSplitterVersion,
      profile: request.profile,
      segments: segments,
      tokens: TextTokenizer.tokenize(normalized, trie: effectiveTrie),
    );
  }
}
