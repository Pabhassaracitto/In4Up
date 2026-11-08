// test/perf/model_idle_watchdog_test.dart
//
// PERF-001-B — máy bắt cho "người gác cổng nhả model khi rảnh".
//
// 100% THUẦN: đồng hồ bơm từ ngoài (`now`), `autoStart: false` ⇒ không Timer,
// không `sleep`, không plugin, không thiết bị ⇒ không flaky.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/model_idle_watchdog.dart';

/// Đồng hồ giả — mỗi test tự bơm thời gian.
class _Clock {
  DateTime _now = DateTime.utc(2026, 11, 8, 12);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file.readAsStringSync();
}

void main() {
  group('PERF-001-B — hành vi watchdog', () {
    late _Clock clock;
    late List<String> logs;
    late ModelIdleWatchdog watchdog;

    setUp(() {
      clock = _Clock();
      logs = <String>[];
      watchdog = ModelIdleWatchdog(
        now: clock.call,
        autoStart: false,
        log: logs.add,
      );
    });

    tearDown(() => watchdog.dispose());

    test('rảnh < timeout ⇒ KHÔNG nhả', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);

      clock.advance(const Duration(minutes: 4, seconds: 59));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);
    });

    test('rảnh ≥ timeout ⇒ nhả ĐÚNG 1 lần (không gọi lặp mỗi nhịp)', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);

      clock.advance(const Duration(minutes: 5));
      expect(await watchdog.checkIdle(), isTrue);
      expect(unloads, 1);

      // 2 nhịp nữa vẫn rảnh — không được nhả lại (model đã nhả rồi).
      clock.advance(const Duration(minutes: 5));
      expect(await watchdog.checkIdle(), isFalse);
      clock.advance(const Duration(minutes: 5));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 1);
      expect(watchdog.unloadCountOf('m1'), 1);
    });

    test('touch() reset đồng hồ ⇒ chưa tới hạn thì không nhả', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);

      clock.advance(const Duration(minutes: 4));
      watchdog.touch('m1');
      clock.advance(const Duration(minutes: 4));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);

      clock.advance(const Duration(minutes: 1));
      expect(await watchdog.checkIdle(), isTrue);
      expect(unloads, 1);
    });

    test('sau khi đã nhả, touch() ⇒ lần rảnh sau nhả LẠI được (nạp lại rồi)', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);

      clock.advance(const Duration(minutes: 5));
      await watchdog.checkIdle();
      expect(unloads, 1);
      expect(watchdog.isUnloaded('m1'), isTrue);

      // Người dùng dùng lại model (engine nạp lại) rồi lại bỏ đó 5 phút.
      watchdog.touch('m1');
      expect(watchdog.isUnloaded('m1'), isFalse);
      clock.advance(const Duration(minutes: 5));
      await watchdog.checkIdle();
      expect(unloads, 2);
    });

    test('retain() đang giữ ⇒ không nhả; release() rồi quá timeout ⇒ nhả', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);

      watchdog.retain('m1');
      clock.advance(const Duration(minutes: 30));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);
      expect(watchdog.isRetained('m1'), isTrue);

      watchdog.release('m1');
      expect(watchdog.isRetained('m1'), isFalse);
      clock.advance(const Duration(minutes: 5));
      expect(await watchdog.checkIdle(), isTrue);
      expect(unloads, 1);
    });

    test('isBusy = true (đang có thao tác chạy) ⇒ không nhả', () async {
      var unloads = 0;
      var busy = true;
      watchdog.register('m1', () async => unloads++, isBusy: () => busy);

      clock.advance(const Duration(minutes: 60));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);

      busy = false;
      clock.advance(const Duration(minutes: 5));
      expect(await watchdog.checkIdle(), isTrue);
      expect(unloads, 1);
    });

    test('unload ném exception ⇒ watchdog KHÔNG crash, id khác vẫn chạy', () async {
      var okUnloads = 0;
      watchdog.register('hỏng', () async => throw StateError('native boom'));
      watchdog.register('tốt', () async => okUnloads++);

      clock.advance(const Duration(minutes: 5));
      // Không được ném ra ngoài.
      final result = await watchdog.checkIdle();

      expect(result, isTrue);
      expect(okUnloads, 1, reason: 'engine lành phải vẫn được nhả');
      expect(watchdog.unloadCountOf('hỏng'), 1);
      expect(
        logs.any((l) => l.contains('unload hỏng lỗi')),
        isTrue,
        reason: 'lỗi phải được LOG, không im lặng',
      );
    });

    test('enabled = false ⇒ KHÔNG BAO GIỜ nhả', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);
      watchdog.setEnabled(false);

      clock.advance(const Duration(hours: 5));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);

      watchdog.setEnabled(true);
      clock.advance(const Duration(minutes: 6));
      expect(await watchdog.checkIdle(), isTrue);
      expect(unloads, 1);
    });

    test('log đúng định dạng owner đọc được trong logcat', () async {
      watchdog.register('hymt', () async {});
      clock.advance(const Duration(minutes: 7));
      await watchdog.checkIdle();

      expect(
        logs.any((l) => l == '[in4up-perf] unload hymt sau 420s rảnh'),
        isTrue,
        reason: 'log thật: $logs',
      );
    });

    test('unregister() ⇒ không nhả model đã bỏ theo dõi', () async {
      var unloads = 0;
      watchdog.register('m1', () async => unloads++);
      watchdog.unregister('m1');

      clock.advance(const Duration(hours: 1));
      expect(await watchdog.checkIdle(), isFalse);
      expect(unloads, 0);
      expect(watchdog.isRegistered('m1'), isFalse);
    });

    test('touch()/retain() id chưa đăng ký = no-op (không tự tạo entry)', () async {
      watchdog.touch('chưa-có');
      watchdog.retain('chưa-có');
      expect(watchdog.isRegistered('chưa-có'), isFalse);
      clock.advance(const Duration(hours: 1));
      expect(await watchdog.checkIdle(), isFalse);
    });

    test('mặc định: BẬT, timeout 5 phút (đúng yêu cầu PERF-001-B)', () {
      expect(ModelIdleWatchdog.defaultEnabled, isTrue);
      expect(ModelIdleWatchdog.defaultIdleTimeout, const Duration(minutes: 5));
      final defaults = ModelIdleWatchdog(autoStart: false);
      expect(defaults.enabled, isTrue);
      expect(defaults.idleTimeout, const Duration(minutes: 5));
      defaults.dispose();
    });
  });

  group('PERF-001-B — engine offline đã nối watchdog (source-scan)', () {
    test('Hy-MT: đăng ký + touch trong chính engine', () {
      final source = _read('lib/features/translation/engines/hymt_engine.dart');
      expect(source.contains('ModelIdleWatchdog'), isTrue);
      expect(source.contains("register(\n      'hymt'") ||
          source.contains("'hymt'"), isTrue);
      expect(source.contains('disposeRuntime'), isTrue,
          reason: 'hàm nhả phải là disposeRuntime() có sẵn');
      expect(source.contains('watchdog.touch('), isTrue);
    });

    test('VieNeu-TTS: đăng ký + retain/release + nạp lại được sau khi nhả', () {
      final source = _read('lib/features/tts/engines/vieneu_tts_engine.dart');
      expect(source.contains('ModelIdleWatchdog'), isTrue);
      expect(source.contains("'vieneu_tts'"), isTrue);
      expect(source.contains("watchdog.touch('vieneu_tts')"), isTrue);
      expect(source.contains("watchdog.retain('vieneu_tts')"), isTrue);
      expect(source.contains("watchdog.release('vieneu_tts')"), isTrue);
      // Nạp lại: isAvailable phải còn báo "có model" sau khi nhả vì rảnh,
      // nếu không TtsService rơi sang engine khác vĩnh viễn.
      expect(
        source.contains('_modelResolved && (_initialized || _unloadedForIdle)'),
        isTrue,
      );
    });

    test('Gemma/AI: hook do app tiêm (không import ngược package:in4up)', () {
      final engine =
          _read('packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart');
      expect(engine.contains('onReadyHook'), isTrue);
      expect(engine.contains('onActivityHook'), isTrue);
      // in4up_ai KHÔNG được phụ thuộc package:in4up (vòng dependency).
      expect(engine.contains("package:in4up/services/model_idle_watchdog.dart"),
          isFalse);

      final mainDart = _read('lib/main.dart');
      expect(mainDart.contains('AiEngineGemma.onReadyHook'), isTrue);
      expect(mainDart.contains("register('ai_gemma'"), isTrue);
      expect(mainDart.contains('engine.dispose'), isTrue);
      expect(mainDart.contains('engine.isBusy'), isTrue);
    });

    test('STT/Sherpa CỐ Ý không nối — dispose() là teardown singleton', () {
      // Quy tắc dừng #3 (PERF-001): `SherpaModelManager.dispose()`
      // (packages/in4up_stt/lib/sherpa_model_manager.dart:3016) đóng
      // asrState/piperState/vadState và đặt `_instance = null` — gọi lúc app
      // đang chạy sẽ làm hỏng Settings đang subscribe. Model sherpa cũng đã
      // được free sau MỖI lần transcribe (stt_engine_sherpa.dart dispose()).
      final manager =
          _read('packages/in4up_stt/lib/sherpa_model_manager.dart');
      expect(manager.contains('ModelIdleWatchdog'), isFalse,
          reason: 'nếu nối STT thì phải làm API unload riêng, không dùng '
              'dispose() của singleton — xem PERF_001_MEASUREMENT.md');
    });
  });
}
