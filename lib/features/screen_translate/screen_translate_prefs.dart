// lib/features/screen_translate/screen_translate_prefs.dart
//
// Lưu ngôn ngữ đích của "dịch màn hình toàn hệ thống" (XLAT-SCR-002).
//
// Vì sao lưu riêng chứ không dùng `TranslationService.targetLang`: service
// chạy trong ENGINE NỀN (isolate khác) nên biến RAM của app không với tới
// được. SharedPreferences là file chung của tiến trình Android ⇒ cả hai bên
// đọc được cùng một giá trị. Đây cũng là lý do native luôn gửi kèm
// `targetLanguage` trong mỗi frame: engine nền không phải đoán.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';

const String kScreenTranslateTargetPrefKey = 'screen_translate_target_lang';

/// Mã ngôn ngữ đích mặc định khi user chưa chọn gì.
const String kScreenTranslateDefaultTarget = 'VI';

/// Chuẩn hoá mã ngôn ngữ đích về đúng `translationCode` trong catalog.
///
/// Thuần Dart (test host VM): rỗng/null/không có trong catalog → mặc định.
String normalizeScreenTranslateTarget(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return kScreenTranslateDefaultTarget;
  final upper = value.toUpperCase();
  final match = AppLanguageCatalog.languages
      .where((lang) => lang.translationCode.toUpperCase() == upper);
  if (match.isEmpty) return kScreenTranslateDefaultTarget;
  return match.first.translationCode;
}

/// Đọc ngôn ngữ đích đã lưu (không bao giờ throw).
Future<String> loadScreenTranslateTarget() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return normalizeScreenTranslateTarget(
      prefs.getString(kScreenTranslateTargetPrefKey),
    );
  } catch (e) {
    debugPrint('⚠️ screen translate: đọc ngôn ngữ đích lỗi: $e');
    return kScreenTranslateDefaultTarget;
  }
}

/// Lưu ngôn ngữ đích; trả về mã đã chuẩn hoá thực sự được lưu.
Future<String> saveScreenTranslateTarget(String raw) async {
  final code = normalizeScreenTranslateTarget(raw);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kScreenTranslateTargetPrefKey, code);
  } catch (e) {
    debugPrint('⚠️ screen translate: lưu ngôn ngữ đích lỗi: $e');
  }
  return code;
}
