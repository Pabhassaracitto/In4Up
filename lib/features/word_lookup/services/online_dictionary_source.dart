// lib/features/word_lookup/services/online_dictionary_source.dart
//
// WORD-INSIGHT-001 — Nguồn tra từ TRÊN MẠNG (ưu tiên đầu tiên của waterfall).
//
// Vì sao mạng đứng trước: máy gần như không có sẵn IPA/nghĩa cho từ hiếm
// trong PDF. Gọi 1 API từ điển mở (không cần API key) rồi mới rơi xuống MDX
// đã import và cuối cùng là AI/offline — đúng yêu cầu của người sở hữu.
//
// API: https://dictionaryapi.dev (English, miễn phí, không key). Trả về
// phonetic + partOfSpeech + definitions/examples. Lỗi mạng / 404 / JSON lạ
// ⇒ `null` (KHÔNG ném) để waterfall đi tiếp.

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Một định nghĩa (kèm ví dụ) từ API mạng.
class OnlineDictSense {
  final String definition;
  final String? example;

  const OnlineDictSense({required this.definition, this.example});
}

/// Nhóm định nghĩa theo loại từ.
class OnlineDictMeaning {
  final String? partOfSpeech;
  final List<OnlineDictSense> senses;

  const OnlineDictMeaning({
    this.partOfSpeech,
    this.senses = const <OnlineDictSense>[],
  });
}

/// Kết quả tra mạng cho một từ.
class OnlineDictEntry {
  final String word;
  final String? phonetic;
  final String? audioUrl;
  final List<OnlineDictMeaning> meanings;

  const OnlineDictEntry({
    required this.word,
    this.phonetic,
    this.audioUrl,
    this.meanings = const <OnlineDictMeaning>[],
  });

  bool get isEmpty => meanings.isEmpty && (phonetic ?? '').isEmpty;

  List<OnlineDictSense> get senses => <OnlineDictSense>[
        for (final meaning in meanings) ...meaning.senses,
      ];

  String? get primaryPartOfSpeech {
    for (final meaning in meanings) {
      final pos = (meaning.partOfSpeech ?? '').trim();
      if (pos.isNotEmpty) return pos;
    }
    return null;
  }

  /// Nghĩa tiếng Anh ngắn (1–2 định nghĩa đầu) để dịch sang ngôn ngữ đích.
  String englishSummary({int maxSenses = 2, int maxChars = 240}) {
    final parts = <String>[];
    for (final sense in senses) {
      if (parts.length >= maxSenses) break;
      final text = sense.definition.trim();
      if (text.isEmpty) continue;
      parts.add(text);
    }
    if (parts.isEmpty) return '';
    final joined = parts.join('; ');
    if (joined.length <= maxChars) return joined;
    return '${joined.substring(0, maxChars).trimRight()}…';
  }

  String? get primaryExample {
    for (final sense in senses) {
      final example = (sense.example ?? '').trim();
      if (example.isNotEmpty) return example;
    }
    return null;
  }
}

/// Client mỏng cho API từ điển mở.
class OnlineDictionarySource {
  OnlineDictionarySource._();

  static const String endpointBase =
      'https://api.dictionaryapi.dev/api/v2/entries/en/';

  static const String userAgent =
      'In4Up/1.4 (language learning app; word insight) '
      '+https://github.com/Pabhassaracitto/In4Up';

  /// Timeout ngắn: sheet PDF đang mở, người dùng không chờ lâu.
  static Duration timeout = const Duration(seconds: 4);

  /// Seam test — không gọi mạng thật (CI sandbox không có egress).
  static Future<OnlineDictEntry?> Function(String word)? lookupOverride;

  static void resetForTest() {
    lookupOverride = null;
    timeout = const Duration(seconds: 4);
  }

  static Future<OnlineDictEntry?> lookup(
    String word, {
    http.Client? client,
  }) async {
    final query = word.trim().toLowerCase();
    if (query.isEmpty) return null;
    if (lookupOverride != null) return lookupOverride!(query);

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('$endpointBase${Uri.encodeComponent(query)}');
      final response = await httpClient.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': userAgent,
        },
      ).timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseJson(utf8.decode(response.bodyBytes));
    } catch (error) {
      debugPrint('[WordInsight] online lookup "$query" lỗi: $error');
      return null;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// Parse phản hồi dictionaryapi.dev. Public để test parser bằng JSON mẫu.
  static OnlineDictEntry? parseJson(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;

    var word = '';
    String? phonetic;
    String? audioUrl;
    final meanings = <OnlineDictMeaning>[];
    final seenPoS = <String>{};

    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, Object?>.from(item);
      if (word.isEmpty) {
        word = (map['word'] ?? '').toString();
      }
      phonetic ??= _firstNonEmpty(<Object?>[map['phonetic']]);
      final phonetics = map['phonetics'];
      if (phonetics is List) {
        for (final variant in phonetics) {
          if (variant is! Map) continue;
          phonetic ??= _firstNonEmpty(<Object?>[variant['text']]);
          final audio = (variant['audio'] ?? '').toString().trim();
          if (audio.isNotEmpty && audioUrl == null) audioUrl = audio;
        }
      }

      final rawMeanings = map['meanings'];
      if (rawMeanings is! List) continue;
      for (final rawMeaning in rawMeanings) {
        if (rawMeaning is! Map) continue;
        final pos = (rawMeaning['partOfSpeech'] ?? '').toString().trim();
        final senses = <OnlineDictSense>[];
        final rawDefinitions = rawMeaning['definitions'];
        if (rawDefinitions is List) {
          for (final rawDefinition in rawDefinitions) {
            if (rawDefinition is! Map) continue;
            final definition =
                (rawDefinition['definition'] ?? '').toString().trim();
            if (definition.isEmpty) continue;
            final example =
                (rawDefinition['example'] ?? '').toString().trim();
            senses.add(OnlineDictSense(
              definition: definition,
              example: example.isEmpty ? null : example,
            ));
            if (senses.length >= 4) break;
          }
        }
        if (senses.isEmpty) continue;
        // Một số từ có nhiều entry cùng partOfSpeech → gộp thay vì lặp.
        if (seenPoS.add(pos)) {
          meanings.add(OnlineDictMeaning(
            partOfSpeech: pos.isEmpty ? null : pos,
            senses: senses,
          ));
        }
        if (meanings.length >= 3) break;
      }
    }

    if (word.isEmpty || meanings.isEmpty) return null;
    return OnlineDictEntry(
      word: word,
      phonetic: phonetic,
      audioUrl: audioUrl,
      meanings: meanings,
    );
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
