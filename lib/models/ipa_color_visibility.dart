// lib/models/ipa_color_visibility.dart
//
// READ-IPA-006 (P1): Panel màu IPA tương tác trong Read Mode.
//
// Tách khỏi [IpaDisplayMode] (chế độ hiển thị) và master toggle `ipaColorByType`
// (READ-IPA-004): đây là lớp "ẩn RIÊNG từng LOẠI màu" — mặc định tất cả BẬT,
// người dùng tắt loại nào thì loại đó không render nữa.
//
// Không đụng bảng POS/CEFR (ColorMode) — hai ngữ nghĩa khác nhau (ADR-0005).

import 'dart:convert';


class IpaColorVisibility {
  /// Nguyên âm (vàng).
  final bool vowels;

  /// Phụ âm (sky-blue).
  final bool consonants;

  /// Đôi nguyên âm (tím).
  final bool diphthongs;

  /// Trọng âm `ˈ`/`ˌ` (amber đậm).
  final bool stress;

  /// Nối âm C→V giữa hai từ (orange) — READ-IPA-006 P2.
  final bool linking;

  /// Từ/cụm được nhấn trong câu (overline) — READ-IPA-006 P3.
  final bool stressWords;

  const IpaColorVisibility({
    this.vowels = true,
    this.consonants = true,
    this.diphthongs = true,
    this.stress = true,
    this.linking = true,
    this.stressWords = true,
  });

  /// Mặc định: tất cả bật (đúng yêu cầu "mặc định là bật hết").
  static const IpaColorVisibility all = IpaColorVisibility();

  /// Ít nhất 1 loại còn bật → còn gì để tô màu.
  bool get anyVisible =>
      vowels || consonants || diphthongs || stress || linking || stressWords;

  /// Loại nào bị ẩn (để panel hiển thị nút "Bật lại tất cả").
  bool get hasHidden =>
      !vowels || !consonants || !diphthongs || !stress || !linking || !stressWords;

  IpaColorVisibility copyWith({
    bool? vowels,
    bool? consonants,
    bool? diphthongs,
    bool? stress,
    bool? linking,
    bool? stressWords,
  }) {
    return IpaColorVisibility(
      vowels: vowels ?? this.vowels,
      consonants: consonants ?? this.consonants,
      diphthongs: diphthongs ?? this.diphthongs,
      stress: stress ?? this.stress,
      linking: linking ?? this.linking,
      stressWords: stressWords ?? this.stressWords,
    );
  }

  Map<String, dynamic> toJson() => {
        'vowels': vowels,
        'consonants': consonants,
        'diphthongs': diphthongs,
        'stress': stress,
        'linking': linking,
        'stressWords': stressWords,
      };

  factory IpaColorVisibility.fromJson(Map<String, dynamic> json) {
    bool read(String key) =>
        json[key] is bool
            ? json[key] as bool
            : IpaColorVisibility.all.toJson()[key] as bool;
    return IpaColorVisibility(
      vowels: read('vowels'),
      consonants: read('consonants'),
      diphthongs: read('diphthongs'),
      stress: read('stress'),
      linking: read('linking'),
      stressWords: read('stressWords'),
    );
  }

  /// Dựng từ JSON string (rỗng/lỗi → mặc định bật hết).
  static IpaColorVisibility fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return IpaColorVisibility.all;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return IpaColorVisibility.fromJson(decoded);
    } catch (_) {
      return IpaColorVisibility.all;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IpaColorVisibility &&
          other.vowels == vowels &&
          other.consonants == consonants &&
          other.diphthongs == diphthongs &&
          other.stress == stress &&
          other.linking == linking &&
          other.stressWords == stressWords;

  @override
  int get hashCode => Object.hash(
        vowels,
        consonants,
        diphthongs,
        stress,
        linking,
        stressWords,
      );
}
