// lib/features/vocab_image/vocab_media_type.dart
//
// LOTTIE-001 — Phân loại media minh họa từ vựng, THUẦN LOGIC (test được,
// không phụ thuộc widget/platform).
//
// Quy ước dự án: `WordEntry.imageUrl` (và `MemoryItem.imageUrl`) giữ MỘT
// trường duy nhất — hoặc relative path local (`vocabulary_images/xx.webp`),
// hoặc URL http(s). Loại media suy ra từ ĐUÔI FILE → không cần thêm cột
// schema, không migration (đúng convention additive: `*.json` / `*.lottie`
// là Lottie animation, còn lại là ảnh tĩnh).

library;

/// Loại media minh họa.
enum VocabMediaType { staticImage, lottie }

/// Đuôi file được coi là Lottie animation.
///  - `.json`   — file Lottie chuẩn (LottieFiles/CDN).
///  - `.lottie` — dotLottie archive (zip chứa manifest + animation).
const List<String> kLottieExtensions = ['.json', '.lottie'];

/// Bỏ query string/fragment (`anim.json?dl=1#x` → `anim.json`).
String _stripQuery(String value) {
  final cut = value.indexOf(RegExp(r'[?#]'));
  return cut >= 0 ? value.substring(0, cut) : value;
}

/// Phân loại media từ URL/đường dẫn. Chuỗi rỗng/null → [VocabMediaType.staticImage]
/// (call-site quyết định có hiển thị hay không).
VocabMediaType detectVocabMediaType(String? urlOrPath) {
  final raw = (urlOrPath ?? '').trim();
  if (raw.isEmpty) return VocabMediaType.staticImage;
  final clean = _stripQuery(raw).toLowerCase();
  for (final ext in kLottieExtensions) {
    if (clean.endsWith(ext)) return VocabMediaType.lottie;
  }
  return VocabMediaType.staticImage;
}

/// true khi [urlOrPath] trỏ tới Lottie animation (đuôi .json/.lottie).
bool isLottieMediaUrl(String? urlOrPath) =>
    detectVocabMediaType(urlOrPath) == VocabMediaType.lottie;

/// true khi giá trị là URL http(s) (còn lại: relative path local).
bool isNetworkMediaUrl(String? urlOrPath) {
  final s = (urlOrPath ?? '').trim().toLowerCase();
  return s.startsWith('http://') || s.startsWith('https://');
}
