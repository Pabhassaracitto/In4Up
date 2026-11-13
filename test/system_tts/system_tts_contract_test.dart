// PSRC-221 — hợp đồng giữa Dart và phần native của "in4up làm giọng đọc hệ
// thống Android".
//
// Repo chưa có hạ tầng test Kotlin, và những lỗi ở đây đều IM LẶNG trên máy
// thật (in4up không hiện trong danh sách engine, nút "Nghe thử" bị khoá,
// engine nền báo "library not found"). Test này đọc thẳng file nguồn và khoá:
//   1. AndroidManifest khai đúng service + 3 activity mà Android đi tìm;
//   2. chuỗi giao thức ở Kotlin khớp `SystemTtsProtocol` (Dart);
//   3. entrypoint Dart tồn tại, được đánh dấu giữ lại và được main.dart import;
//   4. worker không đi qua engine online và không tự gọi lại giọng hệ thống.
// Biên dịch Kotlin thật do `vieneu_engine_build.yml` (build APK) đảm nhận.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/platform/system_tts/system_tts_backends.dart';
import 'package:in4up/core/platform/system_tts/system_tts_protocol.dart';
import 'package:in4up/core/platform/system_tts/system_tts_worker.dart';

const _kotlinDir = 'android/app/src/main/kotlin/com/in4up/systemtts';

String read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'thiếu file $path');
  return file.readAsStringSync();
}

/// Giá trị của `const val NAME = "…"` trong nguồn Kotlin.
String? kotlinConst(String source, String name) {
  final match = RegExp(
    'const val $name(?:\\s*:\\s*String)?\\s*=\\s*"([^"]*)"',
    multiLine: true,
  ).firstMatch(source);
  return match?.group(1);
}

