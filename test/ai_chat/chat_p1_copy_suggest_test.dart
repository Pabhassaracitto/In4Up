// PLAN-049 P1 — máy bắt 3 điểm chạm AI Chat:
//   P1-1 nút sao chép câu trả lời (copy-answer),
//   P1-2 chip gợi ý prompt ở màn trống (chỉ điền chữ, không tự gửi),
//   P1-3 xác nhận trước khi xoá hội thoại (bảo vệ lịch sử persist),
//   i18n: 4 chuỗi gợi ý phải có trong legacy JSON (en) + priority pack
//   (đủ 8 locale, không ký tự Việt ở locale ≠ vi — rule #5).
//
// Thuần source-scan + đọc JSON — KHÔNG widget, KHÔNG plugin (bài học run
// 40575300780: test plugin thật treo runner).
//
// Chạy: flutter test test/ai_chat/chat_p1_copy_suggest_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _screenPath = 'lib/screens/ai_chat/ai_chat_screen.dart';
const _legacyJsonPath = 'tool/legacy_ui_english_overrides.json';
const _packJsonPath = 'tool/priority_native_pack.json';
const _fallbacksDartPath = 'lib/core/language/generated_legacy_ui_fallbacks.dart';

/// 4 chuỗi gợi ý P1-2 — nguồn vi, phải khớp đúng 100% với các catalog.
const _suggestions = <String>[
  'Giải thích ngữ pháp cho mình',
  'Đặt 3 ví dụ với từ mới',
  'Tóm tắt giúp mình một đoạn văn',
  'Sửa lỗi câu tiếng Anh của mình',
];

/// Ký tự Việt (đ/ơ/ư + thanh) — cấm xuất hiện ở locale ≠ vi (rule #5).
final _vietnameseOnly = RegExp(r'[đĐơƠưƯáàảãạắằẳẵặấầẩẫậéèẻẽẹêềểễệ'
    r'íìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]');

void main() {
  final screenSrc = File(_screenPath).readAsStringSync();
  final legacy =
      jsonDecode(File(_legacyJsonPath).readAsStringSync()) as Map<String, dynamic>;
  final pack =
      jsonDecode(File(_packJsonPath).readAsStringSync()) as Map<String, dynamic>;
  final fallbacksSrc = File(_fallbacksDartPath).readAsStringSync();

  group('PLAN-049 P1-1 — nút sao chép câu trả lời', () {
    test('bubble trợ lý có Clipboard.setData + snackbar Đã sao chép', () {
      expect(screenSrc.contains('Clipboard.setData'), isTrue,
          reason: 'Thiếu handler copy — RichText không chọn được chữ bằng gesture');
      expect(screenSrc.contains("uiText('Đã sao chép')"), isTrue,
          reason: 'Snackbar phải dùng chuỗi i18n đã đăng ký');
      expect(screenSrc.contains("uiText('Sao chép')"), isTrue,
          reason: 'Tooltip copy phải dùng chuỗi i18n đã đăng ký');
      expect(screenSrc.contains("import 'package:flutter/services.dart';"), isTrue,
          reason: 'Clipboard nằm trong services.dart');
    });

    test('chuỗi copy đã đăng ký trong legacy JSON + fallback dart', () {
      expect(legacy['Sao chép'], 'Copy');
      expect(legacy['Đã sao chép'], 'Copied');
      expect(fallbacksSrc.contains("'Sao chép': 'Copy'"), isTrue);
      expect(fallbacksSrc.contains("'Đã sao chép': 'Copied'"), isTrue);
    });
  });

  group('PLAN-049 P1-2 — chip gợi ý prompt', () {
    test('màn trống có 4 chuỗi gợi ý + callback onPick', () {
      for (final s in _suggestions) {
        expect(screenSrc.contains("'$s'"), isTrue,
            reason: 'Thiếu chuỗi gợi ý: $s');
      }
      expect(screenSrc.contains('onPick'), isTrue,
          reason: '_EmptyChat phải nhận callback để nạp chữ vào ô nhập');
      expect(screenSrc.contains('_controller.text = suggestion'), isTrue,
          reason: 'Chip phải ĐIỀN chữ vào ô nhập, không tự gửi');
    });

    test('4 chuỗi có trong legacy JSON (en)', () {
      for (final s in _suggestions) {
        final en = legacy[s];
        expect(en, isNotNull,
            reason: '$s thiếu trong $_legacyJsonPath (rule #5)');
        expect(_vietnameseOnly.firstMatch(en as String), isNull,
            reason: 'Giá trị en không được chứa ký tự Việt: $s');
      }
    });

    test('4 chuỗi có trong priority pack, đủ 8 locale, sạch ký tự Việt', () {
      const locales = ['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];
      for (final s in _suggestions) {
        final entry = pack[s];
        expect(entry, isNotNull,
            reason: '$s thiếu trong $_packJsonPath (T2 wave-2)');
        expect(entry.keys.toSet(), containsAll(locales),
            reason: 'Pack thiếu locale cho: $s');
        for (final loc in locales) {
          final v = (entry[loc] as String?) ?? '';
          expect(v, isNotEmpty, reason: '$s[$loc] rỗng');
          if (loc != 'vi') {
            expect(_vietnameseOnly.firstMatch(v), isNull,
                reason: '$s[$loc] chứa ký tự Việt');
          }
        }
      }
    });

    test('fallback dart có en cho 4 chuỗi (tiền lệ thêm tay 71d53978)', () {
      for (final s in _suggestions) {
        expect(RegExp("'${RegExp.escape(s)}': '").hasMatch(fallbacksSrc), isTrue,
            reason: 'Thiếu fallback en cho: $s');
      }
    });
  });

  group('PLAN-049 P1-3 — xác nhận trước khi xoá hội thoại', () {
    test('clearChat chỉ gọi SAU confirm dialog', () {
      final clearIdx = screenSrc.indexOf('clearChat()');
      expect(clearIdx, greaterThan(0), reason: 'Không còn nút xoá chat');
      final confirmIdx = screenSrc.indexOf('showDialog<bool>');
      expect(confirmIdx, greaterThan(0),
          reason: 'Thiếu showDialog xác nhận trước khi xoá');
      expect(confirmIdx, lessThan(clearIdx),
          reason: 'showDialog phải đứng TRƯỚC clearChat()');
      expect(screenSrc.contains("uiText('Hủy')"), isTrue);
      expect(screenSrc.contains("uiText('Xóa')"), isTrue);
    });

    test('3 chuỗi dialog đã đăng ký (không sinh chuỗi mới)', () {
      expect(legacy['Xóa cuộc trò chuyện'], 'Clear conversation');
      expect(legacy['Hủy'], 'Cancel');
      expect(legacy['Xóa'], 'Delete');
    });
  });
}