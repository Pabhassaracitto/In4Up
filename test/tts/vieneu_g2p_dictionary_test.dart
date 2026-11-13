// test/tts/vieneu_g2p_dictionary_test.dart — BETA-1.29.0 · lane L6
//
// Máy bắt cho đường **từ điển phát âm SEA-G2P** (`sea_g2p.bin`).
//
// Vì sao cần: engine VieNeu đã nằm trong APK (module `:vieneu`), nhưng model
// chỉ nhận *phoneme*; thiếu `sea_g2p.bin` thì mọi lần đọc đều lỗi — đúng kiểu
// "engine có mà không chạy" mà owner đã bác. Test khoá 4 nhóm bất biến:
//
//   1. Hằng số ghim: URL/sha256/kích thước phải khớp asset thật của tag
//      v0.10.0 (native lib trong APK cũng v0.10.0 — lệch bản là lỗi khó hiểu).
//   2. Ghi atomically: tải ra `.part`, kiểm sha256 TRƯỚC khi rename đè file
//      đang dùng ⇒ mạng đứt không để lại file hỏng.
//   3. Engine chặn TRƯỚC khi nạp model (~170 MB) khi thiếu từ điển, và nói
//      đúng lý do (`blockingReason`).
//   4. UI có lối vào (tải + chọn tệp) và mọi chuỗi mới đều có bản dịch 8 locale.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bỏ dòng comment `//` để source-scan không bắt nhầm chữ trong giải thích.
String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// 13 chuỗi UI mới của lane L6 (nguồn tiếng Việt = key trong pack).
const List<String> _newUiStrings = <String>[
  'Từ điển phát âm (SEA-G2P)',
  'Model chỉ nhận phiên âm, không nhận chữ thô — thiếu từ điển này VieNeu chưa đọc được.',
  'Đã có từ điển ({value0})',
  'Chưa có từ điển phát âm',
  'Tải từ điển (~60 MB)',
  'Đang tải từ điển… {value0}%',
  'Chọn tệp sea_g2p.bin',
  'Đã cài từ điển phát âm ({value0})',
  'Tệp từ điển tải về không khớp kiểm tra — thử lại sau',
  'Tệp không phải sea_g2p.bin hợp lệ',
  'Không ghi được từ điển vào bộ nhớ app',
  'Không tải được từ điển — kiểm tra mạng rồi thử lại',
  'Không cài được từ điển phát âm',
];

const List<String> _locales = <String>[
  'en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja',
];

