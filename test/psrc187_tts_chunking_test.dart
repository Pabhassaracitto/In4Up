// test/psrc187_tts_chunking_test.dart
//
// PSRC-187 (audit v1.27.0) — MÁY BẮT cho ba việc còn lại của issue:
//   (1) dòng dài của tab Đọc phải được đọc THEO ĐOẠN (Piper từng nhận nguyên
//       dòng trong một lượt chạy model: 786 ký tự ⇒ 935 MB, 2751 ký tự ⇒
//       3,4 GB RAM — đo trên giọng thật `vi_VN-vais1000-medium`);
//   (2) VieNeu-TTS: bản cài không có thư viện native thì engine phải nói
//       "không dùng được" ở MỌI lần hỏi và không spawn isolate nào; lõi
//       hỏi/đáp với worker phải thật sự chạy được (giao thức worker là của
//       PSRC-183/184 — PR #175; test ở đây chạy trên chính giao thức đó);
//   (3) câu báo "bản cài chưa kèm engine VieNeu" có đủ bản dịch (rule #5).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';
import 'package:in4up/features/tts/tts_text_chunker.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';

/// Đoạn kinh mẫu (393 ký tự) — nhân đôi thành dòng 786 ký tự đã dùng để đo RAM.
const String _sutta =
    'Này các Tỷ-kheo, đây là con đường độc nhất đưa đến thanh tịnh cho chúng '
    'sanh, vượt khỏi sầu não, diệt trừ khổ ưu, thành tựu chánh trí, chứng ngộ '
    'Niết-bàn. Đó là Bốn Niệm xứ. Thế nào là bốn? Này các Tỷ-kheo, ở đây '
    'Tỷ-kheo sống quán thân trên thân, nhiệt tâm, tỉnh giác, chánh niệm để chế '
    'ngự tham ưu ở đời. Sống quán thọ trên các thọ, nhiệt tâm, tỉnh giác, '
    'chánh niệm để chế ngự tham ưu ở đời. ';

const String _vieneuNotice =
    'Bản cài này chưa kèm engine VieNeu-TTS nên model đã import chưa đọc '
    'được. Khi VieNeu được ưu tiên, app sẽ đọc bằng nguồn phát kế tiếp.';

List<String> _words(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).join('\n');
}

String _code(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'thiếu $path');
  return _stripComments(file.readAsStringSync());
}

String _between(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: 'không thấy "$start"');
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: 'không thấy "$end" sau "$start"');
  return source.substring(a, b);
}

