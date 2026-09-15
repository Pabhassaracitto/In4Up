// B1+B2 thêm một loạt chuỗi mới mà KHÔNG có widget test nào trong CI chặn được,
// nên test này canh đúng một hợp đồng: mọi key mà luồng xuất/nhập đưa vào
// `uiText` (kể cả key ĐỘNG) phải có bản dịch, và bản dịch ở locale khác tiếng
// Việt không được còn dấu tiếng Việt (rule #5).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/pdf_reader/services/pdf_annotation_sidecar.dart';
import 'package:in4up/features/pdf_reader/services/pdf_export_service.dart';

/// Key không cần dịch: tên định dạng, hiện giống nhau ở mọi locale.
const Set<String> kUntranslatedProperNouns = {'JSON', 'XFDF'};

const List<String> kExportFlowKeys = [
  'Xuất / nhập chú thích',
  'PDF ảnh',
  'Nhập JSON',
  'JSON',
  'XFDF',
  'Đã xuất tệp',
  'Đã xuất bản chụp PDF',
  'Đã nhập chú thích',
  'Không có highlight hoặc ghi chú nào để xuất',
  'Không xuất được tệp này',
  'Không đọc được tệp này',
  'Chưa mở xong tệp PDF',
  'Không mở được trình chọn tệp',
  'Đã giới hạn số trang xuất',
  'File này không phải tệp chú thích của In4Up',
  'Tệp chú thích này được tạo bởi bản In4Up mới hơn',
  'Tệp chú thích không có gì để nhập',
  'Cùng một tệp PDF',
  'Tệp PDF đã thay đổi sau khi xuất',
  'Số trang khác với lúc xuất',
  'Không kiểm tra được tệp PDF có trùng không',
  'Số annotation trong tệp',
  'Highlight đang có sẽ được giữ nguyên.',
  'Nhập chú thích',
  'Nhập',
  'Huỷ',
];

bool hasVietnameseDiacritics(String s) => RegExp(
      r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
      caseSensitive: false,
    ).hasMatch(s);

void main() {
  test('luồng xuất có đúng các key thành công đã đăng ký', () {
    expect(kPdfExportSuccessMessageKeys, isNotEmpty);
    for (final key in kPdfExportSuccessMessageKeys) {
      expect(AppUITranslations.translate(key, 'en'), isNot(equals(key)),
          reason: '"$key" được coi là thành công nhưng chưa có trong catalog');
    }
  });

  test('mọi key của luồng xuất/nhập có bản dịch en', () {
    for (final key in kExportFlowKeys) {
      if (kUntranslatedProperNouns.contains(key)) continue;
      expect(AppUITranslations.translate(key, 'en'), isNot(equals(key)),
          reason: 'Thiếu key "$key" trong lib/core/language/priority_ui_overrides.dart '
              '⇒ người dùng en/hi/zh sẽ thấy tiếng Việt trong hộp xuất/nhập');
    }
  });

  test('bản dịch hi/zh/zh_TW/si không còn dấu tiếng Việt', () {
    for (final key in kExportFlowKeys) {
      for (final lang in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
        final value = AppUITranslations.translate(key, lang);
        expect(hasVietnameseDiacritics(value), isFalse,
            reason: '"$key" [$lang] = "$value" — rơi lại tiếng Việt ở locale $lang');
      }
    }
  });

  group('key sinh động cũng phải khớp catalog', () {
    test('PdfSidecarProblem -> label key, đủ 4 loại', () {
      expect(PdfSidecarProblem.values, hasLength(4));
      for (final p in PdfSidecarProblem.values) {
        final key = PdfSidecarDecoding.failure(p).problemLabelKey!;
        expect(kExportFlowKeys, contains(key),
            reason: 'key thông báo "$key" không nằm trong danh sách đã duyệt');
        expect(AppUITranslations.translate(key, 'en'), isNot(equals(key)));
      }
    });

    test('PdfSidecarFileMatch -> nhãn trong hộp xác nhận, đủ 4 mức', () {
      expect(PdfSidecarFileMatch.values, hasLength(4));
      for (final m in PdfSidecarFileMatch.values) {
        final result = PdfSidecarPickResult(match: m);
        final key = result.matchLabelKey;
        expect(kExportFlowKeys, contains(key));
        expect(AppUITranslations.translate(key, 'en'), isNot(equals(key)),
            reason: '"$key" chưa dịch');
      }
      // Không có match vẫn phải ra nhãn an toàn, không được null/chuỗi rỗng.
      expect(PdfSidecarPickResult.cancelled.matchLabelKey, isNotEmpty);
    });

    test('key thành công/isError không đổi tên âm thầm', () {
      expect(
        kPdfExportSuccessMessageKeys,
        containsAll(<String>['Đã xuất tệp', 'Đã xuất bản chụp PDF']),
      );
      expect(const PdfExportOutcome(messageKey: 'Đã xuất tệp', count: 3).isSuccess, isTrue);
      expect(const PdfExportOutcome(messageKey: 'Không xuất được tệp này').isSuccess, isFalse);
      expect(const PdfExportOutcome(messageKey: 'Đã xuất tệp', detail: 'limited:2').isTruncated, isTrue);
      expect(const PdfExportOutcome(messageKey: 'Đã xuất tệp', detail: 'a.json').isTruncated, isFalse);
    });

    test('số trang tối đa bản chụp là hợp lý (RAM điện thoại)', () {
      expect(kPdfSnapshotMaxPages, greaterThan(0));
      expect(kPdfSnapshotMaxPages, lessThanOrEqualTo(60));
      // Nền trang phải TRẮNG: in nền tối của app ra giấy là thảm hoạ mực.
      expect(kPdfSnapshotBackgroundArgb, 0xFFFFFFFF);
    });
  });
}
