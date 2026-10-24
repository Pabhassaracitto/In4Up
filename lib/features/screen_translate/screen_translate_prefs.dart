// lib/features/screen_translate/screen_translate_prefs.dart
//
// Lưu cấu hình của "dịch màn hình toàn hệ thống" (XLAT-SCR-002 · XLAT-SCR-005).
//
// Vì sao lưu riêng chứ không dùng `TranslationService.targetLang`: service
// chạy trong ENGINE NỀN (isolate khác) nên biến RAM của app không với tới
// được. SharedPreferences là file chung của tiến trình Android ⇒ cả hai bên
// đọc được cùng một giá trị. Đây cũng là lý do native luôn gửi kèm
// `targetLanguage`/`sourceLanguage` trong mỗi frame: engine nền không phải
// đoán.
//
// XLAT-SCR-005 (owner 24/10): thêm NGÔN NGỮ NGUỒN và chế độ "kéo chọn vùng".
// Trước đây chỉ lưu ngôn ngữ đích vì pipeline luôn tự nhận diện nguồn — nay
// người dùng chọn được cả hai đầu (kể cả đảo chiều, kể cả hai ngôn ngữ khác
// tiếng Anh).

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';

const String kScreenTranslateTargetPrefKey = 'screen_translate_target_lang';
const String kScreenTranslateSourcePrefKey = 'screen_translate_source_lang';

/// Khoá bật "mỗi lần bấm bong bóng thì kéo chọn vùng" — native đọc trực tiếp
/// file SharedPreferences của Flutter (`flutter.<khoá>`) nên giá trị có hiệu
/// lực ngay, không cần khởi động lại service.
const String kScreenTranslateSelectRegionPrefKey =
    'screen_translate_select_region';

/// Mã ngôn ngữ đích mặc định khi user chưa chọn gì.
const String kScreenTranslateDefaultTarget = 'VI';

/// Ngôn ngữ nguồn mặc định: để engine tự nhận diện.
const String kScreenTranslateDefaultSource = 'AUTO';

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

/// Chuẩn hoá mã ngôn ngữ NGUỒN: 'AUTO' hợp lệ, mã lạ → AUTO.
///
/// Vì sao không rơi về 'EN': dịch sai chiều (lấy tiếng Việt làm nguồn trong
/// khi màn hình là tiếng Anh) tệ hơn nhiều so với việc để engine tự nhận
/// diện — chế độ AUTO vốn đã là mặc định an toàn.
String normalizeScreenTranslateSource(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return kScreenTranslateDefaultSource;
  final upper = value.replaceAll('_', '-').toUpperCase();
  if (upper == 'AUTO' || upper == 'SYSTEM') return kScreenTranslateDefaultSource;
  final resolved = AppLanguageCatalog.maybeFromCode(upper);
  return resolved?.translationCode ?? kScreenTranslateDefaultSource;
}

/// Ngôn ngữ đích gợi ý theo locale ứng dụng/hệ thống.
///
/// Yêu cầu của owner (24/10): mặc định nên là "tiếng Anh ↔ ngôn ngữ hệ thống"
/// chứ không phải luôn luôn `VI`. Người dùng đổi được cả hai đầu trong thẻ
/// cài đặt; đây chỉ là giá trị GỢI Ý cho lần đầu.
String defaultScreenTranslateTargetForLocale(String? localeCode) {
  final resolved = AppLanguageCatalog.maybeFromCode(localeCode);
  return resolved?.translationCode ?? kScreenTranslateDefaultTarget;
}

/// Đọc ngôn ngữ đích đã lưu (không bao giờ throw).
///
/// [fallback] = giá trị dùng khi CHƯA có gì được lưu (UI truyền ngôn ngữ ứng
/// dụng vào đây để lần đầu tiên đã đúng "ngôn ngữ hệ thống").
Future<String> loadScreenTranslateTarget({
  String fallback = kScreenTranslateDefaultTarget,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kScreenTranslateTargetPrefKey);
    if (saved == null || saved.trim().isEmpty) {
      return normalizeScreenTranslateTarget(fallback);
    }
    return normalizeScreenTranslateTarget(saved);
  } catch (e) {
    debugPrint('⚠️ screen translate: đọc ngôn ngữ đích lỗi: $e');
    return normalizeScreenTranslateTarget(fallback);
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

/// Đọc ngôn ngữ nguồn đã lưu ('AUTO' khi chưa chọn).
Future<String> loadScreenTranslateSource() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return normalizeScreenTranslateSource(
      prefs.getString(kScreenTranslateSourcePrefKey),
    );
  } catch (e) {
    debugPrint('⚠️ screen translate: đọc ngôn ngữ nguồn lỗi: $e');
    return kScreenTranslateDefaultSource;
  }
}

/// Lưu ngôn ngữ nguồn; trả về mã đã chuẩn hoá.
Future<String> saveScreenTranslateSource(String raw) async {
  final code = normalizeScreenTranslateSource(raw);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kScreenTranslateSourcePrefKey, code);
  } catch (e) {
    debugPrint('⚠️ screen translate: lưu ngôn ngữ nguồn lỗi: $e');
  }
  return code;
}

/// Đọc chế độ "bấm bong bóng = kéo chọn vùng" (mặc định tắt = dịch cả màn hình).
Future<bool> loadScreenTranslateSelectRegion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kScreenTranslateSelectRegionPrefKey) ?? false;
  } catch (e) {
    debugPrint('⚠️ screen translate: đọc chế độ chọn vùng lỗi: $e');
    return false;
  }
}

/// Lưu chế độ "bấm bong bóng = kéo chọn vùng".
Future<void> saveScreenTranslateSelectRegion(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kScreenTranslateSelectRegionPrefKey, value);
  } catch (e) {
    debugPrint('⚠️ screen translate: lưu chế độ chọn vùng lỗi: $e');
  }
}
