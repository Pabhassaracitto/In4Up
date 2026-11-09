// YT-LR-002 — 5 lỗi phát hiện khi nghiệm thu trên máy thật (owner báo
// 2026-10-20), pin lại để không tái phát:
//
//   1. Chế độ "Có bản dịch": bấm 1 dòng ⇒ nhiều dòng dịch bị ẩn, chỉ còn
//      các dòng CUỐI. Nguyên nhân: mỗi lô dịch dựng lại `merged` từ `base`
//      (chưa có dịch) ⇒ xoá sạch dịch của các lô trước.
//   2. Chế độ "Làm mờ bản dịch": dịch bị ẩn hẳn thay vì mờ. Nguyên nhân:
//      `ImageFiltered` (lớp blur riêng) render trống trên máy thật; cách
//      thay thế bằng `MaskFilter` trên paint của chữ cũng hỏng (Impeller bỏ
//      qua ⇒ không thấy gì) — xem YT-AUDIT-02 / IN4-98, cách đúng là
//      `TextStyle.shadows`.
//   3. Tab Tải audio: không có nút dừng, kẹt "Đang tải…". Nguyên nhân:
//      `await for` không huỷ được từ UI.
//   4. Âm thanh nhanh hơn chữ ~1 dòng (IN4-81). Nguyên nhân: hỏi vị trí phát
//      bằng `setInterval(250)` ⇒ cộng tới 250ms độ trễ; phải đẩy theo sự kiện
//      `timeupdate` và ĐO drift thay vì đoán.
//   5. Tab GIẢI THÍCH: không phản hồi + crash
//      `'!_debugDoingThisLayout': is not true`. Nguyên nhân:
//      `context.select<AiServiceFacade,…>()` + `TabBarView` (PageView cần
//      viewport layout) trong khi `analyzeWord()` gọi `notifyListeners()` ở
//      giữa các `await`.
//
// Test thuần này pin các ràng buộc cấu trúc (không cần WebView/AI thật).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player =
      File('lib/features/youtube/yt_player_screen.dart').readAsStringSync();
  final panel =
      File('lib/features/youtube/widgets/yt_word_panel.dart').readAsStringSync();

  group('Lỗi 1 — dịch tăng dần phải TÍCH LUỸ (không mất dịch các lô trước)',
      () {
    test('có bảng dịch tích luỹ, kích thước đúng số dòng gốc', () {
      expect(
        player.contains('final translations = List<String?>.filled(total, null);'),
        isTrue,
        reason: 'Thiếu bảng dịch tích luỹ ⇒ mỗi lô xoá dịch của lô trước '
            '(triệu chứng: chỉ còn các dòng dịch cuối).',
      );
    });

    test('mỗi lô GHI THÊM vào bảng, không dựng lại từ base', () {
      expect(
        player.contains('translations[offset + i] ='),
        isTrue,
        reason: 'Phải ghi vào bảng tích luỹ theo chỉ số tuyệt đối.',
      );
      // Bản lỗi: `final merged = List<YtCaptionLine>.from(base);` bên trong
      // vòng lặp ⇒ mỗi lô lại bắt đầu từ bản gốc chưa có dịch.
      expect(
        player.contains('final merged = List<YtCaptionLine>.from(base);'),
        isFalse,
        reason: 'Dựng lại từ `base` trong vòng lặp ⇒ mất dịch các lô trước.',
      );
    });

    test('áp lại TOÀN BỘ danh sách từ bảng tích luỹ', () {
      expect(
        player.contains('base[i].copyWith(translation: translations[i]),'),
        isTrue,
        reason: 'Phải áp lại toàn bộ để dịch đã có không biến mất.',
      );
    });
  });

  group('Lỗi 2 — "Làm mờ bản dịch" phải MỜ, không được ẩn', () {
    // YT-AUDIT-02 (IN4-98): hai cách cũ ĐỀU hỏng — `ImageFiltered` render
    // TRỐNG trên máy thật, còn `MaskFilter` trên paint của chữ bị Impeller
    // bỏ qua ⇒ chữ hiện bình thường ("không thấy gì"). Cách đứng vững là
    // `TextStyle.shadows` (Skia lẫn Impeller đều hỗ trợ).
    test('làm mờ bằng TextStyle.shadows', () {
      expect(
        player.contains('shadows: <Shadow>['),
        isTrue,
        reason: 'Phải làm mờ bằng bóng của chính chữ — không phụ thuộc '
            'backend vẽ.',
      );
      expect(
        player.contains('Shadow(color: Color(0xFFFFC107), blurRadius: 7)'),
        isTrue,
        reason: 'Cần 2 lớp bóng mờ cùng màu để chữ thành vệt mờ.',
      );
    });

    test('không còn MaskFilter / ImageFilter / import dart:ui', () {
      expect(
        player.contains('MaskFilter.blur('),
        isFalse,
        reason: 'MaskFilter trên paint của chữ bị Impeller bỏ qua ⇒ '
            'người dùng không thấy hiệu ứng mờ.',
      );
      expect(
        player.contains('ImageFilter.blur('),
        isFalse,
        reason: 'ImageFiltered/layer blur từng render TRỐNG trên máy thật '
            '⇒ người dùng tưởng bản dịch bị ẩn hẳn.',
      );
      expect(
        player.contains("import 'dart:ui'"),
        isFalse,
        reason: 'Đã bỏ hẳn blur ở lớp composite ⇒ không cần dart:ui.',
      );
    });

    test('chế độ mờ có lối bấm để hiện/mờ lại', () {
      expect(
        player.contains('_translationRevealed = !_translationRevealed'),
        isTrue,
        reason: 'Phải bấm được để hiện tạm rồi mờ lại.',
      );
    });
  });

  group('Lỗi 3 — tab Tải audio phải huỷ được và không kẹt', () {
    test('có nút Dừng gọi YtDownloader.cancel()', () {
      expect(
        player.contains('YtDownloader.instance.cancel();'),
        isTrue,
        reason: 'Thiếu YtDownloader.cancel() ⇒ không dừng được luồng tải.',
      );
      expect(
        player.contains('Future<void> _cancelDownloadAudio()'),
        isTrue,
        reason: 'Thiếu hàm huỷ gắn với nút Dừng trên UI.',
      );
    });

    test('giữ StreamSubscription (await for không huỷ được từ UI)', () {
      expect(
        player.contains('StreamSubscription<YtDownloadEvent>? _dlSub;'),
        isTrue,
        reason: '`await for` không có cách ngắt từ ngoài ⇒ kẹt "Đang tải…".',
      );
      expect(
        player.contains('_dlSub = YtDownloader.instance.download(video).listen('),
        isTrue,
        reason: 'Phải dùng listen() để giữ subscription mà huỷ được.',
      );
    });

    test('có bộ canh báo kẹt sau 45 giây không tiến triển', () {
      expect(
        player.contains('Timer.periodic(const Duration(seconds: 15)'),
        isTrue,
        reason: 'Thiếu bộ canh ⇒ người dùng không biết đang kẹt hay đang tải.',
      );
      expect(
        player.contains('bool _dlStalled = false;'),
        isTrue,
        reason: 'Thiếu cờ báo kẹt để hiện cảnh báo + nút Dừng.',
      );
    });

    test('dispose() phải dọn subscription + bộ canh', () {
      final i = player.indexOf('void dispose() {');
      expect(i, greaterThan(-1));
      final body = player.substring(i, i + 400);
      expect(body.contains('_dlSub?.cancel();'), isTrue);
      expect(body.contains('_dlWatchdog?.cancel();'), isTrue);
    });
  });

  group('Lỗi 4 — đồng bộ âm thanh/chữ (IN4-81)', () {
    test('đẩy vị trí phát theo SỰ KIỆN timeupdate, không chỉ setInterval', () {
      expect(
        player.contains("v.addEventListener('timeupdate', tick);"),
        isTrue,
        reason: '`timeupdate` bắn ngay khi currentTime đổi; setInterval(250) '
            'cộng thêm tới 250ms độ trễ ⇒ chữ đổi trễ hơn tiếng nói.',
      );
      expect(
        player.contains('hook(v0)'),
        isTrue,
        reason: 'Phải gắn listener cho <video> đã tồn tại.',
      );
    });

    test('vẫn có dự phòng setInterval khi trình duyệt throttles timer', () {
      expect(
        player.contains('setInterval(tick, 1000);'),
        isTrue,
        reason: 'Tab ẩn / tiết kiệm pin ⇒ timeupdate ngưng, cần dự phòng.',
      );
    });

    test('ĐO drift thay vì đoán (log drift + driftTB)', () {
      expect(
        player.contains('final drift = ms - line.start.inMilliseconds;'),
        isTrue,
        reason: 'Phải đo độ lệch thực tế; không áp offset cố định mọi video.',
      );
      expect(player.contains('driftTB='), isTrue);
    });
  });

  group('Lỗi 5 — tab GIẢI THÍCH: không crash + báo rõ trạng thái AI', () {
    test('dùng IndexedStack, KHÔNG dùng TabBarView', () {
      expect(
        panel.contains('IndexedStack('),
        isTrue,
        reason: 'IndexedStack gán cùng một约束 tĩnh cho mọi con ⇒ không cần '
            'viewport ⇒ không còn "RenderBox was not laid out".',
      );
      expect(
        panel.contains('TabBarView('),
        isFalse,
        reason: 'TabBarView là PageView; con chưa laid out bị hỏi kích thước '
            "gây lỗi '!_debugDoingThisLayout': is not true.",
      );
    });

    test('KHÔNG watch/select AiServiceFacade trong build()', () {
      expect(
        panel.contains('context.select<AiServiceFacade,'),
        isFalse,
        reason: 'analyzeWord() notifyListeners() giữa các await ⇒ rebuild đúng '
            'lúc build/layout ⇒ crash layout.',
      );
    });

    test('tự gọi lookupWord + tự giữ kết quả bằng setState', () {
      expect(panel.contains('lookupWord('), isTrue);
      expect(panel.contains('bool _aiWaiting = false;'), isTrue);
      expect(panel.contains('AiAnalysis? _aiResult;'), isTrue);
    });

    test('có timeout để không treo (facade mất tới 30s + 45s)', () {
      expect(
        panel.contains('.timeout(const Duration(seconds: 90))'),
        isTrue,
        reason: 'Thiếu timeout ⇒ "không có phản ứng" như owner báo.',
      );
    });

    test('hiện RÕ 4 trạng thái AI (đang chờ / lỗi / chỉ từ điển / xong)', () {
      expect(
        panel.contains('Đang nhờ AI phân tích…'),
        isTrue,
        reason: 'Thiếu trạng thái đang chờ.',
      );
      expect(
        panel.contains('AI chưa phân tích được.'),
        isTrue,
        reason: 'Thiếu trạng thái lỗi.',
      );
      expect(
        panel.contains('AI chưa trả lời kịp (thường do quá 30 giây).'),
        isTrue,
        reason: 'Facade rớt về nghĩa từ điển mà không báo ⇒ người dùng tưởng '
            'AI "chỉ đang dịch".',
      );
      expect(
        panel.contains('Thử lại bằng AI'),
        isTrue,
        reason: 'Phải có nút thử lại.',
      );
    });

    test('phát hiện kết quả CHỈ LÀ TỪ ĐIỂN (success nhưng không có độ sâu AI)',
        () {
      expect(
        panel.contains('bool _isDictionaryOnly(AiAnalysis a)'),
        isTrue,
        reason: 'buildFromLocalDict() trả success:true, isPartial:false ⇒ '
            'phải đoán theo độ sâu để báo trung thực.',
      );
    });
  });
}
