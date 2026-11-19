// test/tts/psrc171b_voice_disk_discovery_test.dart
//
// PSRC-171 (bổ sung) — "import giọng báo thành công mà giọng không hiện".
//
// Người dùng dùng một BẢN SAO gói VieNeu-TTS (mirror trên Hugging Face) thay
// cho gói gốc: `voices/<tên người đọc>/` vẫn có 2 file nhưng tên file khác bộ
// chuẩn (`codes.txt` / `embedding.txt`…). Engine cũ chỉ dò đúng 3 tên
// `ref_codes.txt` / `ref_codes.bin` / `speaker.emb.txt` ⇒ thư mục bị bỏ qua,
// danh sách giọng chỉ còn giọng mặc định, và \"không đọc được gì\".
//
// audio.cpp nhận ĐƯỜNG DẪN bất kỳ cho `reference_codes_file` /
// `speaker_embedding_file`, nên chỗ cần sửa chỉ là khâu nhận diện của Dart:
// nhận theo NỘI DUNG, và nói rõ lý do khi vẫn không dùng được.
//
// File này khoá ba thứ:
//   1. [classifyVieneuVoiceDataText] — nhận loại file bằng nội dung;
//   2. [resolveVieneuVoiceFiles] — tên chuẩn trước, nội dung sau, và
//      placeholder `# VieNeu-TTS default` KHÔNG được coi là giọng;
//   3. [diagnoseVieneuVoiceFolders] — lý do từng thư mục bị bỏ qua
//      (dùng cho mục \"Không thấy giọng vừa import?\" trong Cài đặt).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_model_files.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';
import 'package:path/path.dart' as p;

String _embedding192() => List<String>.generate(
      192,
      (i) => (i.isEven ? 0.01 * (i % 7) : -0.02 * (i % 5)).toStringAsFixed(4),
    ).join(',');

String _refCodes([int frames = 40]) => List<String>.generate(
      frames,
      (_) => '1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16',
    ).join('\n');

