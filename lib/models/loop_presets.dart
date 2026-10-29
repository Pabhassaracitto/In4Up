class LoopPresets {
  LoopPresets._(); // Không cho khởi tạo

  /// Badge cycle trên Listen Screen: tap để chuyển mode
  static const List<int> badgeModes = [0, 1, 3, 5, -1];
  static const List<String> badgeLabels = ['Lặp', '1×', '3×', '5×', '∞'];

  /// Dropdown trong AB Loop sheet
  static const List<int> dropdownValues = [-1, 0, 1, 3, 5, 7, 10, 15, 20];

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

  /// Value an toàn cho dropdown
  static int safeDropdownValue(int maxLoopCount) {
    return dropdownValues.contains(maxLoopCount) ? maxLoopCount : 0;
  }
}
