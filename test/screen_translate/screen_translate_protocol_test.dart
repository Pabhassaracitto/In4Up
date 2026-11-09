// XLAT-SCR-002 — giao thức MethodChannel giữa Dart và Kotlin.
//
// Vì sao cần máy bắt: Kotlin đọc payload bằng CHUỖI khoá ("left", "blocks",
// "status"…). Đổi tên khoá ở Dart mà quên Kotlin ⇒ overlay rỗng im lặng,
// chỉ phát hiện được khi cầm máy thật. Test này khoá tên khoá lại.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/screen_translate/screen_translate_channel.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';

void main() {
  group('ScreenBlock / ScreenTranslateResult', () {
    test('toMap dùng đúng tên khoá mà Kotlin đọc', () {
      const block = ScreenBlock(
        rect: OverlayRect(left: 1, top: 2, right: 3, bottom: 4),
        original: 'Hello',
        translation: 'Xin chào',
        textSizeSp: 16.5,
      );
      final map = block.toMap();
      expect(map.keys.toSet(), <String>{
        'left',
        'top',
        'right',
        'bottom',
        'original',
        'translation',
        'textSizeSp',
      });
      expect(map['left'], 1);
      expect(map['translation'], 'Xin chào');
      expect(map['textSizeSp'], 16.5);
    });

    test('result.toMap: status là tên enum, blocks là List<Map>', () {
      const result = ScreenTranslateResult(
        status: ScreenTranslateStatus.ok,
        engine: 'mlkit',
        elapsed: Duration(milliseconds: 1234),
        blocks: <ScreenBlock>[
          ScreenBlock(
            rect: OverlayRect(left: 0, top: 0, right: 10, bottom: 10),
            original: 'a',
            translation: 'b',
          ),
        ],
      );
      final map = result.toMap();
      expect(map['status'], 'ok');
      expect(map['engine'], 'mlkit');
      expect(map['elapsedMs'], 1234);
      expect((map['blocks'] as List).single, isA<Map<String, Object?>>());
    });

    test('round-trip toMap → fromMap giữ nguyên dữ liệu', () {
      const original = ScreenTranslateResult(
        status: ScreenTranslateStatus.missingModel,
        message: 'thiếu model',
        missingModelCodes: <String>['VI', 'HI'],
        blocks: <ScreenBlock>[
          ScreenBlock(
            rect: OverlayRect(left: 5, top: 6, right: 7, bottom: 8),
            original: 'src',
            translation: '',
            textSizeSp: 12,
          ),
        ],
      );
      final restored = ScreenTranslateResult.fromMap(original.toMap());
      expect(restored.status, ScreenTranslateStatus.missingModel);
      expect(restored.missingModelCodes, <String>['VI', 'HI']);
      expect(restored.blocks.single.rect.left, 5);
      expect(restored.blocks.single.hasTranslation, isFalse);
    });

    test('status lạ từ native ⇒ quy về error (không ném)', () {
      final restored = ScreenTranslateResult.fromMap(<Object?, Object?>{
        'status': 'con-meo',
        'blocks': <Object?>['rác', 42],
      });
      expect(restored.status, ScreenTranslateStatus.error);
      expect(restored.blocks, isEmpty);
    });

    test('ScreenBlock.fromMap chấp nhận số thực từ native', () {
      final block = ScreenBlock.fromMap(<Object?, Object?>{
        'left': 1.6,
        'top': 2.2,
        'right': 9.0,
        'bottom': 12.0,
        'original': 'x',
        'translation': 'y',
      });
      expect(block, isNotNull);
      expect(block!.rect.left, 2);
      expect(block.rect.top, 2);
    });

    test('ScreenBlock.fromMap thiếu toạ độ ⇒ null (bỏ qua khối hỏng)', () {
      expect(
        ScreenBlock.fromMap(<Object?, Object?>{'original': 'x'}),
        isNull,
      );
    });
  });

  group('ScreenTranslateWorkerBinding', () {
    test('onFrame gọi callback và trả payload map', () async {
      Map<Object?, Object?>? received;
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (frame) async {
          received = frame;
          return const ScreenTranslateResult(
            status: ScreenTranslateStatus.noText,
            message: 'không có chữ',
          );
        },
      );
      final out = await binding.handleCall(
        const MethodCall(
          ScreenTranslateProtocol.methodOnFrame,
          <Object?, Object?>{'width': 10},
        ),
      );
      expect(received?['width'], 10);
      expect((out! as Map)['status'], 'noText');
    });

    test('onFrame với tham số không phải Map ⇒ error payload', () async {
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (_) async => const ScreenTranslateResult(
          status: ScreenTranslateStatus.ok,
        ),
      );
      final out = await binding.handleCall(
        const MethodCall(ScreenTranslateProtocol.methodOnFrame, 'xin chào'),
      );
      expect((out! as Map)['status'], 'error');
    });

    test('onStopped gọi callback dừng', () async {
      var stopped = false;
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (_) async =>
            const ScreenTranslateResult(status: ScreenTranslateStatus.ok),
        onStopped: () => stopped = true,
      );
      await binding.handleCall(
        const MethodCall(ScreenTranslateProtocol.methodOnStopped),
      );
      expect(stopped, isTrue);
    });

    test('method lạ ⇒ MissingPluginException', () async {
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (_) async =>
            const ScreenTranslateResult(status: ScreenTranslateStatus.ok),
      );
      await expectLater(
        binding.handleCall(const MethodCall('bay-len-troi')),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('ScreenTranslateChannel (nền tảng)', () {
    test('tên channel + method khớp hằng số dùng chung với Kotlin', () {
      expect(ScreenTranslateProtocol.controlChannel, 'in4up/screentranslate');
      expect(
        ScreenTranslateProtocol.workerChannel,
        'in4up/screentranslate/worker',
      );
      expect(ScreenTranslateProtocol.methodStart, 'start');
      expect(ScreenTranslateProtocol.methodOnFrame, 'onFrame');
    });

    test('desktop/host VM: mọi lệnh trả false, không ném', () async {
      // Test chạy trên host VM (không Android) ⇒ platformSupported = false.
      final channel = ScreenTranslateChannel(
        channel: const MethodChannel('in4up/screentranslate/test-unused'),
      );
      expect(ScreenTranslateChannel.platformSupported, isFalse);
      expect(await channel.isSupported(), isFalse);
      expect(await channel.start(targetLanguage: 'VI'), isFalse);
      expect(await channel.stop(), isFalse);
      expect(await channel.hasOverlayPermission(), isFalse);
    });
  });
}
