// CABIN-FLUSH-001 / CABIN-KEEP-PARTIAL-001 / CABIN-STAGE-001 (2026-10-29)
//
// Máy bắt cho yêu cầu của owner: **"đảm bảo âm thanh được nhận diện và chuyển
// đổi một cách triệt để, tránh bị mất, thiếu"** ở chế độ Cabin Live.
//
// Bối cảnh: owner so bản 1.20.0 (nhánh 251e) với nhánh c26 và thấy bên c26
// "nhận diện tốt hơn + có cơ chế xác nhận chuyên nghiệp". Sau khi đối chiếu:
// **5/5 commit mà agent kia đề xuất cherry-pick ĐÃ CÓ trong 251e** (kiểm bằng
// `git merge-base --is-ancestor`), nên không cherry-pick lại (sẽ chỉ tạo
// commit rỗng/trùng). Phần THỰC SỰ thiếu ở 251e là:
//   1. badge giai đoạn caption (ĐANG NHẬN / ĐÃ CHỐT / ĐÃ DỊCH) — port từ
//      `fb3c1261` của c26 (đây là "cơ chế xác nhận" owner nhìn thấy);
//   2. hai lỗ **mất câu** mà 251e còn hở:
//      • bấm Stop/Tạm dừng khi engine CHƯA phát `isFinal` ⇒ câu đang nói bị
//        bỏ (silence timer đã bị huỷ ở đầu hàm) ⇒ phải tự chốt câu partial;
//      • đang DỊCH (async vài giây) mà người dùng nói tiếp ⇒ gán đè
//        `_activeCaption` bằng câu cũ ⇒ câu mới biến mất.
//
// Vì `SttsCabinService` phụ thuộc plugin (mic/TTS/STT) nên không dựng được ở
// host VM; repo này dùng pattern **source-scan pin** cho loại bảo đảm này
// (xem `test/read_mode/line_edit_gesture_test.dart`). Test đọc mã nguồn và
// khẳng định các bước bảo vệ còn nguyên — ai gỡ sẽ đỏ ngay.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Không thấy file: $path');
  return file.readAsStringSync();
}

