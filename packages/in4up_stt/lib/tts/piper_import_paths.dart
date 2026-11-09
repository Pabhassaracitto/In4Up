import 'dart:convert';

/// Kích thước tối thiểu (byte) của bảng tokens Piper HỢP LỆ.
///
/// ⚠️ Ngưỡng phải THẤP: bảng phoneme Piper VITS chỉ có ~154 dòng
/// (`<symbol> <id>`) ⇒ file tokens.txt của k2-fsa chỉ ~900 byte (không
/// phải hàng trăm KB như tokens của ASR). Ngưỡng cao sẽ loại nhầm giọng
/// hợp lệ ⇒ app báo "chưa cài" dù model nguyên vẹn.
///
/// File nhỏ hơn ngưỡng = file rỗng/cắt ⇒ KHÔNG dùng (native sẽ khởi tạo
/// với tokens rỗng ⇒ phát ra tiếng rỗng).
///
/// Dùng chung cho manager (import) + core (discover) để 2 nơi KHÔNG lệch
/// ngưỡng ⇒ 1 giọng không bị "import OK" ở nơi này rồi "không có tokens" ở
/// nơi kia.
const int kMinPiperTokensBytes = 128;

/// Pure helpers for Piper import (folder + file). Tested without Flutter IO.
class PiperImportPaths {
  static const espeakFolder = 'espeak-ng-data';

  /// ASCII backslash — Windows path separator. Avoid `'\\\\'` in Dart source
  /// (that is TWO backslashes and never matches `espeak-ng-data\phontab`).
  static final String _winSep = String.fromCharCode(92);

  static String posixRel(String rel) => rel.replaceAll(_winSep, '/');

  static bool isOnnxModelName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.onnx') && !lower.endsWith('.onnx.json');
  }

  static bool isTokensName(String name) {
    final lower = name.toLowerCase();
    return lower == 'tokens.txt' || lower.endsWith('_tokens.txt');
  }

  static bool isOnnxJsonName(String name) =>
      name.toLowerCase().endsWith('.onnx.json');

  /// Sinh nội dung `tokens.txt` (format sherpa-onnx: `<symbol> <id>` mỗi
  /// dòng) từ config Piper `.onnx.json`.
  ///
  /// Bộ Piper đời mới (piper 1.0.0, ví dụ `rhasspy/piper-voices`) chỉ có
  /// `<voice>.onnx` + `<voice>.onnx.json` — KHÔNG có `tokens.txt`: bảng
  /// phoneme nằm trong `phoneme_id_map` của JSON (giá trị là số hoặc
  /// mảng `[id]`). Sinh lại từ map ⇒ giọng dùng được ngay.
  ///
  /// Trả null nếu JSON hỏng / không có `phoneme_id_map` ⇒ caller giữ đường
  /// tải fallback như cũ.
  static String? tokensFromPiperConfigJson(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final ids = decoded['phoneme_id_map'];
    if (ids is! Map || ids.isEmpty) return null;
    final pairs = <MapEntry<String, int>>[];
    ids.forEach((symbol, value) {
      int? id;
      if (value is int) {
        id = value;
      } else if (value is List && value.isNotEmpty && value.first is int) {
        id = value.first as int;
      }
      if (id == null) return;
      pairs.add(MapEntry(symbol.toString(), id));
    });
    if (pairs.isEmpty) return null;
    pairs.sort((a, b) => a.value.compareTo(b.value));
    // Symbol có thể là khoảng trắng (" ") ⇒ giữ nguyên (đúng format file
    // tokens.txt của k2-fsa: dòng "  3" = symbol " " + id 3).
    return '${pairs.map((e) => '${e.key} ${e.value}').join('\n')}\n';
  }

  static bool isPiperArchiveName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz');
  }

  /// Phonemizer files that live inside `espeak-ng-data/` (k2-fsa bundle).
  static bool isEspeakLeafName(String name) {
    switch (name.toLowerCase()) {
      case 'phontab':
      case 'phonindex':
      case 'phondata':
      case 'intonations':
        return true;
      default:
        return name.toLowerCase().endsWith('_dict');
    }
  }

  /// Relative path inside dest starting at `espeak-ng-data/…`, or null.
  static String? espeakTail(String relativePath) {
    final posix = posixRel(relativePath);
    final lower = posix.toLowerCase();
    const needle = '$espeakFolder/';
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      if (lower == espeakFolder || lower.endsWith('/$espeakFolder')) {
        return espeakFolder;
      }
      return null;
    }
    return posix.substring(idx);
  }

  static bool looksLikeEspeakRoot(String folderName) =>
      folderName.toLowerCase() == espeakFolder;
}
