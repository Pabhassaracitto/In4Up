// lib/features/translation/line_role_swap.dart
//
// PSRC-237 / ADR-0031 — «Đổi vai» văn bản ⇄ bản dịch (phần THUẦN, không
// Flutter, không storage ⇒ test được trực tiếp).
//
// Vì sao cần: mọi công cụ từ vựng của tab Đọc (IPA, tô màu loại từ, CEFR,
// chạm tra từ) chỉ chạy trên `TextItem.content`. Người có văn bản bản xứ rồi
// dịch sang tiếng Anh thì tiếng Anh nằm ở `translation` ⇒ không công cụ nào
// với tới. Đổi vai = hoán đổi hai trường đó cho từng dòng ĐÃ có bản dịch.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/language/app_language.dart';
import '../../models/text_item.dart';

/// Trạng thái «đang đổi vai» của tài liệu đang mở.
///
/// [promotedCode]  ngôn ngữ của bản dịch đã được đưa lên làm văn bản chính.
/// [originalCode]  ngôn ngữ của văn bản GỐC (nay nằm ở dòng dịch).
/// [swappedLines]  số dòng đã hoán đổi — dùng làm ngưỡng khi mở lại tài
///                 liệu: chỉ tự đổi vai lại khi bản dịch đã có ĐỦ chừng đó.
class LineRoleSwapState {
  const LineRoleSwapState({
    required this.promotedCode,
    required this.originalCode,
    required this.swappedLines,
    this.previousPinnedSourceCode,
  });

  final String promotedCode;
  final String originalCode;
  final int swappedLines;

  /// Nguồn dịch user đã gắn TRƯỚC khi đổi vai (null = tự nhận diện) — trả
  /// lại nguyên trạng khi đổi lại. Không lưu xuống đĩa.
  final String? previousPinnedSourceCode;

  /// Dấu lưu theo tài liệu: `EN>VI>42`.
  String encode() => '$promotedCode>$originalCode>$swappedLines';

  /// Đọc dấu đã lưu; chuỗi lạ / hỏng ⇒ null (coi như chưa từng đổi vai).
  static LineRoleSwapState? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split('>');
    if (parts.length != 3) return null;
    final promoted = AppLanguageCatalog.maybeFromCode(parts[0]);
    final original = AppLanguageCatalog.maybeFromCode(parts[1]);
    final count = int.tryParse(parts[2]);
    if (promoted == null || original == null || count == null || count <= 0) {
      return null;
    }
    if (promoted.translationCode == original.translationCode) return null;
    return LineRoleSwapState(
      promotedCode: promoted.translationCode,
      originalCode: original.translationCode,
      swappedLines: count,
    );
  }
}

/// Kết quả hoán đổi một danh sách dòng.
class LineRoleSwapResult {
  const LineRoleSwapResult({
    required this.lines,
    required this.swapped,
    required this.kept,
  });

  /// Danh sách dòng mới (cùng độ dài, cùng thứ tự, cùng `id`).
  final List<TextItem> lines;

  /// Số dòng đã hoán đổi.
  final int swapped;

  /// Số dòng CÓ CHỮ nhưng giữ nguyên vì chưa có bản dịch ở [fromCode].
  final int kept;
}

/// Mã bản dịch của một dòng. Dòng song ngữ nhập kiểu cũ không có metadata và
/// luôn là tiếng Việt (cùng quy ước với `translatedLineCount`).
String lineTranslationCode(TextItem line) =>
    AppLanguageCatalog.normalizeTranslationCode(
      line.translationLanguageCode ?? 'VI',
    );

/// Dòng này có bản dịch đang ở ngôn ngữ [code] hay không.
bool lineHasTranslationIn(TextItem line, String code) {
  final translation = line.translation;
  if (translation == null || translation.trim().isEmpty) return false;
  return lineTranslationCode(line) == code;
}

/// Số dòng có thể đổi vai với bản dịch ở ngôn ngữ [code].
int countSwappableLines(List<TextItem> lines, String code) =>
    lines.where((line) => lineHasTranslationIn(line, code)).length;

/// Hoán đổi `content` ⇄ `translation` cho mọi dòng có bản dịch ở [fromCode].
///
/// Sau khi đổi:
///   * `content`                 = bản dịch cũ (ngôn ngữ [fromCode]);
///   * `translation`             = nội dung cũ;
///   * `sourceLanguageCode`      = [fromCode];
///   * `translationLanguageCode` = [toCode] — gắn ĐỒNG NHẤT cho mọi dòng đã
///     đổi, kể cả dòng mà detector từng ghi ngôn ngữ khác: nếu để lệch với
///     đích dịch mới, `translateAll` sẽ coi dòng đó «chưa dịch» và ghi đè
///     lên văn bản gốc.
///
/// Dòng không có bản dịch ở [fromCode] giữ NGUYÊN (không mất chữ). Mốc thời
/// gian, `id`, `words`, `isHighlighted` đi theo dòng, không đổi.
///
/// Gọi lại với cặp mã đảo ngược là phép nghịch đảo (đổi lại đúng nội dung).
LineRoleSwapResult swapLineRoles(
  List<TextItem> lines, {
  required String fromCode,
  required String toCode,
}) {
  var swapped = 0;
  var kept = 0;
  final next = <TextItem>[];
  for (final line in lines) {
    if (!lineHasTranslationIn(line, fromCode)) {
      if (line.content.trim().isNotEmpty) kept++;
      next.add(line);
      continue;
    }
    swapped++;
    next.add(
      line.copyWith(
        // Không trim: đổi lại phải trả đúng từng ký tự của văn bản gốc.
        content: line.translation!,
        translation: line.content,
        sourceLanguageCode: fromCode,
        translationLanguageCode: toCode,
      ),
    );
  }
  return LineRoleSwapResult(lines: next, swapped: swapped, kept: kept);
}

/// Khoá lưu dấu đổi vai cho một tài liệu.
///
/// Hive chỉ nhận khoá ASCII ≤ 255 ký tự; đường dẫn file có thể dài và có
/// dấu ⇒ băm MD5 (ổn định giữa các lần chạy, cùng cách `TranslationCache`).
String roleSwapStorageKey(String documentKey) =>
    'read_role_swap_v1_${md5.convert(utf8.encode(documentKey))}';

/// Nơi lưu dấu đổi vai theo tài liệu (seam để test không cần Hive).
abstract class RoleSwapMarkerStore {
  String? read(String documentKey);
  void write(String documentKey, String value);
  void remove(String documentKey);
}