void main() {
  final service = _read('lib/features/cabin/services/stts_cabin_service.dart');
  final screen = _read('lib/features/cabin/screens/live_cabin_screen.dart');

  group('CABIN-FLUSH-001 — không mất câu đang nói khi Stop / Tạm dừng', () {
    test('có hàm chốt nốt câu partial trước khi đóng phiên', () {
      expect(
        service.contains('_flushActivePartialBeforeClose'),
        isTrue,
        reason: 'Thiếu bước chốt câu partial ⇒ bấm Stop giữa câu sẽ MẤT câu '
            'cuối (engine chưa kịp phát isFinal).',
      );
    });

    test('stopCabin gọi flush TRƯỚC khi đợi hàng đợi + đóng phiên', () {
      final stopIndex = service.indexOf('Future<void> stopCabin() async {');
      expect(stopIndex, greaterThan(0), reason: 'Không thấy stopCabin()');

      final flushIndex = service.indexOf(
        '_flushActivePartialBeforeClose()',
        stopIndex,
      );
      final drainIndex = service.indexOf(
        '_drainPendingFinalizations()',
        stopIndex,
      );
      final endIndex = service.indexOf('_endSession()', stopIndex);

      expect(flushIndex, greaterThan(stopIndex),
          reason: 'stopCabin phải gọi _flushActivePartialBeforeClose()');
      expect(
        flushIndex,
        lessThan(drainIndex),
        reason: 'Phải FLUSH trước khi drain, nếu không hàng đợi rỗng và câu '
            'đang nói không bao giờ được chốt.',
      );
      expect(
        flushIndex,
        lessThan(endIndex),
        reason: 'Phải chốt câu TRƯỚC khi đóng phiên (endSession) — sau đó '
            'journal đã đóng, câu sẽ mất khỏi bản lưu.',
      );
    });

    test('tạm dừng (togglePause) cũng chốt câu đang nhận', () {
      final pauseIndex = service.indexOf('Future<void> togglePause() async {');
      expect(pauseIndex, greaterThan(0));
      final flushIndex =
          service.indexOf('_flushActivePartialBeforeClose()', pauseIndex);
      expect(flushIndex, greaterThan(pauseIndex),
          reason: 'Tạm dừng cũng phải flush, nếu không câu đó biến mất.');
    });

    test('listener STT KHÔNG bị huỷ trước khi engine flush (f45672c8 còn nguyên)', () {
      // Bản cũ huỷ `_sttSubscription` ngay đầu stopCabin ⇒ mất câu cuối.
      final stopIndex = service.indexOf('Future<void> stopCabin() async {');
      final cancelIndex =
          service.indexOf('_sttSubscription?.cancel()', stopIndex);
      final stopListeningIndex =
          service.indexOf('await _stt.stopListening()', stopIndex);
      expect(stopListeningIndex, greaterThan(stopIndex));
      expect(
        cancelIndex,
        greaterThan(stopListeningIndex),
        reason: 'Huỷ listener TRƯỚC stopListening sẽ nuốt mất câu cuối '
            '(đúng bug mà commit f45672c8 đã sửa).',
      );
    });
  });

  group('CABIN-KEEP-PARTIAL-001 — câu nói trong lúc đang dịch không bị đè', () {
    test('chỉ gán _activeCaption khi không có partial mới hơn', () {
      expect(
        service.contains('hasNewerPartial'),
        isTrue,
        reason: 'Thiếu guard ⇒ bản dịch xong (async) sẽ đè lên câu mới đang '
            'nhận ⇒ câu mới mất hoàn toàn.',
      );
      // Guard phải dùng cả 3 điều kiện: có caption, chưa final, text khác.
      final guardIndex = service.indexOf('final hasNewerPartial');
      final guardBlock = service.substring(guardIndex, guardIndex + 500);
      expect(guardBlock.contains('!current.isFinal'), isTrue);
      expect(guardBlock.contains('!= trimmed'), isTrue);
    });

    test('lỗi dịch KHÔNG làm mất câu gốc (vẫn vào history + journal)', () {
      final fnIndex = service.indexOf('Future<void> _finalizeCurrentChunk');
      final body = service.substring(fnIndex, fnIndex + 4000);
      expect(body.contains('catch (e)'), isTrue,
          reason: 'Dịch lỗi phải được bắt, không ném ra ngoài.');
      expect(
        body.contains('_history.add(finalizedCaption)'),
        isTrue,
        reason: 'Câu gốc phải vào history kể cả khi dịch lỗi/rỗng.',
      );
      expect(
        body.contains('recorder?.addEntry('),
        isTrue,
        reason: 'Câu gốc phải ghi vào journal phiên (để lưu WAV+LRC).',
      );
    });
  });

  group('CABIN-STAGE-001 — cơ chế xác nhận: badge giai đoạn trong transcript', () {
    test('transcript hiện 3 giai đoạn ĐANG NHẬN / ĐÃ CHỐT / ĐÃ DỊCH', () {
      expect(screen.contains("context.uiText('ĐANG NHẬN')"), isTrue);
      expect(screen.contains("context.uiText('ĐÃ CHỐT')"), isTrue);
      expect(screen.contains("context.uiText('ĐÃ DỊCH')"), isTrue);
    });

    test('3 chuỗi đã đăng ký i18n rule #5 (đủ 5 locale)', () {
      final overrides =
          _read('lib/core/language/priority_ui_overrides.dart');
      for (final label in ['ĐANG NHẬN', 'ĐÃ CHỐT', 'ĐÃ DỊCH']) {
        final index = overrides.indexOf("'$label'");
        expect(index, greaterThan(0), reason: 'Thiếu chuỗi $label trong catalog');
        final block = overrides.substring(index, index + 420);
        for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          expect(
            block.contains("'$locale'"),
            isTrue,
            reason: '$label thiếu bản dịch $locale (rule vàng #5)',
          );
        }
      }
    });
  });
}
