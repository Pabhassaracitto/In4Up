// test/tts/support/vieneu_l6_checks.dart — BETA-1.29.0 · lane L6
//
// Máy bắt cho bốn issue còn lại của lane L6 (PSRC-214…218). Tách thành thư
// viện có hàm đăng ký để dùng lại được từ file test ĐÃ nối vào CI
// (`test/tts/vieneu_state_contract_test.dart`, step `psrc-183-186-tests`) mà
// không phải sửa `.github/workflows/app_analyze.yml` (file của hub — xem
// `docs/project/beta-1.29.0/README.md` § 3).
//
// Nguyên tắc: mỗi bất biến phải là (a) logic THUẦN chạy được trên VM, hoặc
// (b) source-scan khoá cấu trúc đã sửa — không cần máy thật, không cần
// native lib, không cần plugin.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_model_files.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bỏ dòng comment `//` để source-scan không bắt nhầm chữ trong giải thích.
String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const List<String> _locales = <String>[
  'en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja',
];

/// Chuỗi UI mới của lane L6 đợt này (nguồn tiếng Việt = key trong pack).
const List<String> _l6NewUiStrings = <String>[
  'Tệp đã chọn không phải .gguf',
  'Tệp đã chọn rỗng — có thể quá trình tải/chép bị lỗi',
  'Tệp .gguf quá nhỏ (dưới 32 MB) — có thể tải hụt, tải lại rồi import',
  'Tệp không phải model GGUF hợp lệ (thiếu chữ ký GGUF) — kiểm tra lại nguồn tải',
  'Chưa import model VieNeu-TTS (.gguf)',
  'File model .gguf không dùng được (hỏng hoặc không phải GGUF) — import lại',
  'Bản cài này chưa kèm engine VieNeu-TTS (libvieneu_tts) nên model đã import chưa đọc được',
  'Thiếu từ điển phát âm sea_g2p.bin — tải trong Cài đặt › Giọng đọc',
  'Thư mục không có dữ liệu giọng hợp lệ — cần ref_codes.txt hoặc speaker.emb.txt',
  'Không đọc được thư mục đã chọn — cấp quyền truy cập hoặc chọn tệp trực tiếp',
  'Không đọc được tệp đã chọn — thử chọn lại',
  'Đã import {value0} · engine sẵn sàng',
  'Đã import {value0} nhưng engine chưa sẵn sàng: {value1}',
  'Đã import {value0} giọng mẫu nhưng engine chưa sẵn sàng: {value1}',
  'Các giọng này đã có trong ứng dụng',
  'Chưa khởi tạo được engine: {value0}',
  'Khởi tạo engine thất bại: {value0}',
  'Đã tạo giọng {value0} nhưng bằng embedding tạm (chưa có bộ mã hoá giọng) — giọng đọc gần giọng mặc định',
  'Không thể tạo giọng: {value0}',
  'Chọn file model VieNeu-TTS {value0}',
  'Đã import {value0} giọng mẫu',
  'Đã import {value0} · {value1} giọng mẫu',
  'Đã import {value0} · {value1} giọng mẫu · engine sẵn sàng',
  'Đã import {value0} · {value1} giọng mẫu nhưng engine chưa sẵn sàng: {value2}',
  'Đã import {value0} giọng từ thư mục',
  'Đã khởi tạo engine VieNeu-TTS ({value0})',
];

