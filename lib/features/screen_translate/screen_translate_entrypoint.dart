// lib/features/screen_translate/screen_translate_entrypoint.dart
//
// Điểm vào Dart của ENGINE NỀN mà `ScreenTranslateService` (Kotlin) khởi qua
// `FlutterEngineGroup.createAndRunEngine(DartEntrypoint(bundle,
// "package:in4up/features/screen_translate/screen_translate_entrypoint.dart",
// "screenTranslateMain"))`. XLAT-SCR-002 · ADR-0011.
//
// Vì sao engine RIÊNG chứ không tái dùng engine UI:
//  - Bong bóng phải sống khi app đã bị đóng khỏi màn hình gần đây; engine UI
//    lúc đó không tồn tại.
//  - `FlutterEngineGroup` chia sẻ snapshot/code nên engine thứ hai tốn thêm
//    ~vài MB thay vì cả chục MB (tài liệu Flutter: "multiple-flutters").
//  - Isolate riêng ⇒ không chen vào vòng đời Provider của app.
//
// Hệ quả: isolate này có Hive/SharedPreferences RIÊNG (static của Dart không
// chia sẻ qua isolate). Cache dịch nằm trên SharedPreferences nên vẫn ĂN
// chung với app (cùng file XML của Android) — đúng tiêu chí nghiệm thu #3
// "lặp lại cùng màn hình không tốn thêm request".
//
// TUYỆT ĐỐI KHÔNG tải model ở đây (luật vàng): chỉ mở Hive cho glossary và
// gắn handler. Thiếu model dịch offline → trả `missingModel` cho native hiện
// thông báo, user tự vào Cài đặt bấm "Tải về".
//
// XLAT-SCR-005 (owner 24/10) — hai việc thêm ở đây:
//  1. Nối `onProgress` của controller vào `reportProgress` để native đổi bong
//     bóng/thông báo theo từng chặng (đang OCR / đang dịch 3/12 khối).
//  2. `warmUp()` pipeline ngay khi engine nền dựng xong (không chờ) để lượt
//     bấm bong bóng ĐẦU TIÊN không phải gánh chi phí mở cache/glossary.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../translation/translation_service.dart';
import 'screen_translate_channel.dart';
import 'screen_translate_controller.dart';

/// Giữ tham chiếu để binding không bị GC khi `main` kết thúc.
ScreenTranslateWorkerBinding? screenTranslateWorkerBinding;

/// Controller của engine nền (lộ ra để test gọi lại `handleFrame`).
ScreenTranslateController? screenTranslateWorkerController;

@pragma('vm:entry-point')
Future<void> screenTranslateMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prepareScreenTranslateWorker();
}

/// Phần KHỞI TẠO tách riêng khỏi `main` để test gọi được mà không cần engine.
Future<void> prepareScreenTranslateWorker({
  ScreenTranslateController? controller,
  ScreenTranslateWorkerBinding? binding,
}) async {
  try {
    await Hive.initFlutter();
  } catch (e) {
    // Glossary chỉ là một tầng của pipeline dịch; mở Hive hỏng thì vẫn dịch
    // được bằng engine — không để cả bong bóng chết vì chuyện này.
    debugPrint('⚠️ screen translate worker: Hive.initFlutter lỗi: $e');
  }

  ScreenTranslateWorkerBinding? bind;

  late final ScreenTranslateController ctrl;
  ctrl = controller ??
      ScreenTranslateController(
        // Báo tiến trình KHÔNG được chặn OCR/dịch: `reportProgress` là
        // fire-and-forget, lỗi channel bị nuốt trong binding.
        onProgress: (stage, done, total) {
          final message = ctrl.progressText(stage, done: done, total: total);
          final target = bind;
          if (target == null) return;
          unawaited(target.reportProgress(message));
        },
      );
  screenTranslateWorkerController = ctrl;

  bind = binding ??
      ScreenTranslateWorkerBinding(
        onFrame: ctrl.handleFrame,
        onStopped: () => debugPrint('ℹ️ screen translate worker: service dừng'),
      );
  screenTranslateWorkerBinding = bind;
  await bind.attach();

  // Làm ấm pipeline SAU khi đã attach: dù lần đầu chậm vài trăm ms thì
  // native vẫn gửi frame được, và lượt bấm kế tiếp đã nhanh.
  unawaited(TranslationService().warmUp());
}
