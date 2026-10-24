// lib/features/iconize/engine/iconize_lemmatizer.dart
//
// ICONIZE-001b — lemmatizer nhẹ cho tiếng Anh: tra bảng bất quy tắc TRƯỚC
// (assets/iconize/irregular_lemmas.json), rồi mới áp luật đuôi
// (-ies/-es/-s/-ing/-ed). Không model, không mạng — thuần luật + bảng.
//
// `isKnown` (thường là ConcretenessTable.contains) giúp chọn dạng gốc đúng:
// making → mak? make? → chọn dạng CÓ trong bảng concreteness.

import 'dart:convert';

class IconizeLemmatizer {
  final Map<String, String> _irregular;

  IconizeLemmatizer(Map<String, String> irregular)
      : _irregular = Map.unmodifiable(irregular);

  /// Nguồn: nội dung irregular_lemmas.json (map phẳng dạng→lemma).
  factory IconizeLemmatizer.fromJsonString(String jsonString) {
    final raw = json.decode(jsonString) as Map<String, dynamic>;
    return IconizeLemmatizer(raw.map((k, v) => MapEntry(k, v as String)));
  }

  int get irregularCount => _irregular.length;

  /// [word] phải đã lowercase. [isKnown] trả true nếu từ có trong từ điển
  /// tham chiếu (dùng để phân xử -e bị cắt / phụ âm đôi).
  String lemma(String word, {bool Function(String word)? isKnown}) {
    final known = isKnown ?? (_) => false;
    final irregular = _irregular[word];
    if (irregular != null) return irregular;
    // Từ đã là lemma trong từ điển tham chiếu → giữ nguyên ("glass",
    // "bus" không bị cắt s).
    if (known(word)) return word;

    // -ies → y (babies → baby), cần gốc ≥ 2 ký tự.
    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    // -ches/-shes/-sses/-xes/-zes/-oes → bỏ "es" (catches → catch).
    if (word.length > 4 &&
        (word.endsWith('ches') ||
            word.endsWith('shes') ||
            word.endsWith('sses') ||
            word.endsWith('xes') ||
            word.endsWith('zes') ||
            word.endsWith('oes'))) {
      return word.substring(0, word.length - 2);
    }
    // -s thường (cats → cat); tránh -ss/-us/-is (glass, bus, basis).
    if (word.endsWith('s') &&
        word.length > 3 &&
        !word.endsWith('ss') &&
        !word.endsWith('us') &&
        !word.endsWith('is')) {
      return word.substring(0, word.length - 1);
    }
    // -ing (running → run, making → make).
    if (word.endsWith('ing') && word.length > 5) {
      return _stripSuffix(word, 3, known);
    }
    // -ed (jumped → jump, saved → save, stopped → stop).
    if (word.endsWith('ed') && word.length > 4) {
      return _stripSuffix(word, 2, known);
    }
    return word;
  }

  String _stripSuffix(String word, int n, bool Function(String) known) {
    final base = word.substring(0, word.length - n);
    if (known(base)) return base;
    // saved → sav + e = save.
    if (known('${base}e')) return '${base}e';
    // stopped → stopp → stop (bỏ phụ âm đôi).
    if (base.length > 2 && base[base.length - 1] == base[base.length - 2]) {
      final undoubled = base.substring(0, base.length - 1);
      if (known(undoubled)) return undoubled;
    }
    return base;
  }
}
