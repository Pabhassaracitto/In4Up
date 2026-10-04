import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/learning_activity.dart';
import '../services/learning_activity_service.dart';

/// HOME-STREAK-001 — "Nhịp điệu học tập".
///
/// Lịch sử (vì sao viết lại): trước đây provider này tự tính streak trong
/// `saveEffort(score)` — chỉ tăng khi người dùng kéo "slider nỗ lực". Slider đã
/// bị bỏ ở HOME-001 nên `saveEffort` không còn caller nào: streak gần như luôn
/// bằng 0 và không phản ánh việc học thật (KANBAN — HOME-STREAK-001).
///
/// Từ nay provider chỉ là lớp xem (facade) trên [LearningActivityService]:
/// - Sự kiện học thật do nơi phát sinh hành động ghi vào service (đọc tài
///   liệu, lưu/import từ, ôn LHB, shadowing, dịch).
/// - Streak và số liệu hôm nay/7 ngày đọc ra từ cùng một nguồn đó — không
///   hardcode, không còn phụ thuộc slider nỗ lực.
class FocusProvider extends ChangeNotifier {
  FocusProvider({LearningActivityService? service})
      : _service = service ?? LearningActivityService.instance {
    _service.addListener(_handleServiceChanged);
    unawaited(_service.ready);
  }

  final LearningActivityService _service;

  LearningActivityService get service => _service;

  /// Ảnh chụp đầy đủ cho thẻ (hôm nay + streak + 7 ngày).
  LearningStreakSnapshot snapshot({int days = 7}) =>
      _service.snapshot(days: days);

  /// Số ngày học liên tiếp đang giữ.
  int get streak => _service.streak();

  /// Số liệu hôm nay (theo giờ địa phương).
  LearningDayActivity get today => _service.today;

  bool get activeToday => _service.activeToday;

  List<LearningDayActivity> recentDays({int days = 7}) =>
      _service.recentDays(days: days);

  /// Kho đã nạp xong dữ liệu bền hay chưa (UI hiển thị 0 trước khi nạp xong).
  bool get isLoaded => _service.isLoaded;

  void _handleServiceChanged() => notifyListeners();

  @override
  void dispose() {
    _service.removeListener(_handleServiceChanged);
    super.dispose();
  }
}