void main() {
  group('SEA-G2P — hằng số ghim', () {
    test('URL tải đúng tag v0.10.0 và đúng tên asset', () {
      expect(vieneuG2pReleaseTag, 'v0.10.0');
      expect(vieneuG2pDictDownloadUrl, contains('/v0.10.0/'));
      expect(vieneuG2pDictDownloadUrl, endsWith('/sea_g2p.bin'));
      expect(vieneuG2pDictDownloadUrl, startsWith('https://github.com/'));
    });

    test('sha256 + kích thước khớp asset thật của release', () {
      expect(vieneuG2pDictSha256.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(vieneuG2pDictSha256), isTrue);
      // 62.829.820 byte = đúng asset v0.10.0 trên GitHub.
      expect(vieneuG2pDictBytes, 62829820);
      // Ngưỡng "trông giống từ điển thật" phải thấp hơn file thật nhưng cao
      // hơn mọi file rác người dùng có thể chọn nhầm.
      expect(vieneuG2pDictMinBytes, lessThan(vieneuG2pDictBytes));
      expect(vieneuG2pDictMinBytes, greaterThanOrEqualTo(32 * 1024 * 1024));
    });

    test('nhận diện tên file và đường dẫn đích', () {
      expect(isVieneuG2pDictionaryFile('/a/b/sea_g2p.bin'), isTrue);
      expect(isVieneuG2pDictionaryFile('/a/b/SEA_G2P.BIN'), isTrue,
          reason: 'Android/SAF hay trả tên hoa — so sánh không phân biệt');
      expect(isVieneuG2pDictionaryFile('/a/b/sea_g2p.bin.part'), isFalse,
          reason: 'File tải dở KHÔNG được coi là từ điển');
      expect(isVieneuG2pDictionaryFile('/a/b/config.json'), isFalse);
      expect(
        vieneuG2pDictionaryPath('/data/app/vieneu_tts'),
        endsWith('/vieneu_tts/sea_g2p.bin'),
      );
    });

    test('ngưỡng kích thước + nhãn dung lượng', () {
      expect(isPlausibleVieneuG2pDictionarySize(0), isFalse);
      expect(isPlausibleVieneuG2pDictionarySize(vieneuG2pDictMinBytes - 1),
          isFalse);
      expect(isPlausibleVieneuG2pDictionarySize(vieneuG2pDictMinBytes), isTrue);
      expect(isPlausibleVieneuG2pDictionarySize(vieneuG2pDictBytes), isTrue);
      // 62.829.820 B ≈ 59,9 MiB — UI hiển thị dấu phẩy như phần còn lại của app.
      expect(formatVieneuDictionarySize(vieneuG2pDictBytes), '59,9 MB');
    });
  });

  group('SEA-G2P — cách cài (atomically, kiểm digest)', () {
    final service = _codeOnly(_read('lib/features/tts/vieneu_g2p_dictionary.dart'));

    test('tải ra .part rồi mới rename', () {
      expect(service, contains(r"final partial = '$target.part';"));
      expect(service, contains(r'await File(partial).rename(target);'));
      expect(
        service.indexOf('final partial'),
        lessThan(service.indexOf('rename(target)')),
        reason: 'Phải ghi file tạm trước khi thay file đang dùng',
      );
    });

    test('kiểm sha256 TRƯỚC khi rename đè từ điển đang dùng', () {
      final check = service.indexOf('digest.toString() != vieneuG2pDictSha256');
      final rename = service.indexOf('await File(partial).rename(target);');
      expect(check, greaterThan(-1), reason: 'Thiếu so sánh digest');
      expect(rename, greaterThan(-1));
      expect(check, lessThan(rename),
          reason: 'Rename trước khi kiểm ⇒ file hỏng thay thế file tốt');
      expect(service, contains('VieneuG2pFailure.checksum'));
    });

    test('file người dùng tự chọn vẫn phải qua kiểm tên + kích thước', () {
      expect(service, contains('isVieneuG2pDictionaryFile(sourcePath)'));
      expect(service, contains('isPlausibleVieneuG2pDictionarySize(bytes)'));
      expect(service, contains('VieneuG2pFailure.notDictionary'));
    });

    test('sau khi cài thì dọn worker cũ (invalidate)', () {
      expect(service, contains('await VieneuTtsEngine.instance.invalidate();'));
      expect(service, contains('Future<void> _afterInstall() async {'));
    });

    test('không ném lỗi khi đọc trạng thái thất bại (UI không được văng)', () {
      expect(service, contains('Future<VieneuG2pStatus> status() async {'));
      expect(service, contains('VieneuG2pStatus(installed: false)'));
    });
  });

  group('SEA-G2P — engine chặn trước khi nạp model', () {
    final engine = _codeOnly(_read('lib/features/tts/engines/vieneu_tts_engine.dart'));

    test('có hasPhonemeDictionary()', () {
      expect(engine, contains('Future<bool> hasPhonemeDictionary() async {'));
      expect(engine, contains('vieneuG2pDictionaryPath(dir)'));
    });

    test('_initOnce thoát SỚM khi thiếu từ điển, trước _core.init', () {
      final initOnce = engine.indexOf('Future<void> _initOnce({');
      expect(initOnce, greaterThan(-1));
      final body = engine.substring(initOnce);
      final guard = body.indexOf('if (!await hasPhonemeDictionary())');
      final nativeInit = body.indexOf('await _core.init(');
      expect(guard, greaterThan(-1), reason: 'Thiếu chốt chặn từ điển');
      expect(nativeInit, greaterThan(-1));
      expect(guard, lessThan(nativeInit),
          reason: 'Nạp 170 MB rồi mới báo thiếu từ điển = phí RAM + chậm');
    });

    test('lý do chặn được nói ra thay vì mặc định "chưa import model"', () {
      expect(engine, contains('String? get blockingReason => _blockingReason;'));
      expect(engine, contains('error: _blockingReason ??'));
      expect(engine, contains("'Thiếu từ điển phát âm sea_g2p.bin"));
    });
  });

  group('SEA-G2P — UI có lối vào và chuỗi có bản dịch', () {
    final section = _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));

    test('card từ điển được render trong mục import model', () {
      expect(section, contains('Widget _buildG2pCard(BuildContext context) {'));
      expect(section, contains('_buildG2pCard(context),'));
      expect(section, contains('Future<void> _downloadG2p() async {'));
      expect(section, contains('Future<void> _pickG2pFile() async {'));
      // Trạng thái phải được đọc lại mỗi lần mở màn (không cache từ lần trước).
      expect(section, contains('VieneuG2pDictionaryService.instance.status()'));
    });

    test('mọi chuỗi mới có đủ 8 locale trong pack + file generated', () {
      final pack = jsonDecode(
        _read('tool/priority_native_pack.json'),
      ) as Map<String, dynamic>;
      final generated =
          _read('lib/core/language/generated_priority_native_pack.dart');
      for (final source in _newUiStrings) {
        final entry = pack[source];
        expect(entry, isNotNull, reason: 'Thiếu key trong pack: $source');
        for (final locale in _locales) {
          final value = (entry as Map)[locale];
          expect(value, isA<String>(), reason: '$source [$locale]');
          expect((value as String).trim(), isNotEmpty,
              reason: '$source [$locale] rỗng');
        }
        expect(generated, contains(source),
            reason: 'Chưa chạy generate_priority_native_pack.py cho: $source');
      }
    });
  });
}
