/// ═══════════════════════════════════════════════════════════════
/// VIETNAMESE TRIE — khớp TỪ GHÉP dài nhất (longest match)
///
/// Handoff MVA v2.0 — Task 4: "tokenize (Trie cho Việt)".
/// Trie keyed theo TỪ (không phải kí tự): node con = từ tiếp theo.
/// "sinh viên đại học" khớp "sinh viên" + "đại học" nếu cả hai có trong
/// từ điển — ưu tiên cụm DÀI NHẤT tại vị trí quét.
///
/// File thuần dart:core — không import gì (dễ test, không kéo chain).
/// ═══════════════════════════════════════════════════════════════
library;

/// Từ điển mảnh từ ghép tiếng Việt phổ biến (seed v1 — mở rộng sau bằng
/// dữ liệu người dùng thật; cấu trúc giữ key theo từ-thường-không-dấu-câu).
const List<String> kSeedVietnameseCompoundWords = <String>[
  // giáo dục
  'sinh viên', 'đại học', 'học sinh', 'nhà trường', 'giáo viên', 'kỳ thi',
  'bài học', 'bài kiểm tra', 'sách giáo khoa', 'thư viện', 'phòng học',
  'tiết học', 'giờ học', 'học bổng', 'học phí',
  // xã hội - tổ chức
  'thủ đô', 'thành phố', 'cơ quan', 'chính phủ', 'thủ tướng', 'chủ tịch',
  'bộ trưởng', 'hội đồng', 'công an', 'ủy ban', 'trung tâm', 'cộng đồng',
  // nghề nghiệp - con người
  'công nhân', 'nông dân', 'bà con', 'đồng nghiệp', 'bạn bè', 'người quen',
  'người già', 'trẻ em', 'ông bà', 'cha mẹ', 'anh chị em',
  // giao thông - địa điểm
  'xe buýt', 'tàu hỏa', 'tàu điện', 'máy bay', 'sân bay', 'nhà ga',
  'bến xe', 'đường phố', 'khách sạn', 'nhà hàng', 'quán ăn', 'cửa hàng',
  'siêu thị', 'trạm xăng',
  // kinh tế - học thuật
  'giá cả', 'thị trường', 'kinh tế', 'xã hội', 'văn hóa', 'lịch sử',
  'địa lý', 'khoa học', 'công nghệ', 'thông tin', 'học máy', 'dữ liệu',
  'trí tuệ nhân tạo', 'mạng xã hội', 'điện thoại', 'máy tính',
  // đời sống
  'cà phê', 'trà đá', 'cơm tấm', 'phở bò', 'áo dài', 'nước mắt',
  'câu chuyện', 'sức khỏe', 'thể thao', 'bóng đá', 'phim ảnh',
];

/// Trie từ ghép: node = một từ; nhánh = từ kế tiếp trong cụm.
class VietnameseTrie {
  final Map<String, VietnameseTrie> _children = <String, VietnameseTrie>{};
  bool _endsWord = false;

  VietnameseTrie._();

  /// Dựng trie từ danh sách từ ghép (mỗi mục = nhiều từ cách nhau bởi space).
  factory VietnameseTrie.fromWords(Iterable<String> compounds) {
    final root = VietnameseTrie._();
    for (final compound in compounds) {
      final parts = compound
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        root._insert(parts, 0);
      }
    }
    return root;
  }

  void _insert(List<String> parts, int i) {
    if (i == parts.length) {
      _endsWord = true;
      return;
    }
    final node = _children.putIfAbsent(parts[i], VietnameseTrie._);
    node._insert(parts, i + 1);
  }

  /// Độ dài cụm DÀI NHẤT (số từ) khớp tại [words]/[index]; 0 nếu không có.
  /// Chỉ trả >= 2 khi có cụm nhiều từ (đơn từ không thú vị ở tokenizer).
  int longestMatch(List<String> words, int index) {
    var best = 0;
    VietnameseTrie node = this;
    for (var i = index; i < words.length; i++) {
      final next = node._children[words[i]];
      if (next == null) break;
      node = next;
      if (node._endsWord && (i - index + 1) >= 2) {
        best = i - index + 1;
      }
    }
    return best;
  }
}
