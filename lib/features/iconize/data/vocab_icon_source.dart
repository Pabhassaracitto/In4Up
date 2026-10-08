// lib/features/iconize/data/vocab_icon_source.dart
//
// ICONIZE-001d — adapter tầng 1 của fallback icon (blueprint mục 3.6):
// ảnh user đã gán cho từ vựng (vocab_image) THẮNG icon bundle, vì user
// đã tự xác nhận nghĩa khi gán ảnh (engine 001c: user source bỏ qua
// icon_index, chỉ còn cổng concreteness + POS).
//
// Thiết kế: engine giữ reference tới adapter này (bất biến về interface);
// nội dung map được LÀM MỚI qua [update] khi WordEntry thay đổi — resolve
// là lookup đồng bộ thuần, không IO trong vòng render.

import '../engine/iconize_icon_source.dart';
import '../models/iconize_span.dart';

class VocabImageIconSource implements IconizeIconSource {
  // lemma lowercase → đường dẫn TUYỆT ĐỐI của ảnh (đã xác minh tồn tại
  // tại thời điểm update).
  Map<String, String> _pathByLemma = const {};

  @override
  IconizeSource get sourceKind => IconizeSource.userVocabImage;

  @override
  String? resolve(String lemma, IconizePos pos) {
    final path = _pathByLemma[lemma];
    return path == null ? null : 'file:$path';
  }

  int get entryCount => _pathByLemma.length;

  /// Dựng lại map từ danh sách (từ, đường dẫn ảnh tuyệt đối đã tồn tại).
  ///
  /// Caller (IconizeService) chịu trách nhiệm: resolve relative→absolute,
  /// lọc URL http (offline-first — không fetch mạng trong render), kiểm
  /// tra file tồn tại. Ở đây chỉ chuẩn hóa key: lấy TỪ ĐƠN (một token,
  /// không khoảng trắng) lowercase — engine tra theo lemma đơn.
  void update(Iterable<MapEntry<String, String>> wordImagePairs) {
    final next = <String, String>{};
    for (final pair in wordImagePairs) {
      final word = pair.key.trim().toLowerCase();
      if (word.isEmpty || word.contains(RegExp(r'\s'))) continue;
      next[word] = pair.value;
    }
    _pathByLemma = next;
  }
}
