// lib/services/read_chrome_layout_store.dart
//
// READ-UI-120 — nguồn sự thật duy nhất cho cấu hình chrome tab Đọc.
//
// Dùng `ValueNotifier` (không cần đăng ký Provider mới trong main.dart) để cả
// ba nơi cùng phản ứng tức thì khi người dùng đổi trong màn
// «Tùy chỉnh giao diện shell»: app bar (main_shell), dock đáy
// (ReadModeScreen) và chính màn cài đặt.

import 'package:flutter/foundation.dart';

import '../models/read_chrome_layout.dart';
import 'storage_service.dart';

class ReadChromeLayoutStore {
  ReadChromeLayoutStore._();

  static final ReadChromeLayoutStore instance = ReadChromeLayoutStore._();

  final ValueNotifier<ReadChromeLayout> layout =
      ValueNotifier<ReadChromeLayout>(ReadChromeLayout.defaults);

  bool _loaded = false;

  /// Idempotent; gọi ở `initState` của màn shell / màn cài đặt / màn Đọc.
  /// Nếu Hive chưa sẵn sàng thì KHÔNG đánh dấu đã load — lần gọi sau sẽ đọc
  /// lại thay vì kẹt ở giá trị mặc định.
  void load() {
    final storage = StorageService();
    if (_loaded || !storage.isInitialized) return;
    _loaded = true;
    layout.value = storage.getReadChromeLayout();
  }

  Future<void> update(ReadChromeLayout next) async {
    if (layout.value == next) return;
    layout.value = next;
    await StorageService().saveReadChromeLayout(next);
  }

  Future<void> restoreDefaults() => update(ReadChromeLayout.defaults);
}