void registerVieneuL6Checks() {
  group('PSRC-214 — mọi lối import model đi qua CÙNG một đường kiểm', () {
    test('kiểm đuôi / rỗng / quá nhỏ / chữ ký GGUF', () {
      // Đuôi sai.
      expect(
        inspectVieneuModelHead(path: '/tmp/model.bin', bytes: 200 * 1024 * 1024),
        VieneuModelFileProblem.missingExtension,
      );
      // Rỗng.
      expect(
        inspectVieneuModelHead(path: '/tmp/model.gguf', bytes: 0),
        VieneuModelFileProblem.empty,
      );
      // Tải hụt: 1 MB với chữ ký đúng vẫn bị chặn.
      expect(
        inspectVieneuModelHead(
          path: '/tmp/model.gguf',
          bytes: 1024 * 1024,
          head: vieneuGgufMagic,
        ),
        VieneuModelFileProblem.tooSmall,
      );
      // Đủ lớn nhưng KHÔNG phải GGUF (ví dụ HTML tải hụt của trang release).
      expect(
        inspectVieneuModelHead(
          path: '/tmp/model.gguf',
          bytes: vieneuModelMinBytes,
          head: utf8.encode('<html>'),
        ),
        VieneuModelFileProblem.notGguf,
      );
      // Hợp lệ.
      expect(
        inspectVieneuModelHead(
          path: '/tmp/model.gguf',
          bytes: vieneuModelMinBytes,
          head: vieneuGgufMagic,
        ),
        isNull,
      );
      // Đuôi hoa (Android/SAF hay đổi) vẫn nhận.
      expect(
        inspectVieneuModelHead(
          path: '/tmp/MODEL.GGUF',
          bytes: vieneuModelMinBytes,
          head: vieneuGgufMagic,
        ),
        isNull,
      );
    });

    test('chữ ký GGUF đúng nghĩa 4 byte đầu', () {
      expect(hasVieneuGgufMagic(const <int>[0x47, 0x47, 0x55, 0x46]), isTrue);
      expect(hasVieneuGgufMagic(utf8.encode('GGUF')), isTrue);
      expect(hasVieneuGgufMagic(utf8.encode('GGU')), isFalse,
          reason: 'Thiếu byte ⇒ không được coi là hợp lệ');
      expect(hasVieneuGgufMagic(utf8.encode('GGML')), isFalse);
    });

    test('soi file thật trên đĩa: đọc được magic + dung lượng', () async {
      final dir = await Directory.systemTemp.createTemp('vieneu_l6_model_');
      try {
        final file = File('${dir.path}/vieneu-v3-turbo-q8_0.gguf');
        await file.writeAsBytes(<int>[...vieneuGgufMagic, 1, 2, 3, 4]);
        final report = await inspectVieneuModelOnDisk(file.path);
        expect(report.bytes, greaterThan(0));
        // File 8 byte < 32 MiB ⇒ tooSmall, KHÔNG phải notGguf (thứ tự kiểm).
        expect(report.problem, VieneuModelFileProblem.tooSmall);
        expect(report.variantName, 'q8_0');

        final bf16 = File('${dir.path}/vieneu-v3-turbo-bf16.gguf');
        await bf16.writeAsBytes(<int>[...vieneuGgufMagic, 9]);
        expect((await inspectVieneuModelOnDisk(bf16.path)).variantName, 'bf16');

        final missing = await inspectVieneuModelOnDisk('${dir.path}/nope.gguf');
        expect(missing.problem, VieneuModelFileProblem.empty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('UI: hai mục import (trên/dưới) gọi cùng một hàm, không còn lối cũ',
        () {
      final settings =
          _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));
      expect(settings.contains('_pickAndImport('), isFalse,
          reason: 'Lối import cũ (không kiểm tệp) phải biến mất');
      // Nút trên từng dòng biến thể + nút rộng phía dưới.
      expect(
          settings.contains('onPressed: () => _pickModelAndImport(variant),'),
          isTrue);
      expect(settings.contains('_pickModelAndImport(_selectedVariant)'), isTrue);
      // Không có lối nào gọi thẳng service mà bỏ qua bước kiểm/probe.
      final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
      expect(service.contains('inspectVieneuModelOnDisk(file.path)'), isTrue);
      expect(service.contains('VieneuModelImportException(report.problem!'),
          isTrue);
    });

    test('service ghi model theo BIẾN THỂ THẬT của tệp, không theo dòng UI',
        () {
      final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
      final start = service.indexOf('Future<VieneuImportResult> importVieneuModel(');
      final end = service.indexOf('Future<List<String>> _importBundledVoicesFromSource', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = service.substring(start, end);
      expect(body.contains('report.variantName'), isTrue,
          reason: 'Biến thể phải suy từ chính tên tệp người dùng chọn');
      expect(body.contains('effectiveVariant.fileName'), isTrue);
      expect(body.contains('setSelectedVieneuModelVariant(effectiveVariant)'),
          isTrue,
          reason: 'Không ghi prefs ⇒ lần mở app sau nạp biến thể khác');
    });
  });

  group('PSRC-215 — chỉ báo "thành công" khi engine nạp được model', () {
    test('kết quả import mang theo trạng thái engine', () {
      final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
      expect(service.contains('final VieneuEngineProbe readiness;'), isTrue);
      expect(service.contains('bool get engineReady => readiness.blocker == null;'),
          isTrue);
      expect(service.contains('await VieneuTtsEngine.instance.probe('), isTrue,
          reason: 'Import xong phải hỏi engine ngay, không đoán');
    });

    test('UI không báo xanh khi engine còn thiếu mảnh', () {
      final settings =
          _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));
      expect(settings.contains('_statusIsError = !imported.engineReady'), isTrue);
      expect(
          settings.contains(
              'Đã import {value0} nhưng engine chưa sẵn sàng: {value1}'),
          isTrue);
      expect(settings.contains('blockerKey: imported.blockerMessage'), isTrue,
          reason: 'Thông điệp phải nêu đúng mảnh còn thiếu (vd sea_g2p.bin)');
    });

    test('câu "thiếu từ điển" nêu đúng TÊN FILE', () {
      final message = vieneuEngineBlockerMessage(
          VieneuEngineBlocker.noPhonemeDictionary);
      expect(message.contains('sea_g2p.bin'), isTrue,
          reason: 'Người dùng phải biết cần tải file nào');
      expect(message.contains('Tải'), isFalse,
          reason: 'Câu nguồn trỏ tới nút tải trong Cài đặt, không tự nhét lệnh');
    });
  });

  group('PSRC-216 — engine nói đúng file/mảnh còn thiếu', () {
    test('thứ tự chặn: model → file hỏng → native → từ điển', () {
      expect(
        firstVieneuEngineBlocker(
          hasModel: false,
          nativeLibrary: false,
          phonemeDictionary: false,
        ),
        VieneuEngineBlocker.noModel,
        reason: 'Chưa có model là chặn đầu tiên, đừng doạ thiếu native',
      );
      expect(
        firstVieneuEngineBlocker(
          hasModel: true,
          nativeLibrary: true,
          phonemeDictionary: true,
          modelProblem: VieneuModelFileProblem.notGguf,
        ),
        VieneuEngineBlocker.modelUnreadable,
      );
      expect(
        firstVieneuEngineBlocker(
          hasModel: true,
          nativeLibrary: false,
          phonemeDictionary: false,
        ),
        VieneuEngineBlocker.noNativeLibrary,
      );
      expect(
        firstVieneuEngineBlocker(
          hasModel: true,
          nativeLibrary: true,
          phonemeDictionary: false,
        ),
        VieneuEngineBlocker.noPhonemeDictionary,
      );
      expect(
        firstVieneuEngineBlocker(
          hasModel: true,
          nativeLibrary: true,
          phonemeDictionary: true,
        ),
        isNull,
        reason: 'Đủ 3 mảnh ⇒ không còn chặn',
      );
    });

    test('mỗi chặn có một câu riêng, không dùng câu chung', () {
      final messages = <String>{
        for (final blocker in VieneuEngineBlocker.values)
          vieneuEngineBlockerMessage(blocker),
      };
      expect(messages.length, VieneuEngineBlocker.values.length,
          reason: 'Hai nguyên nhân khác nhau không được dùng chung một câu');
      for (final message in messages) {
        expect(message.trim(), isNotEmpty);
      }
    });

    test('engine có probe() và MỌI nhánh init đều ghi lý do', () {
      final engine =
          _codeOnly(_read('lib/features/tts/engines/vieneu_tts_engine.dart'));
      expect(engine.contains('Future<VieneuEngineProbe> probe('), isTrue);
      expect(engine.contains('firstVieneuEngineBlocker('), isTrue);
      expect(engine.contains('String? get lastInitError'), isTrue);

      final initStart = engine.indexOf('Future<void> _initOnce({');
      // Mốc phải là CODE: `_codeOnly` đã bỏ mọi dòng comment (kể cả `///`).
      final initEnd =
          engine.indexOf('Future<void> selectVoice(String voiceId) async {',
              initStart);
      expect(initStart, greaterThan(-1));
      expect(initEnd, greaterThan(initStart));
      final initBody = engine.substring(initStart, initEnd);
      // 4 nhánh chặn: thiếu model / thiếu native / file model hỏng / thiếu g2p.
      final assignments =
          RegExp(r'_blockingReason\s*=').allMatches(initBody).length;
      expect(assignments, greaterThanOrEqualTo(4),
          reason: 'Nhánh thoát nào không ghi lý do là nhánh UI nói sai');
      expect(initBody.contains('inspectVieneuModelOnDisk(model)'), isTrue);
    });

    test('UI "Khởi tạo engine" hỏi probe trước, hiện lỗi native nguyên văn', () {
      final settings =
          _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));
      expect(settings.contains('Future<void> _initializeEngine('), isTrue);
      expect(settings.contains('blockerKey: probe.message'), isTrue);
      expect(settings.contains('engine.lastInitError'), isTrue);
    });
  });

  group('PSRC-217 — import giọng: lý do có kiểu, đã có ≠ lỗi', () {
    test('thư mục giọng hợp lệ được nhận diện (và placeholder bị loại)',
        () async {
      final dir = await Directory.systemTemp.createTemp('vieneu_l6_voices_');
      try {
        final real = Directory('${dir.path}/minh_quan_pro');
        await real.create(recursive: true);
        await File('${real.path}/ref_codes.txt')
            .writeAsString('AQIDBAUGBwgJCgsMDQ4PEBESExQ=\n');
        final placeholder = Directory('${dir.path}/fake_voice');
        await placeholder.create(recursive: true);
        await File('${placeholder.path}/ref_codes.txt')
            .writeAsString('# VieNeu-TTS default\n');

        expect(await folderHasVieneuVoiceData(real), isTrue);
        expect(await folderHasVieneuVoiceData(placeholder), isFalse,
            reason: 'Placeholder toàn comment không phải một giọng');

        final found = await findVieneuVoiceFolders(dir);
        expect(found.map((d) => d.path.split(Platform.pathSeparator).last),
            <String>['minh_quan_pro']);

        // Chính thư mục là một giọng ⇒ trả về chính nó.
        final single = await findVieneuVoiceFolders(real);
        expect(single.length, 1);
        expect(single.first.path, real.path);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('thư mục không tồn tại ⇒ lỗi có kiểu `unreadable` (không phải câu chung)',
        () async {
      await expectLater(
        findVieneuVoiceFolders(Directory('/khong/ton/tai/vieneu')),
        throwsA(isA<VieneuVoiceImportException>().having(
          (e) => e.problem,
          'problem',
          VieneuVoiceImportProblem.unreadable,
        )),
      );
    });

    test('service: 0 giọng mới KHÔNG phải lỗi; UI nói rõ', () {
      final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
      final start =
          service.indexOf('Future<int> importVieneuVoicesFromDirectory(');
      final end = service.indexOf('Future<int> importVieneuVoiceFiles(', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = service.substring(start, end);
      expect(body.contains('findVieneuVoiceFolders(chosen)'), isTrue);
      expect(body.contains('VieneuVoiceImportProblem.noVoiceData'), isTrue);
      expect(body.contains('Không tìm thấy giọng hợp lệ trong thư mục'), isFalse,
          reason: 'Câu chung cho mọi trường hợp là gốc của PSRC-217');

      final settings =
          _codeOnly(_read('lib/features/tts/widgets/tts_settings_section.dart'));
      expect(settings.contains('vieneuVoiceImportProblemMessage(e.problem)'),
          isTrue);
      expect(settings.contains('Các giọng này đã có trong ứng dụng'), isTrue);
    });
  });

  group('PSRC-218 — tạo giọng từ mẫu: nói đúng lý do + giọng sống qua restart',
      () {
    test('embedding placeholder toàn 0 được nhận ra', () async {
      final dir = await Directory.systemTemp.createTemp('vieneu_l6_emb_');
      try {
        final placeholder = File('${dir.path}/speaker.emb.txt');
        final zeros = List<String>.filled(256, '0.000000').join(' ');
        await placeholder.writeAsString('256\n$zeros\n');
        expect(await isPlaceholderVieneuEmbedding(placeholder.path), isTrue);

        final real = File('${dir.path}/real.emb.txt');
        final values = List<String>.filled(256, '0.000000');
        values[7] = '0.481200';
        await real.writeAsString('256\n${values.join(' ')}\n');
        expect(await isPlaceholderVieneuEmbedding(real.path), isFalse);

        expect(await isPlaceholderVieneuEmbedding('${dir.path}/none.txt'),
            isFalse,
            reason: 'Không đọc được thì không kết luận — không doạ người dùng');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('service: engine chưa sẵn sàng ⇒ ném lỗi CÓ LÝ DO', () {
      final service = _codeOnly(_read('lib/features/tts/tts_service.dart'));
      final start = service.indexOf('Future<void> ensureVieneuWorkerReady()');
      // Mốc là CODE (dòng tiêu đề `GIAI ĐOẠN 3…` là comment nên đã bị bỏ).
      final end = service.indexOf(
          'Future<VieneuModelVariant> getSelectedVieneuModelVariant()', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = service.substring(start, end);
      expect(body.contains('VieneuEngineNotReadyException'), isTrue);
      expect(body.contains('probe(modelVariant: variant)'), isTrue);
      expect(body.contains("StateError('VieNeu worker chưa khởi tạo')"), isFalse,
          reason: 'Câu chung cho mọi nguyên nhân là gốc của PSRC-218');
    });

    test('UI clone: bắt lỗi có kiểu, cảnh báo embedding tạm, lưu lựa chọn', () {
      final clone =
          _codeOnly(_read('lib/features/tts/widgets/voice_clone_section.dart'));
      expect(clone.contains('on VieneuEngineNotReadyException catch (e)'), isTrue);
      expect(clone.contains('isPlaceholderVieneuEmbedding(embeddingPath)'),
          isTrue);
      expect(clone.contains('_CloneNotice.successPlaceholder'), isTrue);
      expect(clone.contains('setSelectedVieneuVoiceId(voiceId)'), isTrue,
          reason: 'Giọng vừa tạo phải được chọn và sống qua lần mở app sau');
      expect(clone.contains('_cloneErrorDetail = e.toString()'), isTrue,
          reason: 'Lỗi native nguyên văn phải vào log/UI, không nuốt');
    });
  });

  group('Rule #5 — chuỗi mới của lane L6 có đủ 8 locale', () {
    test('pack + file generated có đủ en/hi/zh/zh_TW/si/my/th/ja', () {
      final pack = jsonDecode(_read('tool/priority_native_pack.json'))
          as Map<String, dynamic>;
      final generated =
          _read('lib/core/language/generated_priority_native_pack.dart');
      for (final source in _l6NewUiStrings) {
        final entry = pack[source];
        expect(entry, isNotNull, reason: 'Thiếu key trong pack: $source');
        for (final locale in _locales) {
          final value = (entry as Map)[locale];
          expect(value, isA<String>(), reason: '$source [$locale]');
          expect((value as String).trim(), isNotEmpty,
              reason: '$source [$locale] rỗng');
        }
        expect(generated.contains(source), isTrue,
            reason: 'Chưa chạy generate_priority_native_pack.py cho: $source');
      }
    });
  });
}
