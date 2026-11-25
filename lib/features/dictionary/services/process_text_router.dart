// ADR-0018 P2 — BỘ ĐỊNH TUYẾN `ACTION_PROCESS_TEXT` (bôi chữ ở app khác).
//
// Luồng: Android gửi `EXTRA_PROCESS_TEXT` qua kênh `in4up/process_text`
// (native chỉ chuyển tiếp chuỗi thô — xem MainActivity) → [ProcessTextRouter]
// bóc bằng `routeProcessText` (smart split, thuần Dart) →
//   • một từ  → đẩy `DictionaryScreen` (cùng màn với mọi đường vào khác);
//   • cụm/câu → hiện `ReadSelectionTranslateSheet` (cùng engine dịch với
//     toolbar Đọc — KHÔNG thêm engine mới).
//
// Vì sao tách khỏi `DictDeepLinkRouter`: deep link chỉ làm TỪ ĐIỆN (P1),
// còn route này phải mở cả sheet dịch — nhưng DÙNG CHUNG `navigatorKey`
// của `DictDeepLinkRouter` vì `MaterialApp` chỉ nhận một navigatorKey
// (main.dart:503).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../screens/read_mode/sheets/read_selection_sheets.dart';
import '../../translation/translation_service.dart';
import '../widgets/dictionary_screen.dart';
import 'dict_deep_link_router.dart';
import 'process_text_route.dart';

/// Bộ định tuyến chữ bôi chọn từ app khác (`ACTION_PROCESS_TEXT`).
///
/// Gọi [start] một lần ngay sau `runApp` (main.dart) — giống
/// `DictDeepLinkRouter.start`. Web không có handler hệ điều hành ⇒ bỏ qua.
class ProcessTextRouter {
  ProcessTextRouter._();

  static final ProcessTextRouter instance = ProcessTextRouter._();

  /// Kênh native → Dart. Native gọi `onProcessText` với `String` (chuỗi thô);
  /// Dart gọi `getInitialProcessText` để lấy chuỗi lúc khởi động (một lần).
  static const MethodChannel channel = MethodChannel('in4up/process_text');

  final List<ProcessTextRoute> _pending = <ProcessTextRoute>[];

  bool _started = false;
  bool _callHandlerInstalled = false;
  int _flushAttempts = 0;

  /// Chuỗi vừa xử lý xong + lúc nào — native có thể gửi trùng (intent lúc
  /// khởi động + `onNewIntent`); bỏ bản trùng trong cửa sổ 3 giây để không
  /// mở màn hai lần, nhưng vẫn cho phép tra lại cùng từ sau đó.
  String? _lastHandled;
  int _lastHandledAtMs = 0;

  /// Số yêu cầu đang chờ mở màn (dùng cho test/chẩn đoán).
  int get pendingCount => _pending.length;

  /// Khởi động: lấy chuỗi khởi động (nếu app được mở bằng PROCESS_TEXT) +
  /// lắng nghe chuỗi đến sau. Gọi **một lần** ngay sau `runApp`.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Web không có `ACTION_PROCESS_TEXT` (giới hạn trình duyệt — ADR-0018).
    if (kIsWeb) return;

    _installCallHandler();
    try {
      final raw = await channel.invokeMethod<String>('getInitialProcessText');
      if (raw != null && raw.isNotEmpty) enqueue(raw);
    } catch (_) {
      // Nền tảng không có kênh này (desktop/iOS chưa cài native) — bỏ qua.
    }
  }

  void _installCallHandler() {
    if (_callHandlerInstalled) return;
    _callHandlerInstalled = true;
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onProcessText') return null;
      final raw = call.arguments;
      if (raw is String) enqueue(raw);
      return null;
    });
  }

  /// Nhận một chuỗi `EXTRA_PROCESS_TEXT` từ native. Chuỗi rỗng/toàn khoảng
  /// trắng ⇒ [routeProcessText] trả `null` ⇒ im lặng bỏ qua (không mở màn).
  void enqueue(String raw) {
    final route = routeProcessText(raw);
    if (route == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (route.text == _lastHandled && nowMs - _lastHandledAtMs < 3000) {
      return; // bản trùng do native gửi 2 lần (intent + onNewIntent)
    }
    if (_pending.isNotEmpty && _pending.last.text == route.text) return;

    _pending.add(route);
    _flush();
  }

  /// Mở màn/sheet cho yêu cầu đang chờ. Nếu navigator chưa sẵn (app còn màn
  /// hình tải) thì thử lại ở frame kế tiếp — cùng đựng pháp với
  /// `DictDeepLinkRouter._flush`.
  void _flush() {
    if (_pending.isEmpty) return;
    final navigatorKey = DictDeepLinkRouter.instance.navigatorKey;
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
    _flushAttempts = 0;
    final route = _pending.removeAt(0);
    _lastHandled = route.text;
    _lastHandledAtMs = DateTime.now().millisecondsSinceEpoch;

    switch (route.action) {
      case ProcessTextAction.dictionary:
        navigator.push(
          DictionaryScreen.route(query: route.text, source: 'process_text'),
        );
      case ProcessTextAction.translate:
        _showTranslateSheet(navigatorKey, route.text);
    }
    if (_pending.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
    }
  }

  /// Hiện bảng dịch — cùng sheet với nút "Dịch" của tab Đọc
  /// (`ReadSelectionTranslateSheet.show`), dùng ngữ cảnh CỦA NAVIGATOR
  /// (MaterialApp đặt Localizations/Theme/MediaQuery phía trên Navigator nên
  /// `showModalBottomSheet` lấy đủ). Ngôn ngữ đích = cấu hình dịch hiện tại
  /// (`TranslationService.targetLang`, mặc định VI); nguồn để service tự
  /// nhận diện — đúng hành vi mọi caller khác của sheet.
  void _showTranslateSheet(GlobalKey<NavigatorState> navigatorKey, String text) {
    // Dùng ngữ cảnh của OVERLAY (con của Navigator): `Navigator.of` tự xử
    // lý đúng cả khi ngữ cảnh là chính Navigator, và Localizations/Theme mà
    // `showModalBottomSheet` cần (debugCheckHasMaterialLocalizations) đều nằm
    // phía TRÊN Navigator trong MaterialApp — lấy đủ từ đây.
    final navigator = navigatorKey.currentState;
    final context = navigator?.overlay?.context ?? navigatorKey.currentContext;
    if (context == null) {
      // Không bao giờ xảy ra (navigator đã có currentState) — nhưng đừng ném
      // exception từ đường vào ngoài app.
      debugPrint('[ProcessTextRouter] Không có ngữ cảnh cho sheet dịch');
      return;
    }
    final service = TranslationService();
    unawaited(
      ReadSelectionTranslateSheet.show(
        context,
        text: text,
        targetCode: service.targetLang,
      ),
    );
  }

  /// Chỉ dùng cho test.
  @visibleForTesting
  void resetForTest() {
    _pending.clear();
    _started = false;
    _callHandlerInstalled = false;
    _flushAttempts = 0;
    _lastHandled = null;
    _lastHandledAtMs = 0;
  }
}
