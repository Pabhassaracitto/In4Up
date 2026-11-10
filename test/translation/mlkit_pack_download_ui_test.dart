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
      final dlStart = toolbar.indexOf('Future<void> _downloadModel(String code)');
      final delStart = toolbar.indexOf('Future<void> _deleteModel(String code)');
      expect(dlStart, greaterThan(0));
      expect(delStart, greaterThan(dlStart));
      final download = toolbar.substring(dlStart, delStart);
      expect(download, contains('isModelDownloaded('),
          reason: 'Sau downloadModel phải hỏi lại isModelDownloaded.');
      final delEnd = toolbar.indexOf('String _modelLabel(String code)');
      expect(delEnd, greaterThan(delStart));
      final delete = toolbar.substring(delStart, delEnd);
      expect(delete, contains('isModelDownloaded('),
          reason: 'Sau deleteModel phải hỏi lại isModelDownloaded.');
    });
  });
}
