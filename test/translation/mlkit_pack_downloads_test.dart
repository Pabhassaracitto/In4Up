// PSRC-188 (owner 2026-11-11) — *"cho tải gói dịch offline tiếp tục khi đóng
// popup"*.
//
// Hợp đồng phải giữ được (đây là lý do test này tồn tại):
//   1. Lượt tải KHÔNG thuộc về sheet: đóng sheet (State dispose, listener bị
//      gỡ) thì future vẫn chạy tới cùng và trạng thái vẫn đúng.
//   2. Mở lại giữa chừng ⇒ thấy `downloading`, KHÔNG quay về `missing`.
//   3. Mở lại sau khi xong ⇒ thấy `ready`, KHÔNG hiện lại "Tải về".
//   4. Bấm tải lần hai khi đang chạy ⇒ không gọi native lần hai (một lượt tải,
//      nhiều nơi cùng chờ).
//   5. `downloadModel()` trả `false` mà máy báo ĐÃ có gói ⇒ `ready` (PSRC-182:
//      không tin tuyệt đối giá trị trả về của plugin).
//   6. Thất bại ⇒ `failed` + giữ lý do; `refresh()` không xoá cờ thất bại ngay
//      (UI cần báo), nhưng máy báo có gói thì luôn `ready`.
//
// Thuần Dart — không cần plugin ML Kit / thiết bị.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/mlkit_pack_downloads.dart';

/// Bản giả của `MlKitEngine` + điều khiển thời điểm tải xong.
class _FakePacks {
  _FakePacks({this.platformSupported = true});

  bool platformSupported;
  final Map<String, Completer<bool>> pending = <String, Completer<bool>>{};
  final Map<String, bool> onDisk = <String, bool>{};
  final List<String> downloadCalls = <String>[];
  final List<String> isDownloadedCalls = <String>[];
  bool throwOnDownload = false;

  late final MlKitPackDownloads registry = MlKitPackDownloads(
    download: (code) {
      downloadCalls.add(code);
      if (throwOnDownload) throw StateError('native từ chối');
      final completer = Completer<bool>();
      pending[code] = completer;
      return completer.future;
    },
    isDownloaded: (code) async {
      isDownloadedCalls.add(code);
      return onDisk[code] ?? false;
    },
    platformSupported: () => platformSupported,
  );

