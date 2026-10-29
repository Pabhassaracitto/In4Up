// CABIN-SAVE-001 (PLAN-030) — lưu phiên Cabin: LRC/TXT, header WAV,
// lưu / bỏ / khôi phục phiên bị tắt ngang.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';
import 'package:in4up/features/cabin/services/cabin_transcript_exporter.dart';
import 'package:in4up/features/cabin/services/cabin_wav_writer.dart';

const _entries = [
  CabinTranscriptEntry(
    offset: Duration(seconds: 65, milliseconds: 430),
    sourceText: 'Xin chào',
    translatedText: 'Hello',
  ),
  CabinTranscriptEntry(
    offset: Duration(seconds: 2),
    sourceText: 'Câu một\ncó xuống dòng',
    translatedText: 'Sentence one',
  ),
];

void main() {
  group('CabinTranscriptExporter', () {
    test('formatTimestamp mm:ss.cc', () {
      expect(CabinTranscriptExporter.formatTimestamp(Duration.zero),
          '[00:00.00]');
      expect(
          CabinTranscriptExporter.formatTimestamp(
              const Duration(minutes: 1, seconds: 5, milliseconds: 437)),
          '[01:05.43]');
      expect(
          CabinTranscriptExporter.formatTimestamp(
              const Duration(milliseconds: -50)),
          '[00:00.00]');
    });

    test('LRC song ngữ: sắp theo thời gian, gốc trước dịch, 1 dòng/mục', () {
      final lrc = CabinTranscriptExporter.buildLrc(
          _entries, CabinTextMode.bilingual,
          title: 'Phiên A');
      final lines = lrc.trim().split('\n');
      expect(lines.first, '[ti:Phiên A]');
      final timed = lines.where((l) => l.startsWith('[0')).toList();
      expect(timed, [
        '[00:02.00]Câu một có xuống dòng',
        '[00:02.01]Sentence one',
        '[01:05.43]Xin chào',
        '[01:05.44]Hello',
      ]);
    });

    test('LRC chỉ gốc / chỉ dịch', () {
      final src =
          CabinTranscriptExporter.lines(_entries, CabinTextMode.source);
      expect(src.map((e) => e.$2), ['Câu một có xuống dòng', 'Xin chào']);
      final tgt =
          CabinTranscriptExporter.lines(_entries, CabinTextMode.target);
      expect(tgt.map((e) => e.$2), ['Sentence one', 'Hello']);
    });

    test('bản dịch trống ⇒ chế độ dịch dùng câu gốc, song ngữ không lặp', () {
      const e = [
        CabinTranscriptEntry(offset: Duration.zero, sourceText: 'Pāli'),
      ];
      expect(
          CabinTranscriptExporter.lines(e, CabinTextMode.target)
              .map((x) => x.$2),
          ['Pāli']);
      expect(
          CabinTranscriptExporter.lines(e, CabinTextMode.bilingual).length, 1);
    });

    test('LRC đúng regex parser Đọc của app', () {
      final re = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
      final lrc =
          CabinTranscriptExporter.buildLrc(_entries, CabinTextMode.bilingual);
      final matched =
          lrc.split('\n').where((l) => re.hasMatch(l)).toList();
      expect(matched.length, 4);
    });
  });

  group('CabinWavWriter', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cabin_wav_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('header 44 byte chuẩn PCM16 16k mono', () {
      final h = CabinWavWriter.buildHeader(32000);
      final bd = ByteData.sublistView(h);
      expect(ascii.decode(h.sublist(0, 4)), 'RIFF');
      expect(bd.getUint32(4, Endian.little), 36 + 32000);
      expect(ascii.decode(h.sublist(8, 12)), 'WAVE');
      expect(bd.getUint16(22, Endian.little), 1);
      expect(bd.getUint32(24, Endian.little), 16000);
      expect(bd.getUint32(28, Endian.little), 32000);
      expect(bd.getUint32(40, Endian.little), 32000);
    });

    test('ghi streaming + close vá kích thước; duration theo byte', () async {
      final path = '${tmp.path}/a.wav';
      final w = await CabinWavWriter.open(path);
      w.add(Uint8List(16000));
      w.add(Uint8List(16000));
      expect(w.duration, const Duration(seconds: 1));
      await w.close();
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, 44 + 32000);
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 32000);
    });

    test('repairHeader: file bị cắt ngang (header 0, byte lẻ)', () async {
      final path = '${tmp.path}/b.wav';
      File(path).writeAsBytesSync([
        ...CabinWavWriter.buildHeader(0),
        ...List.filled(1001, 0),
      ]);
      final data = await CabinWavWriter.repairHeader(path);
      expect(data, 1000);
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, 1044);
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 1000);
    });
  });

  group('CabinSessionStore', () {
    late Directory tmp;
    final store = CabinSessionStore.instance;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('cabin_store_');
      store.debugRootOverride = tmp.path;
    });
    tearDown(() {
      store.debugRootOverride = null;
      tmp.deleteSync(recursive: true);
    });

    Future<CabinSession> makeSession(
        {required CabinSessionStatus status, bool audio = true}) async {
      final dir = await store.createSessionDir(DateTime(2026, 9, 25, 10, 0));
      final id = dir.path.split(RegExp(r'[\\/]')).last;
      final s = CabinSession(
        id: id,
        dirPath: dir.path,
        title: 'Test',
        createdAt: DateTime(2026, 9, 25, 10),
        sourceLang: 'vi',
        targetLang: 'en',
        status: status,
        hasAudio: audio,
      );
      File(s.journalPath).writeAsStringSync(
        '${_entries.map((e) => jsonEncode(e.toJson())).join('\n')}\n{"ms":12',
      );
      if (audio) {
        File(s.audioPath).writeAsBytesSync([
          ...CabinWavWriter.buildHeader(0),
          ...List.filled(64000, 0),
        ]);
      }
      await store.writeMeta(s);
      return s;
    }

    test('journal cụt dòng cuối vẫn đọc được các câu hợp lệ', () async {
      final s = await makeSession(status: CabinSessionStatus.unsaved);
      expect((await store.loadEntries(s)).length, 2);
    });

    test('recoverInterrupted: vá WAV, dựng LRC, chuyển unsaved', () async {
      final s = await makeSession(status: CabinSessionStatus.recording);
      final rec = await store.recoverInterrupted();
      expect(rec.length, 1);
      final r = rec.single;
      expect(r.status, CabinSessionStatus.unsaved);
      expect(r.recovered, isTrue);
      expect(r.duration, const Duration(seconds: 2));
      expect(r.entryCount, 2);
      expect(File(s.lrcPath).existsSync(), isTrue);
      // Phiên đang chạy thì KHÔNG đụng.
      final s2 = await makeSession(status: CabinSessionStatus.recording);
      expect(await store.recoverInterrupted(activeId: s2.id), isEmpty);
    });

    test('save: đổi tên + chế độ chỉ dịch + bỏ audio', () async {
      final s = await makeSession(status: CabinSessionStatus.unsaved);
      final saved = await store.save(s,
          title: 'Bài giảng', textMode: CabinTextMode.target, keepAudio: false);
      expect(saved, isNotNull);
      expect(saved!.status, CabinSessionStatus.saved);
      expect(saved.hasAudio, isFalse);
      expect(File(s.audioPath).existsSync(), isFalse);
      final lrc = File(saved.lrcPath).readAsStringSync();
      expect(lrc, contains('[ti:Bài giảng]'));
      expect(lrc, contains('Hello'));
      expect(lrc, isNot(contains('Xin chào')));
      final listed = await store.list();
      expect(listed.single.title, 'Bài giảng');
    });

    test('save bỏ cả audio lẫn text ⇒ xoá phiên', () async {
      final s = await makeSession(status: CabinSessionStatus.unsaved);
      final saved = await store.save(s,
          title: '',
          textMode: CabinTextMode.bilingual,
          keepAudio: false,
          keepText: false);
      expect(saved, isNull);
      expect(Directory(s.dirPath).existsSync(), isFalse);
    });

    test('WAV và LRC cùng tên gốc (tab Nghe tự tìm sidecar)', () async {
      final s = await makeSession(status: CabinSessionStatus.unsaved);
      String stem(String p) => p.substring(0, p.lastIndexOf('.'));
      expect(stem(s.audioPath), stem(s.lrcPath));
    });
  });
}
