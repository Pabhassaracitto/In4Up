class LoopPresets {
  LoopPresets._(); // Không cho khởi tạo

  /// Badge cycle trên Listen Screen: tap để chuyển mode LẶP BÀI (khác với
  /// số lần lặp A-B). `-1` ở đây là "lặp bài vô hạn" — chỉ MỘT `∞`, không
  /// phải lỗi user báo (lỗi nằm ở `dropdownValues` bên dưới).
  static const List<int> badgeModes = [0, 1, 3, 5, -1];
  static const List<String> badgeLabels = ['Lặp', '1×', '3×', '5×', '∞'];

  /// Dropdown / chip chọn số lần lặp A-B.
  /// AUDIT-1.21.0 #8: trước đây `[-1, 0, 1, …]` + `labelFor(count <= 0)`
  /// ⇒ HAI mục "∞ ∞" đứng đầu (đúng lỗi user báo:
  /// "∞ ∞ 1× 3× 5× 7× … 20×"). Với A-B, `0` và `-1` ĐỀU là "không giới hạn"
  /// (`_maxLoopCount > 0` mới dừng) ⇒ giữ MỘT `∞` (= 0), `-1` chỉ gom về 0
  /// khi đọc cài đặt cũ.
  static const List<int> dropdownValues = [0, 1, 3, 5, 7, 10, 15, 20];

  /// Label cho giá trị bất kỳ
  static String labelFor(int count) {
    if (count <= 0) return '∞';
    return '${count}x';
  }

  /// Tìm index an toàn trong badgeModes
  static int safeBadgeIndex(int maxLoopCount) {
    final idx = badgeModes.indexOf(maxLoopCount);
    return idx >= 0 ? idx : 0;
  }

  /// Value an toàn cho dropdown / chip: `-1` (cài đặt cũ) được gom về `0`
  /// để danh sách chọn không bao giờ có 2 mục `∞`.
  static int safeDropdownValue(int maxLoopCount) {
    if (maxLoopCount < 0) return 0;
    return dropdownValues.contains(maxLoopCount) ? maxLoopCount : 0;
  }
}