  /// Chờ cho registry gọi tới hàm tải thật (future tải chỉ được tạo sau
  /// `isModelDownloaded` ⇒ phải nhường vài microtask).
  Future<void> _waitForPending(String code) async {
    for (var i = 0; i < 100 && !pending.containsKey(code); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(pending.containsKey(code), isTrue,
        reason: 'registry chưa gọi hàm tải cho "$code"');
  }

  /// Kết thúc lượt tải đang chờ của [code].
  Future<void> complete(
    String code, {
    bool ok = true,
    bool onDiskAfter = true,
  }) async {
    await _waitForPending(code);
    onDisk[code] = onDiskAfter;
    pending.remove(code)!.complete(ok);
  }

  /// Chỉ nhường microtask (cho registry kịp gọi `isModelDownloaded`).
  Future<void> settle() => Future<void>.delayed(Duration.zero);
}

void main() {
  group('PSRC-188 — lượt tải sống ngoài vòng đời sheet', () {
    test('đóng sheet giữa chừng: lượt tải vẫn chạy và vẫn báo đúng', () async {
      final fake = _FakePacks();
      var sheetOpen = true;
      var notificationsWhileOpen = 0;
      void listener() {
        if (sheetOpen) notificationsWhileOpen++;
      }

      fake.registry.addListener(listener);
      final future = fake.registry.start('vi');
      expect(fake.registry.statusOf('vi').isDownloading, isTrue);

      // User đóng sheet ⇒ State.dispose gỡ listener (đúng như code sheet).
      sheetOpen = false;
      fake.registry.removeListener(listener);
      final seenBefore = notificationsWhileOpen;

      // Tải vẫn chạy tiếp và xong bình thường.
      await fake.complete('vi');
      final status = await future;

      expect(status.isReady, isTrue, reason: 'đóng sheet không được huỷ tải');
      expect(fake.registry.statusOf('vi').isReady, isTrue);
      // Listener đã gỡ ⇒ không có notify nào cho sheet đã đóng (không crash,
      // không setState trên widget đã tháo).
      expect(notificationsWhileOpen, seenBefore,
          reason: 'gỡ listener phải thật sự ngắt thông báo');
      expect(fake.downloadCalls, <String>['vi'],
          reason: 'chỉ MỘT lượt tải native cho một gói');
    });

    test('mở lại khi đang tải ⇒ thấy "đang tải", KHÔNG về "chưa tải"', () async {
      final fake = _FakePacks();
      final future = fake.registry.start('hi');
      expect(fake.registry.statusOf('hi').isDownloading, isTrue,
          reason: 'phải chuyển "đang tải" NGAY (đồng bộ) khi vừa bấm');
      await fake.settle();

      // Sheet mở lại gọi refresh() cho các mã đang hiện.
      await fake.registry.refresh(<String>['en', 'vi', 'hi']);
      expect(fake.registry.statusOf('hi').isDownloading, isTrue,
          reason: 'refresh không được ghi đè gói đang tải thành missing');
      // Gói khác chưa có ⇒ missing (bấm tải được).
      expect(fake.registry.statusOf('en').state, MlKitPackState.missing);

      await fake.complete('hi');
      await future;
      expect(fake.registry.statusOf('hi').isReady, isTrue);
    });

    test('mở lại sau khi xong ⇒ ready + refresh xác nhận với máy', () async {
      final fake = _FakePacks();
      final future = fake.registry.start('en');
      await fake.complete('en');
      await future;

      await fake.registry.refresh(<String>['en', 'vi', 'hi']);
      expect(fake.registry.statusOf('en').isReady, isTrue);
      expect(fake.registry.statusOf('vi').state, MlKitPackState.missing);
      expect(fake.registry.statusOf('hi').state, MlKitPackState.missing);
    });

    test('bấm tải lần hai lúc đang chạy ⇒ dùng chung một future', () async {
      final fake = _FakePacks();
      final first = fake.registry.start('vi');
      final second = fake.registry.start('vi');
      expect(identical(first, second), isTrue,
          reason: 'bấm lại không được tạo lượt tải thứ hai');
      await fake.complete('vi');
      expect((await first).isReady, isTrue);
      expect((await second).isReady, isTrue);
      expect(fake.downloadCalls, <String>['vi']);
    });

    test('gói đã có sẵn trên máy ⇒ ready ngay, không gọi native tải', () async {
      final fake = _FakePacks()..onDisk['en'] = true;
      final status = await fake.registry.start('en');
      expect(status.isReady, isTrue);
      expect(fake.downloadCalls, isEmpty,
          reason: 'đã có gói thì không được tải lại (tốn pin/mạng)');
    });

    test('plugin trả false nhưng máy báo ĐÃ có gói ⇒ ready (PSRC-182)',
        () async {
      final fake = _FakePacks();
      final future = fake.registry.start('vi');
      // Kịch bản thật: `downloadModel()` trả false khi gói đã tồn tại.
      await fake.complete('vi', ok: false, onDiskAfter: true);
      final status = await future;
      expect(status.isReady, isTrue,
          reason: 'phải hỏi lại isModelDownloaded thay vì tin giá trị false');
    });

    test('thất bại ⇒ failed + giữ lý do; refresh không xoá ngay', () async {
      final fake = _FakePacks()..throwOnDownload = true;
      final status = await fake.registry.start('hi');
      expect(status.hasFailed, isTrue);
      expect(status.error, isNotNull);

      await fake.registry.refresh(<String>['hi']);
      expect(fake.registry.statusOf('hi').hasFailed, isTrue,
          reason: 'mở lại sheet ngay sau lỗi vẫn phải thấy lý do');

      // Lần tải lại thành công ⇒ ready, cờ lỗi biến mất.
      fake.throwOnDownload = false;
      final retry = fake.registry.start('hi');
      await fake.complete('hi');
      expect((await retry).isReady, isTrue);
      expect(fake.registry.statusOf('hi').error, isNull);
    });

    test('máy không hỗ trợ (desktop/web) ⇒ failed, không gọi native', () async {
      final fake = _FakePacks(platformSupported: false);
      final status = await fake.registry.start('vi');
      expect(status.hasFailed, isTrue);
      expect(fake.downloadCalls, isEmpty);
      await fake.registry.refresh(<String>['en', 'vi']);
      expect(fake.registry.statusOf('vi').state, MlKitPackState.missing);
    });

    test('xoá gói: đọc lại trạng thái THẬT thay vì đoán', () async {
      final fake = _FakePacks()..onDisk['en'] = true;
      await fake.registry.refresh(<String>['en']);
      expect(fake.registry.statusOf('en').isReady, isTrue);

      final status = await fake.registry.removed('en', (code) async {
        fake.onDisk[code] = false;
      });
      expect(status.state, MlKitPackState.missing);
    });

    test('xoá gói thất bại (native lỗi) ⇒ vẫn khớp trạng thái máy', () async {
      final fake = _FakePacks()..onDisk['en'] = true;
      final status = await fake.registry.removed('en', (code) async {
        throw StateError('không xoá được');
      });
      expect(status.isReady, isTrue,
          reason: 'xoá lỗi thì gói vẫn còn ⇒ UI phải hiện "Đã tải"');
    });

    test('downloadingCount/hasActiveDownloads phản ánh đúng để báo "ngầm"', () async {
      final fake = _FakePacks();
      expect(fake.registry.hasActiveDownloads, isFalse);
      final a = fake.registry.start('en');
      final b = fake.registry.start('vi');
      expect(fake.registry.downloadingCount, 2);
      expect(fake.registry.hasActiveDownloads, isTrue);
      await fake.complete('en');
      await fake.complete('vi');
      await a;
      await b;
      expect(fake.registry.hasActiveDownloads, isFalse);
      expect(fake.registry.downloadingCount, 0);
    });
  });
}