void main() {
  group('classifyVieneuVoiceDataText — nhận loại bằng nội dung', () {
    test('192 float có dấu chấm ⇒ speakerEmbedding', () {
      expect(
        classifyVieneuVoiceDataText(_embedding192()),
        VieneuVoiceDataKind.speakerEmbedding,
      );
    });

    test('dòng toàn số nguyên ⇒ refCodes', () {
      expect(
        classifyVieneuVoiceDataText(_refCodes()),
        VieneuVoiceDataKind.refCodes,
      );
    });

    test('ref codes một dòng, phân tách bằng dấu phẩy ⇒ vẫn là refCodes', () {
      expect(
        classifyVieneuVoiceDataText('12,42,7,300,1,2,3'),
        VieneuVoiceDataKind.refCodes,
      );
    });

    test('embedding 256 chiều (placeholder đời đầu) ⇒ unknown', () {
      final wrongDims = List<String>.generate(256, (i) => '0.0').join(',');
      expect(
        classifyVieneuVoiceDataText(wrongDims),
        VieneuVoiceDataKind.unknown,
      );
    });

    test('chỉ có comment placeholder ⇒ unknown', () {
      expect(
        classifyVieneuVoiceDataText('# VieNeu-TTS default\n'),
        VieneuVoiceDataKind.unknown,
      );
    });

    test('rỗng ⇒ unknown', () {
      expect(classifyVieneuVoiceDataText(''), VieneuVoiceDataKind.unknown);
    });
  });

  group('resolveVieneuVoiceFiles — tên chuẩn trước, nội dung sau', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('psrc171b_voice_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('tên chuẩn: ref_codes.txt + speaker.emb.txt', () async {
      final dir = Directory(p.join(tmp.path, 'minh_quan_pro'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'ref_codes.txt')).writeAsString(_refCodes());
      await File(p.join(dir.path, 'speaker.emb.txt'))
          .writeAsString('${_embedding192()}\n');

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.usable, isTrue);
      expect(resolved.resolvedByContent, isFalse);
      expect(p.basename(resolved.refCodesPath!), 'ref_codes.txt');
      expect(p.basename(resolved.speakerEmbeddingPath!), 'speaker.emb.txt');
    });

    test('mirror cộng đồng: codes.txt + embedding.txt vẫn nhận ra', () async {
      final dir = Directory(p.join(tmp.path, 'ngoc_huyen'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'codes.txt')).writeAsString(_refCodes());
      await File(p.join(dir.path, 'embedding.txt'))
          .writeAsString(_embedding192());

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.usable, isTrue, reason: 'phải nhận theo nội dung');
      expect(resolved.resolvedByContent, isTrue);
      expect(p.basename(resolved.refCodesPath!), 'codes.txt');
      expect(p.basename(resolved.speakerEmbeddingPath!), 'embedding.txt');
      // Cùng một định nghĩa với đường import ⇒ import cũng phải thấy giọng này.
      expect(await folderHasVieneuVoiceData(dir), isTrue);
    });

    test('chỉ có file mã (không embedding) vẫn dùng được', () async {
      final dir = Directory(p.join(tmp.path, 'chi_codes'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'voice.codes.csv'))
          .writeAsString(_refCodes());

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.usable, isTrue);
      expect(resolved.refCodesPath, isNotNull);
      expect(resolved.speakerEmbeddingPath, isNull);
    });

    test('chỉ có mẫu WAV ⇒ vẫn là GIỌNG, nhưng phải mã hoá trước khi đọc',
        () async {
      final dir = Directory(p.join(tmp.path, 'chi_wav'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'sample.wav'))
          .writeAsBytes(List<int>.filled(4096, 0));

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.usable, isFalse, reason: 'Chưa có mã sẵn');
      expect(resolved.samplePath, isNotNull);
      expect(resolved.isVoice, isTrue, reason: 'Có mẫu ⇒ vẫn phải hiện ra');
      expect(await folderHasVieneuVoiceData(dir), isTrue,
          reason: 'Import phải nhận, nếu không giọng không bao giờ được copy');
    });

    test('gói giọng upstream: <Tên>.pt + <Tên>.txt + <Tên>.wav', () async {
      // Đây đúng là dạng thư mục trong các gói/mirror của VieNeu-TTS: ba file
      // KHÔNG có tên `ref_codes.txt` / `speaker.emb.txt`.
      final dir = Directory(p.join(tmp.path, 'Bình (nam miền Bắc)'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'Bình (nam miền Bắc).pt'))
          .writeAsBytes(List<int>.filled(512, 7));
      await File(p.join(dir.path, 'Bình (nam miền Bắc).txt'))
          .writeAsString('Xin chào, tôi là Bình.');
      await File(p.join(dir.path, 'Bình (nam miền Bắc).wav'))
          .writeAsBytes(List<int>.filled(8192, 0));

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.isVoice, isTrue);
      expect(resolved.samplePath, endsWith('.wav'));
      expect(
        p.basename(resolved.samplePath!),
        'Bình (nam miền Bắc).wav',
        reason: 'Tên file giữ nguyên — native nhận đường dẫn bất kỳ',
      );

      final report = await diagnoseVieneuVoiceFolders(tmp);
      final entry = report.firstWhere((d) => d.name.startsWith('Bình'));
      expect(entry.status, VieneuVoiceFolderStatus.sampleOnly);
    });

    test('placeholder comment ⇒ KHÔNG dùng được', () async {
      final dir = Directory(p.join(tmp.path, 'placeholder'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'ref_codes.txt'))
          .writeAsString('# VieNeu-TTS default\n');

      expect(await folderHasVieneuVoiceData(dir), isFalse);
    });

    test('embedding sai số chiều không được đưa xuống native', () async {
      final dir = Directory(p.join(tmp.path, 'sai_chieu'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'speaker.emb.txt'))
          .writeAsString(List<String>.generate(256, (_) => '0.0').join(','));

      final resolved = await resolveVieneuVoiceFiles(dir);
      expect(resolved.speakerEmbeddingPath, isNull);
      expect(resolved.usable, isFalse);
    });
  });

  group('engine — giọng chỉ có mẫu WAV được mã hoá khi dùng', () {
    final engine = File('lib/features/tts/engines/vieneu_tts_engine.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('selectVoice mã hoá mẫu trước khi nạp giọng', () {
      expect(engine.contains('_materializeSample('), isTrue);
      expect(
        engine.contains('final files = await _materializeSample(_voiceIndex[voiceId]);'),
        isTrue,
        reason: 'Không mã hoá thì giọng wav-only sẽ đọc bằng giọng mặc định',
      );
    });

    test('mã hoá dùng lại đường clone của native, không tự viết lại', () {
      expect(engine.contains('_core.cloneVoice('), isTrue);
      expect(engine.contains('encode_reference_only'), isFalse,
          reason: 'Đó là việc của native, Dart không gọi thẳng');
      expect(engine.contains('_encode_sample'), isTrue,
          reason: 'Thư mục tạm phải có tiền tố _ để không bị quét thành giọng');
    });
  });

  group('diagnoseVieneuVoiceFolders — nói rõ vì sao không hiện', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('psrc171b_diag_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('phân loại được 4 trạng thái', () async {
      final ok = Directory(p.join(tmp.path, 'ok_voice'));
      await ok.create(recursive: true);
      await File(p.join(ok.path, 'codes.txt')).writeAsString(_refCodes());

      final broken = Directory(p.join(tmp.path, 'broken_voice'));
      await broken.create(recursive: true);
      await File(p.join(broken.path, 'embedding.txt'))
          .writeAsString(List<String>.generate(256, (_) => '0.5').join(','));

      final emptyFolder = Directory(p.join(tmp.path, 'empty_voice'));
      await emptyFolder.create(recursive: true);

      final noData = Directory(p.join(tmp.path, 'photos_only'));
      await noData.create(recursive: true);
      await File(p.join(noData.path, 'cover.png')).writeAsBytes([1, 2, 3, 4]);

      final report = await diagnoseVieneuVoiceFolders(tmp);
      final byName = {for (final d in report) d.name: d};

      expect(byName['ok_voice']!.status, VieneuVoiceFolderStatus.usable);
      expect(byName['ok_voice']!.resolvedByContent, isTrue);
      expect(byName['broken_voice']!.status,
          VieneuVoiceFolderStatus.unknownFormat);
      expect(byName['empty_voice']!.status,
          VieneuVoiceFolderStatus.emptyFolder);
      expect(byName['photos_only']!.status, VieneuVoiceFolderStatus.noDataFile);
      expect(byName['ok_voice']!.fileNames, contains('codes.txt'));
    });

    test('thư mục không tồn tại ⇒ danh sách rỗng (không ném)', () async {
      final report =
          await diagnoseVieneuVoiceFolders(Directory(p.join(tmp.path, 'khong_co')));
      expect(report, isEmpty);
    });
  });
}
