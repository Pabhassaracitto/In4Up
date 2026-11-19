// lib/features/translation/translation_source_choice.dart
//
// PSRC-238 / ADR-0031 (bước 3b) — người dùng CHỌN ngôn ngữ nguồn của tài
// liệu ở tab Đọc (phần THUẦN, không Flutter, không storage ⇒ test trực tiếp).
//
// Vì sao cần: ngôn ngữ nguồn do app tự nhận diện từ 24 dòng đầu. Văn bản
// ngắn / lẫn tên riêng dễ bị nhận diện sai (vd tiếng Anh thành tiếng Đức) và
// người dùng không có chỗ nào để sửa. `setTranslationSourceLanguage` đã có
// từ XLAT-MLKIT-001 nhưng chưa có giao diện gọi tới và lựa chọn chưa được
// lưu.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/language/app_language.dart';

/// Giá trị «Tự nhận diện» khi gọi `setTranslationSourceLanguage`.
const String kTranslationSourceAuto = 'AUTO';

/// Đọc lựa chọn nguồn đã lưu của một tài liệu.
///
/// Trả mã dịch chuẩn (vd `EN`, `ZH-TW`); `null` = «Tự nhận diện» (chưa lưu,
/// đã bỏ chọn, hoặc chuỗi lạ / hỏng — coi như chưa từng chọn).
String? decodeSavedTranslationSource(String? raw) =>
    AppLanguageCatalog.maybeFromCode(raw)?.translationCode;

/// Khoá lưu lựa chọn nguồn cho một tài liệu.
///
/// Cùng cách băm với dấu «Đổi vai» (`roleSwapStorageKey`): Hive chỉ nhận
/// khoá ASCII ≤ 255 ký tự, đường dẫn file có thể dài và có dấu.
String translationSourceStorageKey(String documentKey) =>
    'read_translation_source_v1_${md5.convert(utf8.encode(documentKey))}';

/// Khi nguồn trùng đích: đề nghị MỘT ngôn ngữ đích khác để người dùng chọn
/// bằng một chạm, thay vì chỉ báo lỗi.
///
/// Thứ tự ưu tiên (bỏ qua mục nào trùng [source]):
///   1. ngôn ngữ giao diện của app — người học thường muốn đọc nghĩa bằng
///      tiếng mình đang dùng;
///   2. nguồn đang dùng ngay trước khi đổi ([previousSource]);
///   3. tiếng Anh, rồi tiếng Việt;
///   4. ngôn ngữ đầu tiên trong danh mục khác [source].
///
/// Không bao giờ trả ngôn ngữ trùng [source].
AppLanguage suggestTargetAvoidingSource({
  required AppLanguage source,
  String? uiLanguageCode,
  AppLanguage? previousSource,
}) {
  final candidates = <AppLanguage?>[
    AppLanguageCatalog.maybeFromCode(uiLanguageCode),
    previousSource,
    AppLanguageCatalog.maybeFromCode('EN'),
    AppLanguageCatalog.maybeFromCode('VI'),
    ...AppLanguageCatalog.languages,
  ];
  for (final candidate in candidates) {
    if (candidate == null) continue;
    if (candidate.translationCode == source.translationCode) continue;
    return candidate;
  }
  // Danh mục có nhiều hơn một ngôn ngữ ⇒ không tới được đây.
  return AppLanguageCatalog.english;
}
