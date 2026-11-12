// test/tts/vieneu_state_contract_test.dart — PSRC-183..186
//
// "Máy bắt" cấu trúc: các bất biến đã sửa phải CÒN trong code, không bị
// merge/commit sau đó đưa ngược lại lỗi cũ. Thuần đọc file — không plugin,
// không isolate, chạy được ngay trên CI.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bỏ comment nguyên dòng để source-scan không bắt nhầm tên biến cũ nằm
/// trong comment giải thích (ví dụ `_modelResolved` ở PSRC-183).
String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Ký tự chỉ có trong tiếng Việt (tránh flag nhầm fr/es/pt/it).
final RegExp _viOnly = RegExp(
  r'[đĐơƠưƯ]|[ảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]',
);

void main() {
  group('worker protocol — PSRC-183/184', () {
    final core = _codeOnly(_read('packages/in4up_stt/lib/tts/vieneu_tts_core.dart'));
    test('response đi qua replyPort của main isolate', () {
      expect(core.contains('replyPort.send(response);'), isTrue);
      expect(core.contains('mainPort.sendPort.send(_respond'), isFalse,
          reason: 'Không được gửi response ngược lại vào port của worker');
      expect(
          core.contains(
              '<SendPort>[commandPort.sendPort, responsePort.sendPort]'),
          isTrue);
    });

    test('isInitialized chỉ true sau khi native init trả ok', () {
      expect(core.contains('bool get isInitialized => _ready;'), isTrue);
      expect(core.contains('_ready = true;'), isTrue);
      expect(core.contains('await _awaitReady();'), isTrue,
          reason: 'clone/synthesize phải chờ init đang bay');
    });

    test('dispose reset trạng thái và kill isolate', () {
      expect(core.contains('_workerIsolate?.kill('), isTrue);
      expect(core.contains('_ready = false;'), isTrue);
    });
  });

  group('một nguồn sự thật cho model/engine — PSRC-183', () {
    final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
    final engine =
        _codeOnly(_read('lib/features/tts/engines/vieneu_tts_engine.dart'));

    test('biến thể lưu trong prefs được đối chiếu với file thật', () {
      expect(service.contains('getAvailableVariants()'), isTrue);
      expect(service.contains('voicesRevision.value++'), isTrue);
      expect(service.contains('VieneuTtsEngine.instance.invalidate()'), isTrue);
    });

    test('isAvailable không cache trạng thái sai', () {
      expect(engine.contains('_modelResolved'), isFalse,
          reason: 'Bản cũ cache false → true ở lần gọi sau');
      expect(engine.contains('bool get isInitialized =>'), isTrue);
    });

    test('liệt kê giọng KHÔNG nạp model 170 MB', () {
      final start = engine.indexOf('Future<List<TtsVoice>> getAvailableVoices');
      final end = engine.indexOf('Future<void> init(', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = engine.substring(start, end);
      expect(body.contains('_core.init('), isFalse);
      expect(body.contains('await _readManifest('), isTrue);
    });
  });

  group('import giọng / mẫu — PSRC-185/186', () {
    final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
    final settings =
        _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));
    final clone = _codeOnly(_read('lib/features/tts/widgets/voice_clone_section.dart'));
    final cpp = _codeOnly(_read('native/tts_vieneu/vieneu_tts.cpp'));

    test('dò voices/ kèm GGUF qua nhiều ứng viên', () {
      expect(service.contains('bundledVoiceDirCandidates(ggufPath)'), isTrue);
      expect(service.contains('importVieneuBundleFromDirectory'), isTrue);
      expect(service.contains('importVieneuVoiceFiles'), isTrue);
    });

    test('mẫu chỉ nhận WAV ở cả Dart lẫn native', () {
      expect(service.contains('isVieneuVoiceSampleFile'), isTrue);
      final cloneStart = cpp.indexOf('vieneu_tts_clone_voice');
      final cloneEnd = cpp.indexOf('vieneu_tts_language_supported', cloneStart);
      expect(cloneStart, greaterThan(-1));
      expect(cloneEnd, greaterThan(cloneStart));
      final cloneFn = cpp.substring(cloneStart, cloneEnd);
      expect(cloneFn.contains('std::tolower'), isTrue);
      expect(cloneFn.contains('.u8string()'), isFalse,
          reason: 'C++20 `u8string()` không so sánh được với const char*');
    });

    test('picker lắng nghe revision riêng, không reload theo playback', () {
      final start = settings.indexOf('class _VieneuVoicePickerState');
      final end = settings.indexOf('class _LicenseSection', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final picker = settings.substring(start, end);
      expect(picker.contains('voicesRevision.addListener'), isTrue);
      expect(picker.contains('TtsService().addListener'), isFalse);
      expect(picker.contains('await engine.init('), isFalse);
    });

    test('clone chờ worker, giữ mẫu khi lỗi, dọn khi thành công', () {
      expect(clone.contains('ensureVieneuWorkerReady()'), isTrue);
      expect(clone.contains('_clearTempSamples()'), isTrue);
      expect(clone.contains('_countTempSamples()'), isTrue);
      expect(clone.contains('notifyVoicesChanged()'), isTrue);
      expect(clone.contains('sanitizeVieneuVoiceId'), isTrue);
      expect(clone.contains('vieneuTempSamplesDirName'), isTrue);
      expect(clone.contains('importVieneuSampleFiles('), isTrue);
      // Không kéo singleton TtsService vào initState (just_audio platform
      // channel làm văng test widget thuần).
      expect(clone.contains('TtsService().getVieneuSampleCount()'), isFalse);
    });

    test('status import lưu key nguồn, dịch lại khi đổi locale', () {
      expect(settings.contains('class _ImportStatus'), isTrue);
      expect(settings.contains('_status!.localize(context)'), isTrue);
      expect(settings.contains('context.uiText(_statusMessage!)'), isFalse);
      // Các nhãn có interpolation phải opt-in `uiText` (Text shim dùng
      // translateExact, template bị tắt).
      expect(RegExp(r"context\.uiText\(\s*'Đã import · ").hasMatch(settings),
          isTrue);
      expect(settings.contains("context.uiText('Đường dẫn: "), isTrue);
      expect(
          settings.contains("tooltip: context.uiText('Tải lại danh sách giọng')"),
          isTrue);
      expect(
          settings.contains("'\${context.uiText(subtitle)} · \$license'"),
          isTrue);
    });
  });

  group('Rule #5 — chrome VieNeu có English fallback', () {
    const newKeys = <String>[
      'Import giọng từ thư mục',
      'Import trọn bộ từ thư mục',
      'Thêm mẫu từ thư mục',
      'Khởi tạo engine',
      'Engine đã sẵn sàng',
      'Model đã có · engine nạp khi bắt đầu đọc',
      'Đã import {value0} mẫu WAV',
      'Đã import {value0} giọng từ thư mục',
      'Đã import {value0} · {value1} giọng mẫu',
      'Import {value0}',
      'Chọn thư mục chứa bộ model VieNeu-TTS',
      'Chọn file dữ liệu giọng VieNeu-TTS',
      'Giọng mẫu',
      'Đã clone',
    ];
    final overrides =
        jsonDecode(_read('tool/legacy_ui_english_overrides.json')) as Map;
    final generated =
        _read('lib/core/language/generated_legacy_ui_fallbacks.dart');
    final arbVi = jsonDecode(_read('lib/l10n/app_vi.arb')) as Map;
    final arbValues = arbVi.entries
        .where((e) => !e.key.toString().startsWith('@') && e.value is String)
        .map((e) => e.value as String)
        .toSet();

    test('mọi chuỗi mới có bản dịch en, không còn ký tự Việt', () {
      for (final key in newKeys) {
        expect(overrides.containsKey(key), isTrue,
            reason: 'Thiếu English override cho $key');
        final english = overrides[key] as String;
        expect(_viOnly.hasMatch(english), isFalse,
            reason: 'English fallback còn tiếng Việt: $key → $english');
        expect(generated.contains("'$key':"), isTrue,
            reason: 'Thiếu entry sinh ra cho $key');
      }
    });

    test('label đã có ARB không bị đưa vào legacy catalog (nợ generator)', () {
      for (final key in newKeys) {
        expect(arbValues.contains(key), isFalse,
            reason: '$key đã có ARB — không thuộc legacy overrides');
      }
      // Hai label ARB-backed từng bị quét nhầm ở v1 audit.
      expect(overrides.containsKey('Phiên bản mô hình'), isFalse);
      expect(overrides.containsKey(
              'Q8_0 (~170 MB) là mặc định, cân bằng chất lượng và dung lượng; bf16 (~292 MB) chất lượng cao hơn, file lớn hơn.'),
          isFalse);
    });
  });
}
