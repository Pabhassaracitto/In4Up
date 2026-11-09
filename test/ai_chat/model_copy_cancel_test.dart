// PSRC-23 — Nút Huỷ khi đang copy model.
//
// Test logic thuần (ModelCopyCancelToken + copyFileWithProgress) bằng temp
// dir — KHÔNG đụng path_provider/FilePicker (chỉ dart:io + flutter_test).
// Facade.cancelImport() được phủ gián tiếp: token cancel 2 lần no-op,
// cancel trước copy no-op, copy bị huỷ thì không còn file đích.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  group('PSRC-23 — ModelCopyCancelToken', () {
    test('cancel() 2 lần không ném exception', () {
      final token = ModelCopyCancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(() => token.cancel(), returnsNormally);
      expect(token.isCancelled, isTrue);
    });

    test('huỷ khi chưa copy → no-op, không crash', () {
      final token = ModelCopyCancelToken();
      expect(token.isCancelled, isFalse);
      expect(() => token.cancel(), returnsNormally);
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled ném khi đã huỷ, không ném khi chưa huỷ', () {
      final token = ModelCopyCancelToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
      token.cancel();
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<ModelCopyCancelledException>()),
      );
    });
  });

  group('PSRC-23 — copyFileWithProgress', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('psrc23_copy_test');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('copy đang chạy → cancel() → không còn file đích', () async {
      final src = File('${tmp.path}/src.gguf');
      final dest = File('${tmp.path}/dest.gguf');
      // File đủ lớn để copy mất vài chunk (không đọc cả file vào RAM).
      await src.writeAsBytes(List<int>.filled(1024 * 1024, 0x47));

      final token = ModelCopyCancelToken();
      final future = copyFileWithProgress(
        src: src,
        dest: dest,
        cancelToken: token,
      );
      // Huỷ ngay sau khi copy bắt đầu (giữa các chunk).
      token.cancel();
      await expectLater(
        future,
        throwsA(isA<ModelCopyCancelledException>()),
      );
      expect(await dest.exists(), isFalse,
          reason: 'File đích dở dang phải bị xoá khi huỷ');
    });

    test('copy không huỷ → file đích đầy đủ', () async {
      final src = File('${tmp.path}/src.gguf');
      final dest = File('${tmp.path}/dest.gguf');
      final data = List<int>.filled(4096, 0x47);
      await src.writeAsBytes(data);

      final token = ModelCopyCancelToken();
      await copyFileWithProgress(
        src: src,
        dest: dest,
        cancelToken: token,
      );
      expect(await dest.exists(), isTrue);
      expect(await dest.readAsBytes(), data);
    });

    test('huỷ trước khi copy → không tạo file đích', () async {
      final src = File('${tmp.path}/src.gguf');
      final dest = File('${tmp.path}/dest.gguf');
      await src.writeAsBytes(List<int>.filled(1024, 0x47));

      final token = ModelCopyCancelToken();
      token.cancel();
      await expectLater(
        copyFileWithProgress(src: src, dest: dest, cancelToken: token),
        throwsA(isA<ModelCopyCancelledException>()),
      );
      expect(await dest.exists(), isFalse);
    });
  });

  group('PSRC-23 — AiServiceFacade.cancelImport (logic stage)', () {
    test('cancelImport khi chưa copy → no-op, không crash', () {
      // Facade singleton — chỉ kiểm tra không ném khi idle.
      final facade = AiServiceFacade();
      expect(() => facade.cancelImport(), returnsNormally);
      // importStage không phải copying sau khi huỷ lúc idle.
      expect(facade.importStage, isNot(AiImportStage.copying));
    });

    test('canCancelImport chỉ true khi copying/downloading', () {
      final facade = AiServiceFacade();
      // Lúc idle (chưa copy) thì không huỷ được.
      if (facade.importStage == AiImportStage.idle ||
          facade.importStage == AiImportStage.ready ||
          facade.importStage == AiImportStage.failed) {
        expect(facade.canCancelImport, isFalse);
      }
    });
  });
}
