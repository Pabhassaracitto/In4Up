// IN4-80 — Import bản dịch Tipitaka thất bại với SQLITE_READONLY_DBMOVED.
//
// Root cause (đã xác minh trong code, không phải file hỏng):
// 1. MỌI import dùng CHUNG đường dẫn tạm `'$targetPath.importing'`.
// 2. `_openImportTarget` XOÁ file tạm nếu tồn tại.
// ⇒ Khi 2 import chạy song song (Pāli + Việt), import thứ hai XOÁ file mà
//    import thứ nhất đang giữ connection SQLite ⇒ cây `UPDATE` của import
//    thứ nhất trả SQLITE_READONLY_DBMOVED (1032) "attempt to write a
//    readonly database" — dù file hoàn toàn KHÔNG hỏng.
// 3. Thay file DB đích khi connection còn mở cũng cho lỗi tương tự.
//
// Fix: (a) đường dẫn tạm RIÊNG cho mỗi lần import; (b) khoá tuần tự hoá
// mọi thao tác import + cài đặt; (c) đóng connection trước khi thay file;
// (d) sao lưu `.bak` trước mọi thao tác phá hủy.
//
// Test thuần này pin các ràng buộc cấu trúc (không cần máy/DB thật).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dbService =
      File('lib/features/tipitaka/services/db_service.dart').readAsStringSync();
  final taskService = File(
          'lib/features/tipitaka/services/tipitaka_task_service.dart')
      .readAsStringSync();

  group('IN4-80 — đường dẫn tạm RIÊNG cho mỗi lần import', () {
    test(r'không còn đường dẫn tạm dùng chung "$targetPath.importing"', () {
      // Bỏ COMMENT trước khi so (ghi chú giải thích cũ có thể nhắc lại
      // chuỗi cũ mà không phải code).
      final code = dbService
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains("'\$targetPath.importing'"),
        isFalse,
        reason: 'Đường dẫn tạm dùng chung ⇒ import song song xoá nhau '
            '(nguyên nhân SQLITE_READONLY_DBMOVED).',
      );
    });

    test('có helper sinh đường dẫn tạm có timestamp (duy nhất)', () {
      expect(dbService.contains('_importTemporaryPath'), isTrue);
      expect(
        RegExp(r"_importTemporaryPath\(String targetPath\) =>")
            .hasMatch(dbService),
        isTrue,
        reason: 'Helper phải trả về đường dẫn duy nhất cho từng import.',
      );
    });

    test('cả 2 nhánh import (Pāli + bản dịch) dùng đường dẫn tạm riêng', () {
      // Tìm phần KHAI BÁO (chỗ gọi hàm nằm trước trong file), then bound
      // each body by the next method declaration (named-parameter braces are
      // part of the signature and are not the end of the function body).
      final pali = dbService.indexOf('static Future<String> _importPaliSource(');
      final translation =
          dbService.indexOf('static Future<String> _importTranslationSource(');
      final deduplicate = dbService.indexOf('static Future<void> _deduplicateCatalog(');
      expect(pali, greaterThan(0));
      expect(translation, greaterThan(pali));
      expect(deduplicate, greaterThan(translation));
      // Mỗi nhánh phải gọi helper (không tự chế đường dẫn tạm).
      final paliBody = dbService.substring(pali, translation);
      final translationBody = dbService.substring(translation, deduplicate);
      expect(paliBody, contains('_importTemporaryPath'));
      expect(translationBody, contains('_importTemporaryPath'));
    });
  });

  group('IN4-80 — khoá tuần tự hoá import (tránh 2 import song song)', () {
    test('có khoá import + hàng đợi', () {
      expect(dbService.contains('_withImportLock'), isTrue);
      expect(dbService.contains('_importQueue'), isTrue);
    });

    test('importSourceDatabase VÀ installDatabaseFile đều đi qua khoá', () {
      expect(
        RegExp(r'static Future<String> importSourceDatabase\([^)]*\)\s*\{[^}]*'
                r'_withImportLock')
            .hasMatch(dbService),
        isTrue,
        reason: 'importSourceDatabase phải xếp hàng.',
      );
      expect(
        RegExp(r'static Future<String> installDatabaseFile\([^)]*\)\s*\{[^}]*'
                r'_withImportLock')
            .hasMatch(dbService),
        isTrue,
        reason: 'installDatabaseFile phải xếp hàng (cũng thay DB đích).',
      );
    });

    test('KHÔNG tự gọi khoá lồng nhau (deadlock)', () {
      // Trong phần thân các hàm đang giữ khoá, không được gọi lại bản công
      // khai (bản công khai sẽ chờ khoá ⇒ treo).
      expect(
        dbService.contains('return _importSourceDatabaseLocked('),
        isTrue,
        reason: 'Phần thân đang giữ khoá phải gọi bản KHÔNG khóa.',
      );
      expect(
        dbService.contains('return await _installDatabaseFileLocked('),
        isTrue,
        reason: 'Nhánh archive phải gọi bản KHÔNG khóa.',
      );
    });
  });

  group('IN4-80 — đóng connection + sao lưu trước khi thay file', () {
    test('copyBundledDatabaseIfPresent đóng connection trước khi thay file',
        () {
      final idx = dbService.indexOf(
          'static Future<String?> copyBundledDatabaseIfPresent');
      expect(idx, greaterThan(0),
          reason: 'Phải tìm được phần KHAI BÁO hàm (không phải chỗ gọi).');
      final body = dbService.substring(
          idx, dbService.indexOf('\n  }', idx) + 4);
      expect(body, contains('await close();'),
          reason: 'Xoá/rename file khi SQLite còn giữ handle ⇒ DBMOVED.');
    });

    test('có sao lưu .bak trước khi thay DB cài đặt', () {
      expect(dbService.contains('_backupInstalledDatabase'), isTrue);
      expect(dbService.contains('.bak'), isTrue,
          reason: 'Phải giữ 1 bản sao lưu để khôi phục được.');
      // Atomic replacement first preserves the target as `.swap`; the `.bak`
      // copy must complete before that rename begins.
      final installIdx = dbService.indexOf('static Future<String> _installImportTarget(');
      expect(installIdx, greaterThan(0));
      final installBody = dbService.substring(installIdx);
      final backupIdx = installBody.indexOf('await _backupInstalledDatabase(');
      final swapIdx = installBody.indexOf('await destination.rename(swapBackup.path)');
      expect(backupIdx, greaterThan(0));
      expect(swapIdx, greaterThan(0));
      expect(backupIdx, lessThan(swapIdx),
          reason: 'Sao lưu phải hoàn tất trước khi thay file đích.');
    });
  });

  group('IN4-80 — coordinator không chạy 2 batch import song song', () {
    test('mọi import đi qua cùng một hàng đợi của db_service', () {
      // Coordinator gọi installDatabaseFile / importSourceDatabase — cả hai
      // đã khoá ở tầng DB ⇒ đủ an toàn dù coordinator cho phép task song song.
      expect(taskService, contains('TipitakaDb.importSourceDatabase'));
      expect(taskService, contains('TipitakaDb.installDatabaseFile'));
    });
  });
}
