// PSRC-182 (owner 2026-11-10) — *"Phân biệt gói ngôn ngữ ĐÃ TẢI trong dịch
// offline"*.
//
// Triệu chứng: trong sheet "Engine dịch thuật" → "Gói dịch offline (ML Kit —
// Android/iOS)", gói ĐÃ TẢI vẫn hiện nút "Tải về" ⇒ user phân vân không biết
// tải xong chưa.
//
// Yêu cầu: KHÔNG hiện "Tải về" cho gói đã tải; ưu tiên BIỂU TƯỢNG (có thể
// kèm chữ).
//
// `_modelRow` là method private của State + `MlKitEngine.platformSupported`
// chỉ đúng trên Android/iOS ⇒ không dựng widget test trên CI được. Pin bằng
// source-scan (máy bắt, cùng chuẩn các card khác).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final toolbar =
      File('lib/features/translation/translation_toolbar.dart')
          .readAsStringSync();

  String modelRowBody() {
    final start = toolbar.indexOf('Widget _modelRow(String code)');
    expect(start, greaterThan(0), reason: 'Mất hàng gói ML Kit (_modelRow).');
    // Lấy tới hết class (hàng kế tiếp là `class _TranslateButton`).
    final end = toolbar.indexOf('class _TranslateButton');
    expect(end, greaterThan(start));
    return toolbar.substring(start, end);
  }

  group('PSRC-182 — gói ML Kit đã tải không còn nút "Tải về"', () {
    test('nút tải chỉ render khi CHƯA tải', () {
      final body = modelRowBody();
      final gateIdx = body.indexOf('if (supported && !downloaded)');
      expect(gateIdx, greaterThan(0),
          reason: 'Nút tải phải nằm trong nhánh "chưa tải" — thiếu điều kiện '
              'này là quay lại lỗi gói đã tải vẫn hiện "Tải về".');
      // Nhánh chưa tải: spinner "Đang tải..." + nút "Tải về" (có icon).
      final nextBranch = body.indexOf('if (supported && downloaded)', gateIdx);
      final gate = body.substring(
          gateIdx, nextBranch > 0 ? nextBranch : body.length);
      expect(gate, contains("context.uiText('Tải về')"));
      // Không còn nhánh cũ "if (supported) TextButton(" luôn hiện.
      expect(body.contains('if (supported)\n            TextButton('), isFalse,
          reason: 'Nhánh cũ luôn hiện nút cho MỌI gói (kể cả đã tải).');
    });

    test('nút tải có BIỂU TƯỢNG (icon + chữ), không chỉ chữ', () {
      final body = modelRowBody();
      expect(body, contains('TextButton.icon('),
          reason: 'Owner: ưu tiên biểu tượng thay vì chỉ chữ "Tải về".');
      expect(body, contains('Icons.download_rounded'));
    });

    test('trạng thái đã tải đọc được bằng mắt (✓ + chữ "Đã tải" màu xanh)',
        () {
      final body = modelRowBody();
      // Icon trạng thái đầu hàng: ✓ xanh khi đã tải.
      expect(body, contains('Icons.check_circle'));
      expect(body, contains('context.uiText(\'Đã tải\')'));
      expect(body, contains('? Colors.green'),
          reason: 'Chữ "Đã tải" phải khác màu "Chưa tải" để phân biệt ngay.');
    });

    test('đọc lại trạng thái THẬT sau khi tải/xoá (không tin plugin)', () {
      // `downloadModel()` có thể trả false khi gói đã có sẵn ⇒ nếu tin
      // tuyệt đối, hàng UI lại hiện "Tải về" cho gói đã tải.
      //
      // PSRC-188: việc hỏi lại `isModelDownloaded` đã CHUYỂN vào registry
      // `MlKitPackDownloads` (sống ngoài sheet) — sheet chỉ uỷ quyền. Vì vậy
      // pin hai chỗ: sheet gọi registry, registry hỏi lại trạng thái thật.
      final dlStart = toolbar.indexOf('Future<void> _downloadModel(String code)');
      final delStart = toolbar.indexOf('Future<void> _deleteModel(String code)');
      expect(dlStart, greaterThan(0));
      expect(delStart, greaterThan(dlStart));
      final download = toolbar.substring(dlStart, delStart);
      expect(download, contains('_packs.start('),
          reason: 'Sheet phải uỷ quyền tải cho registry (sống ngoài sheet).');
      final delEnd = toolbar.indexOf('String _modelLabel(String code)');
      expect(delEnd, greaterThan(delStart));
      final delete = toolbar.substring(delStart, delEnd);
      expect(delete, contains('_packs.removed('),
          reason: 'Xoá gói cũng đi qua registry để mọi nơi thấy trạng thái mới.');

      final registry = File(
        'lib/features/translation/mlkit_pack_downloads.dart',
      ).readAsStringSync();
      expect(registry, contains('_isDownloaded(bcpCode)'),
          reason: 'Sau downloadModel phải hỏi lại isModelDownloaded.');
      expect(registry, contains('removed('),
          reason: 'Sau deleteModel phải hỏi lại isModelDownloaded.');
    });

    test('PSRC-28 — danh sách gói gọn 3 ngôn ngữ + nút "Thêm ngôn ngữ"', () {
      // Sheet phải vẽ từ catalog (không hard-code 3 mã) và có nhánh mở rộng,
      // nếu không 16 ngôn ngữ ML Kit còn lại lại bị giấu.
      expect(toolbar, contains('MlKitPackCatalog('),
          reason: 'Danh sách gói phải lấy từ catalog, không hard-code EN/VI/HI.');
      expect(toolbar, contains('_catalog.primary'),
          reason: 'Nhóm hiện sẵn = 3 ngôn ngữ phổ biến.');
      expect(toolbar, contains('_catalog.extra'),
          reason: 'Nhóm mở rộng = phần còn lại trong 26 ngôn ngữ của app.');
      expect(toolbar, contains("context.uiText('Thêm ngôn ngữ')"));
      expect(toolbar, contains("context.uiText('Ẩn bớt ngôn ngữ')"),
          reason: 'Mở ra được thì phải thu gọn lại được.');
      expect(toolbar.contains("static const _mlkitCodes"), isFalse,
          reason: 'Hard-code 3 mã chính là lỗi PSRC-28.');
    });

    test('PSRC-188 — trạng thái gói KHÔNG nằm trong State của sheet', () {
      // Nếu ai đó đưa map trạng thái trở lại State, đóng sheet là mất dấu
      // "đang tải" ⇒ lỗi cũ quay lại. Pin bằng source-scan.
      expect(toolbar.contains('_modelDownloaded'), isFalse,
          reason: 'Map trạng thái trong State = lỗi PSRC-188 quay lại.');
      expect(toolbar.contains('_downloading['), isFalse);
      expect(toolbar, contains('_packs.addListener('),
          reason: 'Sheet phải lắng nghe registry ngoài sheet.');
      expect(toolbar, contains('_packs.removeListener('),
          reason: 'Rời sheet phải gỡ listener (không setState trên State đã tháo).');
      expect(toolbar, contains('Đang tải ngầm'),
          reason: 'Mở lại khi đang tải phải thấy dấu hiệu vẫn đang chạy.');
    });
  });
}