void main() {
  group('AndroidManifest — Android tìm thấy engine', () {
    late String manifest;
    late String serviceBlock;

    setUpAll(() {
      manifest = read('android/app/src/main/AndroidManifest.xml');
      final match = RegExp(
        r'<service\s[^>]*com\.in4up\.systemtts\.In4UpTtsService[\s\S]*?</service>',
      ).firstMatch(manifest);
      expect(match, isNotNull, reason: 'manifest thiếu In4UpTtsService');
      serviceBlock = match!.group(0)!;
    });

    test('service exported + action TTS_SERVICE + metadata android.speech.tts',
        () {
      expect(serviceBlock, contains('android:exported="true"'));
      expect(
        serviceBlock,
        contains('<action android:name="android.intent.action.TTS_SERVICE"'),
      );
      expect(serviceBlock, contains('android:name="android.speech.tts"'));
      expect(serviceBlock, contains('android:resource="@xml/tts_engine"'));
      // Engine TTS không được đòi quyền riêng: Android/app khác sẽ không
      // bind được.
      expect(serviceBlock, isNot(contains('android:permission=')));
      // Không tách tiến trình: engine nền cần cùng FlutterLoader với app.
      expect(serviceBlock, isNot(contains('android:process=')));
    });

    test('ba activity của màn Cài đặt TTS đều exported và đúng action', () {
      const expected = <String, String>{
        'CheckVoiceDataActivity': 'android.speech.tts.engine.CHECK_TTS_DATA',
        'GetSampleTextActivity': 'android.speech.tts.engine.GET_SAMPLE_TEXT',
        'InstallVoiceDataActivity': 'android.speech.tts.engine.INSTALL_TTS_DATA',
      };
      final activities = read('$_kotlinDir/SystemTtsActivities.kt');
      for (final entry in expected.entries) {
        final match = RegExp(
          '<activity\\s[^>]*com\\.in4up\\.systemtts\\.${entry.key}'
          r'[\s\S]*?</activity>',
        ).firstMatch(manifest);
        expect(match, isNotNull, reason: 'manifest thiếu ${entry.key}');
        final block = match!.group(0)!;
        expect(block, contains('android:exported="true"'),
            reason: '${entry.key} phải exported (Cài đặt Android gọi vào)');
        expect(block, contains('<action android:name="${entry.value}"'));
        expect(activities, contains('class ${entry.key} '),
            reason: 'thiếu lớp Kotlin ${entry.key}');
      }
    });

    test('tts_engine.xml tồn tại và trỏ tới activity có thật', () {
      final xml = read('android/app/src/main/res/xml/tts_engine.xml');
      expect(xml, contains('<tts-engine'));
      final settings = RegExp(r'android:settingsActivity="([^"]+)"')
          .firstMatch(xml)
          ?.group(1);
      expect(settings, 'com.in4up.MainActivity');
      expect(manifest, contains('android:name=".MainActivity"'));
      expect(
        File('android/app/src/main/kotlin/com/in4up/MainActivity.kt')
            .existsSync(),
        isTrue,
      );
    });
  });

  group('Kotlin ↔ Dart — chuỗi giao thức', () {
    late String runtime;
    late String catalog;
    late String service;

    setUpAll(() {
      runtime = read('$_kotlinDir/SystemTtsRuntime.kt');
      catalog = read('$_kotlinDir/SystemTtsVoiceCatalog.kt');
      service = read('$_kotlinDir/In4UpTtsService.kt');
    });

    test('channel, entrypoint, method, khoá, trạng thái khớp từng chuỗi', () {
      const expected = <String, String>{
        'CHANNEL': SystemTtsProtocol.channel,
        'DART_ENTRYPOINT': SystemTtsProtocol.dartEntrypoint,
        'METHOD_READY': SystemTtsProtocol.methodReady,
        'METHOD_AUDIO': SystemTtsProtocol.methodAudio,
        'METHOD_LIST_VOICES': SystemTtsProtocol.methodListVoices,
        'METHOD_SYNTHESIZE': SystemTtsProtocol.methodSynthesize,
        'METHOD_CANCEL': SystemTtsProtocol.methodCancel,
        'KEY_REQUEST_ID': SystemTtsProtocol.keyRequestId,
        'KEY_TEXT': SystemTtsProtocol.keyText,
        'KEY_VOICE': SystemTtsProtocol.keyVoice,
        'KEY_LOCALE': SystemTtsProtocol.keyLocale,
        'KEY_RATE': SystemTtsProtocol.keyRate,
        'KEY_PITCH': SystemTtsProtocol.keyPitch,
        'KEY_SAMPLE_RATE': SystemTtsProtocol.keySampleRate,
        'KEY_PCM': SystemTtsProtocol.keyPcm,
        'KEY_VOICES': SystemTtsProtocol.keyVoices,
        'KEY_STATUS': SystemTtsProtocol.keyStatus,
        'KEY_MESSAGE': SystemTtsProtocol.keyMessage,
        'STATUS_OK': SystemTtsProtocol.statusOk,
        'STATUS_CANCELLED': SystemTtsProtocol.statusCancelled,
        'STATUS_NO_VOICE': SystemTtsProtocol.statusNoVoice,
        'STATUS_FAILED': SystemTtsProtocol.statusFailed,
      };
      for (final entry in expected.entries) {
        expect(kotlinConst(runtime, entry.key), entry.value,
            reason: 'SystemTtsRuntime.${entry.key} lệch với Dart');
      }
      // DART_LIBRARY xuống dòng sau dấu `=` nên so bằng chuỗi con.
      expect(runtime, contains('"${SystemTtsProtocol.dartLibrary}"'));
      expect(kotlinConst(catalog, 'KEY_NAME'), SystemTtsProtocol.keyName);
      expect(kotlinConst(catalog, 'KEY_LOCALE'), SystemTtsProtocol.keyLocale);
    });

    test('các giá trị giao thức không trùng nhau', () {
      const methods = <String>[
        SystemTtsProtocol.methodReady,
        SystemTtsProtocol.methodAudio,
        SystemTtsProtocol.methodListVoices,
        SystemTtsProtocol.methodSynthesize,
        SystemTtsProtocol.methodCancel,
      ];
      const statuses = <String>[
        SystemTtsProtocol.statusOk,
        SystemTtsProtocol.statusCancelled,
        SystemTtsProtocol.statusNoVoice,
        SystemTtsProtocol.statusFailed,
      ];
      expect(methods.toSet().length, methods.length);
      expect(statuses.toSet().length, statuses.length);
    });

    test('service là TextToSpeechService thật và trả lời đủ các câu hỏi', () {
      expect(service, contains('class In4UpTtsService : TextToSpeechService()'));
      for (final method in <String>[
        'onIsLanguageAvailable',
        'onGetLanguage',
        'onLoadLanguage',
        'onGetVoices',
        'onIsValidVoiceName',
        'onLoadVoice',
        'onGetDefaultVoiceNameFor',
        'onStop',
        'onSynthesizeText',
      ]) {
        expect(service, contains('override fun $method('),
            reason: 'In4UpTtsService thiếu $method');
      }
      // Định dạng khai với Android phải khớp thứ worker gửi (PCM16 mono).
      expect(service, contains('AudioFormat.ENCODING_PCM_16BIT, 1)'));
      expect(service, contains('callback.done()'));
    });

    test('danh mục giọng không chờ ở luồng chính (tránh tự khoá)', () {
      expect(
        runtime,
        contains('Looper.myLooper() == Looper.getMainLooper()'),
      );
    });
  });

  group('entrypoint Dart của engine nền', () {
    test('thư viện khai trong giao thức tồn tại và có hàm entrypoint', () {
      const prefix = 'package:in4up/';
      expect(SystemTtsProtocol.dartLibrary, startsWith(prefix));
      final path = 'lib/${SystemTtsProtocol.dartLibrary.substring(prefix.length)}';
      final source = read(path);
      expect(
        RegExp(
          "@pragma\\('vm:entry-point'\\)\\s+Future<void> "
          '${SystemTtsProtocol.dartEntrypoint}\\(\\)',
        ).hasMatch(source),
        isTrue,
        reason: 'entrypoint phải có @pragma(vm:entry-point) — thiếu là bản '
            'release cắt mất hàm',
      );
    });

    test('main.dart import entrypoint (không import ⇒ release không tìm thấy)',
        () {
      expect(
        read('lib/main.dart'),
        contains("import 'core/platform/system_tts/system_tts_entrypoint.dart';"),
      );
    });

    test('chỉ dùng engine OFFLINE, không tự gọi lại giọng hệ thống', () {
      final sources = <String>[
        read('lib/core/platform/system_tts/system_tts_backends.dart'),
        read('lib/core/platform/system_tts/system_tts_entrypoint.dart'),
        read('lib/core/platform/system_tts/system_tts_worker.dart'),
      ];
      const forbidden = <String>[
        'offline_tts_engine.dart', // flutter_tts = giọng hệ thống ⇒ vòng lặp
        'flutter_tts',
        'edge_tts_engine.dart',
        'google_tts_engine.dart',
        'fpt_tts_engine.dart',
        'zalo_tts_engine.dart',
        'openai_compat_tts_engine.dart',
        'tts_service.dart', // bộ định tuyến của app có nhánh online
      ];
      for (final source in sources) {
        final imports = source
            .split('\n')
            .where((line) => line.trimLeft().startsWith('import '))
            .join('\n');
        for (final name in forbidden) {
          expect(imports, isNot(contains(name)));
        }
      }
    });
  });

  group('giọng Piper → locale Android', () {
    test('suy locale từ tên model', () {
      expect(
        piperSystemTtsLocale('vi_VN-vais1000-medium', const <String, String>{}),
        'vi-VN',
      );
      expect(
        piperSystemTtsLocale('en_US-lessac-medium', const <String, String>{}),
        'en-US',
      );
    });

    test('tên không có mã ngôn ngữ ⇒ dùng ngôn ngữ người dùng đã gán', () {
      const preferred = <String, String>{
        'vi': 'calmwoman3688',
        'vi-VN': 'calmwoman3688',
        'en-US': 'en_US-lessac-medium',
      };
      expect(piperSystemTtsLocale('calmwoman3688', preferred), 'vi-VN');
      expect(
        piperSystemTtsLocale('calmwoman3688', const <String, String>{
          'vi': 'calmwoman3688',
        }),
        'vi',
      );
    });

    test('không biết ngôn ngữ ⇒ rỗng (không liệt kê cho Android)', () {
      expect(
        piperSystemTtsLocale('calmwoman3688', const <String, String>{}),
        '',
      );
      expect(
        piperSystemTtsLocale('calmwoman3688', const <String, String>{
          'en-US': 'en_US-lessac-medium',
        }),
        '',
      );
    });

    test('giọng người dùng đã chọn đứng trước (mặc định của ngôn ngữ)', () {
      const voices = <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'en_US-a', locale: 'en-US'),
        SystemTtsBackendVoice(voiceId: 'vi_VN-a', locale: 'vi-VN'),
        SystemTtsBackendVoice(voiceId: 'vi_VN-b', locale: 'vi-VN'),
      ];
      final ordered = orderPiperSystemVoices(voices, const <String, String>{
        'vi-VN': 'vi_VN-b',
      });
      expect(
        ordered.map((v) => v.voiceId).toList(),
        <String>['vi_VN-b', 'en_US-a', 'vi_VN-a'],
      );
      // Không có lựa chọn ⇒ giữ nguyên thứ tự.
      expect(
        orderPiperSystemVoices(voices, const <String, String>{})
            .map((v) => v.voiceId)
            .toList(),
        <String>['en_US-a', 'vi_VN-a', 'vi_VN-b'],
      );
    });
  });
}