void main() {
  group('PSRC-187 — chunkTextForTts', () {
    test('câu ngắn giữ NGUYÊN VĂN (khoá cache không đổi)', () {
      expect(chunkTextForTts('  Xin chào. ', 280), ['  Xin chào. ']);
      expect(chunkTextForTts('abc', 3), ['abc']);
      expect(chunkTextForTts('abc', 0), ['abc']);
      expect(chunkTextForTts('abc', -1), ['abc']);
    });

    test('chỉ có khoảng trắng ⇒ không có gì để đọc', () {
      expect(chunkTextForTts('', 280), isEmpty);
      expect(chunkTextForTts('  \n\t ', 2), isEmpty);
    });

    test('dòng 786 ký tự ⇒ 4 đoạn, cắt ở CUỐI CÂU, không đoạn nào quá giới hạn',
        () {
      final line = _sutta * 2;
      expect(line.length, 786);
      final chunks = chunkTextForTts(line, kPiperTtsChunkChars);

      expect(chunks.map((c) => c.length).toList(), [189, 202, 189, 202]);
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(kPiperTtsChunkChars));
        expect(RegExp(r'[.!?]$').hasMatch(chunk), isTrue,
            reason: 'đoạn phải kết thúc ở cuối câu: "…${chunk.substring(chunk.length - 20)}"');
      }
      expect(_words(chunks.join(' ')), _words(line),
          reason: 'không được mất hay tách đôi từ nào');
    });

    test('dòng 2751 ký tự (ca 3,4 GB) ⇒ mọi đoạn ≤ giới hạn, đủ từ', () {
      final line = _sutta * 7;
      expect(line.length, 2751);
      final chunks = chunkTextForTts(line, kPiperTtsChunkChars);
      expect(chunks.length, greaterThanOrEqualTo(10));
      expect(
        chunks.every((c) => c.isNotEmpty && c.length <= kPiperTtsChunkChars),
        isTrue,
      );
      expect(_words(chunks.join(' ')), _words(line));
    });

    test('không cắt giữa số thập phân, số có dấu phẩy, số phiên bản', () {
      final numbers = 'Quãng đường dài 3.5 km, tốn 1,234 đồng. ' * 12;
      for (final chunk in chunkTextForTts(numbers, 100)) {
        expect(chunk.length, lessThanOrEqualTo(100));
        expect(chunk.endsWith('3.'), isFalse, reason: chunk);
        expect(chunk.endsWith('1,'), isFalse, reason: chunk);
        expect(chunk.startsWith('5 km'), isFalse, reason: chunk);
        expect(chunk.startsWith('234'), isFalse, reason: chunk);
      }
      expect(_words(chunkTextForTts(numbers, 100).join(' ')), _words(numbers));

      final version = 'Bản v1.27.0 có lỗi. ' * 30;
      for (final chunk in chunkTextForTts(version, 60)) {
        expect(RegExp(r'v1\.(?!27\.0)').hasMatch(chunk), isFalse, reason: chunk);
        expect(chunk.endsWith('lỗi.'), isTrue, reason: chunk);
      }
    });

    test('không có dấu câu ⇒ cắt ở khoảng trắng, không tách từ', () {
      final text = List<String>.filled(400, 'word').join(' ');
      final chunks = chunkTextForTts(text, 280);
      expect(chunks.every((c) => c.length <= 280), isTrue);
      expect(_words(chunks.join(' ')), _words(text));
    });

    test('tiếng Trung không có khoảng trắng ⇒ cắt sau dấu câu toàn hình', () {
      final text = '这是第一句话。这是第二句话！这是第三句话？' * 10;
      final chunks = chunkTextForTts(text, 40);
      expect(chunks.join(), text);
      expect(chunks.every((c) => c.length <= 40), isTrue);
      expect(chunks.first, '这是第一句话。这是第二句话！这是第三句话？这是第一句话。这是第二句话！');
    });

    test('chuỗi liền không có chỗ ngắt ⇒ cắt cứng đúng giới hạn', () {
      final text = 'a' * 1000;
      final chunks = chunkTextForTts(text, 300);
      expect(chunks.map((c) => c.length).toList(), [300, 300, 300, 100]);
      expect(chunks.join(), text);
    });

    test('cắt cứng không xẻ đôi một cặp surrogate (emoji)', () {
      final text = '😀' * 100; // 200 đơn vị UTF-16
      final chunks = chunkTextForTts(text, 51);
      expect(chunks.join(), text);
      for (final chunk in chunks) {
        expect(chunk.length.isEven, isTrue, reason: 'cặp surrogate bị xẻ');
        expect(chunk.runes.every((r) => r == 0x1F600), isTrue);
      }
    });

    test('giới hạn đoạn của Piper / online đúng như đã chốt', () {
      expect(kPiperTtsChunkChars, 280);
      expect(kOnlineTtsChunkChars, 600);
    });
  });

  group('PSRC-187 — TtsService đọc theo đoạn cho mọi engine ra file', () {
    late final String service;

    setUpAll(() {
      service = _code('lib/features/tts/tts_service.dart');
    });

    test('Piper: chia đoạn theo kPiperTtsChunkChars, tổng hợp TỪNG đoạn', () {
      final body = _between(
        service,
        'Future<bool> _trySpeakPiper(',
        'Future<bool> _trySpeakVieneu(',
      );
      expect(body.contains('_speakPreparedChunks('), isTrue);
      expect(body.contains('maxChars: kPiperTtsChunkChars'), isTrue);
      expect(RegExp(r'piper\.synthesize\(\s*text: chunk,').hasMatch(body),
          isTrue);
      expect(RegExp(r'piper\.synthesize\(\s*text: text,').hasMatch(body),
          isFalse,
          reason: 'đưa NGUYÊN dòng cho Piper là ca 3,4 GB RAM');
    });

    test('VieNeu và engine online cũng đi qua cùng một đường chia đoạn', () {
      final vieneu = _between(
        service,
        'Future<bool> _trySpeakVieneu(',
        'Future<VieneuImportResult> importVieneuModel(',
      );
      expect(vieneu.contains('_speakPreparedChunks('), isTrue);
      expect(RegExp(r'vieneu\.synthesize\(\s*text: chunk,').hasMatch(vieneu),
          isTrue);

      final online = _between(
        service,
        'Future<bool> _trySpeakOnline(',
        'void _prefetchOnline(',
      );
      expect(online.contains('_speakPreparedChunks('), isTrue);
      expect(online.contains('maxChars: kOnlineTtsChunkChars'), isTrue);
      expect(RegExp(r'\.synthesize\(\s*text: chunk,').hasMatch(online), isTrue);
    });

    test('đoạn KẾ được chuẩn bị trước khi đoạn hiện tại phát (không hở tiếng)',
        () {
      final body = _between(
        service,
        'Future<bool> _speakPreparedChunks(',
        'Future<bool> _trySpeakPiper(',
      );
      final prepareNext = body.indexOf('pending = safePrepare(chunks[i + 1])');
      final playCurrent = body.indexOf('await play(prepared)');
      expect(prepareNext, greaterThanOrEqualTo(0));
      expect(playCurrent, greaterThan(prepareNext));
    });

    test('engine hỏng giữa dòng ⇒ đọc nốt bằng giọng máy, không đọc lại từ đầu',
        () {
      final body = _between(
        service,
        'Future<bool> _speakPreparedChunks(',
        'Future<bool> _trySpeakPiper(',
      );
      expect(body.contains('if (i == 0) return false;'), isTrue,
          reason: 'chỉ trả false khi CHƯA phát được gì');
      expect(body.contains('chunks.sublist(from).join('), isTrue);
      expect(body.contains('_trySpeakOffline('), isTrue);
    });
  });

  group('PSRC-187 — VieNeu: nói thật về khả năng dùng được', () {
    tearDown(() => VieneuTtsCore.debugSetNativeLibraryProbe(null));

    test('engine: isAvailable cần CẢ thư viện native LẪN model, ở mọi lần gọi',
        () {
      final engine = _code('lib/features/tts/engines/vieneu_tts_engine.dart');
      // Thân hàm isAvailable() — tới dấu đóng ở mức thụt của method.
      final body = _between(
        engine,
        'Future<bool> isAvailable() async {',
        '\n  }\n',
      );
      // Không có model ⇒ false; có model ⇒ câu trả lời CHÍNH LÀ kết quả dò
      // thư viện native, hỏi lại ở mỗi lần gọi (engine không nhớ cờ "đã sẵn
      // sàng" nào giữa các lần gọi).
      expect(
        RegExp(r'if \(model == null\) \{[\s\S]*?return false;').hasMatch(body),
        isTrue,
      );
      expect(
        body.contains('return VieneuTtsCore.isNativeLibraryAvailable();'),
        isTrue,
        reason: 'có model nhưng thiếu thư viện native ⇒ không dùng được',
      );
      expect(engine.contains('_modelResolved'), isFalse,
          reason: 'bản cũ trả true từ lần gọi thứ hai dù thiếu thư viện');

      final init = _between(engine, 'Future<void> init({', 'Future<void> selectVoice(');
      final guard = init.indexOf('isNativeLibraryAvailable()');
      final nativeInit = init.indexOf('_core.init(');
      expect(guard, greaterThanOrEqualTo(0));
      expect(nativeInit, greaterThan(guard),
          reason: 'không có thư viện thì không được thử nạp');
    });

    test('lõi: không có thư viện native ⇒ init báo lỗi NGAY, không spawn gì',
        () async {
      VieneuTtsCore.debugSetNativeLibraryProbe(false);
      final core = VieneuTtsCore.instance;

      // Hai lần gọi đồng thời: lần sau CHỜ lần đang chạy rồi mới chạy lượt
      // của mình (hợp đồng của PSRC-183 — tham số có thể khác nhau). Cả hai
      // phải dừng ở chốt "không có thư viện", trước khi spawn bất cứ gì.
      final first = core.init(modelPath: '/khong/co/model.gguf');
      final second = core.init(modelPath: '/khong/co/model.gguf');
      final notBundled = throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not bundled'),
        ),
      );
      // Gắn người nhận lỗi cho CẢ HAI trước khi chờ.
      final firstFails = expectLater(first, notBundled);
      final secondFails = expectLater(second, notBundled);
      await firstFails;
      await secondFails;
      expect(core.isInitialized, isFalse);
      expect(await core.synthesize(text: 'xin chào', language: 'vi-VN'),
          isNull);
    });

    test('lõi: hỏi/đáp với worker THẬT chạy được — lỗi của worker về tới main',
        () async {
      // Ép "có thư viện" để đi qua bước spawn; worker kiểm file model TRƯỚC
      // khi nạp thư viện nên test không cần libvieneu_tts.
      VieneuTtsCore.debugSetNativeLibraryProbe(true);
      final core = VieneuTtsCore.instance;
      await expectLater(
        core
            .init(modelPath: '/khong/co/model.gguf')
            .timeout(const Duration(seconds: 30)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Không tìm thấy file model'),
          ),
        ),
        reason: 'giao thức cũ không bao giờ đưa được trả lời của worker về '
            'main (nghe hai lần trên một cổng; worker tự trả lời mình)',
      );
      expect(core.isInitialized, isFalse);

      // Thất bại xong vẫn thử lại được (không kẹt future cũ).
      await expectLater(
        core.init(modelPath: '/khong/co/model.gguf'),
        throwsStateError,
      );
    });

    test('WAV 16-bit: header đúng, mẫu được kẹp biên, NaN thành im lặng', () {
      final samples = Float32List.fromList(
        <double>[0, 1, -1, 0.5, double.nan, 2, -2],
      );
      final wav = encodeWav16MonoFloat(samples, 48000);
      final view = ByteData.sublistView(wav);

      expect(wav.length, 44 + samples.length * 2);
      expect(String.fromCharCodes(wav, 0, 4), 'RIFF');
      expect(view.getUint32(4, Endian.little), 36 + samples.length * 2);
      expect(String.fromCharCodes(wav, 8, 16), 'WAVEfmt ');
      expect(view.getUint16(20, Endian.little), 1); // PCM
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint32(24, Endian.little), 48000);
      expect(view.getUint32(28, Endian.little), 96000);
      expect(view.getUint16(32, Endian.little), 2);
      expect(view.getUint16(34, Endian.little), 16);
      expect(String.fromCharCodes(wav, 36, 40), 'data');
      expect(view.getUint32(40, Endian.little), samples.length * 2);
      expect(
        [
          for (var i = 0; i < samples.length; i++)
            view.getInt16(44 + i * 2, Endian.little),
        ],
        [0, 32767, -32767, 16384, 0, 32767, -32767],
      );
    });
  });

  group('PSRC-187 — câu báo "bản cài chưa kèm engine VieNeu" (rule #5)', () {
    test('màn cài đặt TTS dùng đúng chuỗi này và chỉ hiện khi thiếu engine', () {
      final settings =
          _code('lib/features/tts/widgets/tts_settings_section.dart');
      expect(
        settings.contains(
          "'Bản cài này chưa kèm engine VieNeu-TTS nên model đã import chưa "
          "đọc '",
        ),
        isTrue,
      );
      expect(settings.contains('context.uiText(kVieneuNativeMissingNotice)'),
          isTrue);
      expect(settings.contains('if (_nativeBundled == false)'), isTrue);
    });

    test('có đủ en + 7 ngôn ngữ ưu tiên, không rơi về tiếng Việt/English', () {
      final entry = generatedPriorityNativePack[_vieneuNotice];
      expect(entry, isNotNull,
          reason: 'thiếu trong tool/priority_native_pack.json');
      for (final locale in ['en', 'zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja']) {
        expect((entry![locale] ?? '').trim(), isNotEmpty, reason: locale);
        expect(entry[locale], contains('VieNeu'), reason: locale);
      }
      final english = entry!['en']!;
      for (final locale in ['zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja']) {
        final shown = AppUITranslations.translate(_vieneuNotice, locale);
        expect(shown, entry[locale]);
        expect(shown, isNot(english), reason: '$locale rơi về English');
        expect(shown, isNot(_vieneuNotice), reason: '$locale còn tiếng Việt');
      }
      // Locale chưa có bản dịch riêng ⇒ English, không bao giờ tiếng Việt.
      expect(AppUITranslations.translate(_vieneuNotice, 'de'), english);
      expect(AppUITranslations.translate(_vieneuNotice, 'en'), english);
      expect(AppUITranslations.translate(_vieneuNotice, 'vi'), _vieneuNotice);
    });
  });
}
