// lib/features/iconize/engine/iconize_bridge.dart
//
// ICONIZE-001c — Bridge-to-English (blueprint mục 3.5, ADR-0013 #3):
// token tiếng đích (v1: tiếng Việt) → ứng viên lemma tiếng Anh qua bảng
// đảo của từ điển offline sẵn có. Engine sau đó resolve TỪNG ứng viên;
// chỉ icon hóa khi MỌI ứng viên resolve được đồng thuận đúng 1 icon —
// không đồng thuận / từ điển mỏng → giữ chữ (an toàn trước, đẹp sau).
//
// Nguồn v1: OfflineDictionary.entries (~500 cặp EN→VI thiên lyric) — phủ
// mỏng là CHẤP NHẬN ĐƯỢC vì fallback luôn là giữ chữ; mở rộng bằng MDX
// user-import là việc của roadmap v2 (ghi ở blueprint mục 9).

class EnglishBridgeDictionary {
  final Map<String, List<String>> _viToEn;

  EnglishBridgeDictionary._(this._viToEn);

  /// Loại từ đứng đầu cụm nghĩa tiếng Việt có thể bóc để lấy danh từ lõi:
  /// "cái cây" → "cây", "cuốn sách" → "sách", "trái tim" → "tim".
  /// CHỦ ĐÍCH không gồm "mặt" (mặt trời/mặt trăng — bóc ra sai nghĩa).
  static const Set<String> _classifiers = {
    'con', 'cái', 'chiếc', 'cuốn', 'quyển', 'ngôi',
    'cánh', 'trái', 'bàn', 'đôi', 'bức', 'tấm',
  };

  /// Dựng bảng đảo VI→EN từ map EN→VI (OfflineDictionary.entries).
  factory EnglishBridgeDictionary.fromEnViEntries(
      Map<String, String> enToVi) {
    final rev = <String, Set<String>>{};
    void add(String vi, String en) {
      rev.putIfAbsent(vi, () => <String>{}).add(en);
    }

    enToVi.forEach((en, vi) {
      final viNorm = vi.toLowerCase().trim();
      final enNorm = en.toLowerCase().trim();
      if (viNorm.isEmpty || enNorm.isEmpty) return;
      add(viNorm, enNorm);
      final parts = viNorm.split(' ');
      if (parts.length == 2 && _classifiers.contains(parts[0])) {
        add(parts[1], enNorm);
      }
    });
    // List sort để kết quả tất định giữa các lần chạy.
    final frozen = <String, List<String>>{};
    rev.forEach((k, v) => frozen[k] = List.unmodifiable(v.toList()..sort()));
    return EnglishBridgeDictionary._(Map.unmodifiable(frozen));
  }

  /// Ứng viên lemma tiếng Anh cho một token tiếng Việt (đã lowercase).
  /// Rỗng = từ điển không biết → engine giữ chữ.
  List<String> englishCandidates(String viTokenLower) =>
      _viToEn[viTokenLower] ?? const [];

  int get entryCount => _viToEn.length;
}
