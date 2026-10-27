// ADR-0018 (P1) — CẦU NỐI link/tệp từ hệ điều hành vào MÀN TỪ ĐIỂN.
//
// Ba nguồn, một đích:
//   * Android/iOS  → MethodChannel `in4up/deeplink`
//                    (`getInitialLink` để lấy link lúc khởi động, `onLink`
//                    cho lúc app đã chạy — xem MainActivity.kt / AppDelegate.swift)
//   * Windows/Linux → `argv` của `main(List<String> args)`
//   * Web           → không có (trình duyệt không đăng ký được handler)
//
// Vì sao KHÔNG dùng `app_links` như ADR-0018 dự phóng: repo đã có sẵn khuôn
// MethodChannel cho 4 channel khác ("in4up/audiolib", "in4up/textlib",
// "in4up/dictionary", "in4up/ocr") ⇒ phần native chỉ ~30 dòng, không thêm phụ
// thuộc nào phải giải version (mỗi lần `flutter pub get` trên CI là một rủi ro
// mới), và không phải chờ plugin cập nhật khi Flutter đổi API nhúng.
//
// Nguyên tắc: KHÔNG tự dựng UI. Mọi yêu cầu tra từ đi qua
// `DictionaryScreen.open(...)` — đúng "một đích duy nhất" của ADR-0018.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../widgets/dictionary_screen.dart';
import 'dict_deep_link.dart';

class DictDeepLinkRouter {
  DictDeepLinkRouter._();

  static final DictDeepLinkRouter instance = DictDeepLinkRouter._();

  /// Kênh native → Dart. Native gọi `onLink` với `String` (URL thô).
  static const MethodChannel channel = MethodChannel('in4up/deeplink');

  /// Gắn vào `MaterialApp.navigatorKey` để mở màn hình từ ngoài widget tree.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<DictDeepLinkRequest> _pendingWords = <DictDeepLinkRequest>[];
  final List<DictDeepLinkRequest> _deferredFiles = <DictDeepLinkRequest>[];

  bool _started = false;
  bool _callHandlerInstalled = false;
  int _flushAttempts = 0;

  /// Yêu cầu mở TỆP đã bóc được nhưng chưa xử lý (P3 — "Mở bằng In4Up").
  /// Giữ lại thay vì nuốt lặng: khi P3 xong, chỗ này là hàng đợi sẵn dùng.
  List<DictDeepLinkRequest> get deferredFiles =>
      List<DictDeepLinkRequest>.unmodifiable(_deferredFiles);

  /// Số yêu cầu tra từ đang chờ mở màn (dùng cho test/chẩn đoán).
  int get pendingWordCount => _pendingWords.length;

  /// Khởi động: đọc `argv` (desktop) + link khởi động (mobile) + lắng nghe
  /// link đến sau. Gọi **một lần** ngay sau `runApp`.
  Future<void> start([List<String> arguments = const <String>[]]) async {
    if (_started) return;
    _started = true;

    // Desktop: `in4up.exe "C:\a.mdx"` / `in4up in4up://dict?w=hello`.
    handleArguments(arguments);

    // Web không có handler hệ điều hành (giới hạn trình duyệt — ADR-0018).
    if (kIsWeb) return;

    _installCallHandler();
    try {
      final raw = await channel.invokeMethod<String>('getInitialLink');
      if (raw != null && raw.isNotEmpty) handleRaw(raw);
    } catch (_) {
      // Nền tảng không có kênh này (web/desktop chưa cài native) — bỏ qua.
    }
  }

  void _installCallHandler() {
    if (_callHandlerInstalled) return;
    _callHandlerInstalled = true;
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onLink') return null;
      final raw = call.arguments;
      if (raw is String) handleRaw(raw);
      return null;
    });
  }

  /// Bóc `argv` của desktop.
  void handleArguments(List<String> arguments) {
    if (arguments.isEmpty) return;
    enqueue(DictDeepLink.parseArguments(arguments));
  }

  /// Bóc một URL thô từ native.
  void handleRaw(String raw) => enqueue(DictDeepLink.parse(raw));

  /// Nhận một yêu cầu đã bóc. `null` (link không liên quan) ⇒ không làm gì.
  void enqueue(DictDeepLinkRequest? request) {
    if (request == null) return;
    if (!request.isWord) {
      // Chưa hỗ trợ mở tệp (P3) — ghi lại, KHÔNG hiện lỗi cho người dùng.
      _deferredFiles.add(request);
      return;
    }
    // Native có thể đưa cùng một link 2 lần (intent lúc khởi động + onNewIntent).
    if (_pendingWords.isNotEmpty &&
        _pendingWords.last.value == request.value) {
      return;
    }
    _pendingWords.add(request);
    _flush();
  }

  /// Mở màn Từ điển cho các yêu cầu đang chờ. Nếu navigator chưa sẵn (app còn
  /// màn hình tải) thì thử lại ở frame kế tiếp.
  void _flush() {
    if (_pendingWords.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (_flushAttempts >= 20) return; // ~20 frame ≈ 0,3 s: bỏ, không treo
      _flushAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushAttempts = 0;
        _flush();
      });
      return;
    }
    final request = _pendingWords.removeAt(0);
    navigator.push(
      DictionaryScreen.route(query: request.value, source: request.source),
    );
    if (_pendingWords.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
    }
  }

  /// Chỉ dùng cho test.
  @visibleForTesting
  void resetForTest() {
    _pendingWords.clear();
    _deferredFiles.clear();
    _started = false;
    _callHandlerInstalled = false;
    _flushAttempts = 0;
  }
}
