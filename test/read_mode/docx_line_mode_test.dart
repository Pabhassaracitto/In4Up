// I4U18-READ-IPA-001 (Agent F · F1) — chế độ dòng khi mở Word/DOCX.
//
// Lỗi gốc: `docxXmlToPlainText` xuất ranh giới đoạn bằng MỘT `\n`, còn
// `TextSplitterService` (chế độ smart — mặc định của tab Đọc) chỉ coi
// `\n\s*\n` là ranh giới cứng. Hệ quả: các đoạn Word không kết bằng dấu
// `.`/`!`/`?` (tiêu đề, kệ, gạch đầu dòng, thơ) bị DÍNH lại thành một "dòng"
// khổng lồ → chạm dòng không ra IPA/tra từ theo dòng.
//
// Test này khoá hành vi đúng ở CẢ HAI tầng: text_source_loader xuất dòng
// trống, và splitter cho ra đúng số dòng đọc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/text_device_entry.dart';
import 'package:in4up/providers/text_device_provider.dart';
import 'package:in4up/services/text_device_channel.dart';
import 'package:in4up/services/text_source_loader.dart';
import 'package:in4up/services/text_splitter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DOCX → chế độ dòng', () {
    test('mỗi đoạn Word là một ranh giới cứng (dòng trống)', () {
      const xml = '''
<w:p><w:r><w:t>Kinh Chuyển Pháp Luân</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần một</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần hai</w:t></w:r></w:p>
''';

      expect(
        TextSourceLoader.docxXmlToPlainText(xml),
        'Kinh Chuyển Pháp Luân\n\nPhần một\n\nPhần hai',
      );
    });

    test('ba đoạn KHÔNG có dấu câu vẫn ra ba dòng đọc (lỗi cũ: 1 dòng)', () {
      const xml = '''
<w:p><w:r><w:t>Kinh Chuyển Pháp Luân</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần một</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần hai</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      final lines = TextSplitterService.split(text, mode: SplitMode.smart);

      expect(lines, [
        'Kinh Chuyển Pháp Luân',
        'Phần một',
        'Phần hai',
      ]);
    });

    test('xuống dòng mềm (Shift+Enter) cũng là một dòng đọc', () {
      const xml = '''
<w:p><w:r><w:t>Dòng trên</w:t></w:r><w:br/><w:r><w:t>Dòng dưới</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Dòng trên', 'Dòng dưới'],
      );
    });

    test('đoạn văn xuôi nhiều câu vẫn tách theo câu như cũ', () {
      const xml = '''
<w:p><w:r><w:t>Câu một. Câu hai! Câu ba?</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Câu một.', 'Câu hai!', 'Câu ba?'],
      );
    });

    test('nhiều đoạn trống liên tiếp không sinh dòng rỗng', () {
      const xml = '''
<w:p><w:r><w:t>Trên</w:t></w:r></w:p>
<w:p></w:p>
<w:p></w:p>
<w:p><w:r><w:t>Dưới</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Trên', 'Dưới'],
      );
    });

    test('run bị Word cắt nhỏ trong CÙNG đoạn vẫn nối lại thành một dòng', () {
      const xml = '''
<w:p>
  <w:r><w:t>ng</w:t></w:r>
  <w:r><w:t>ườ</w:t></w:r>
  <w:r><w:t>i</w:t></w:r>
  <w:r><w:t xml:space="preserve"> </w:t></w:r>
  <w:r><w:t>Việt</w:t></w:r>
</w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(TextSplitterService.split(text, mode: SplitMode.smart),
          ['người Việt']);
    });
  });

  group('PSRC-206 — quét thư mục lớn không treo UI', () {
    tearDown(() {
      TextDeviceChannel.invokeOverride = null;
    });

    test('MainActivity chạy scanTree/copyContentToCache ngoài UI thread và đóng Cursor trước khi đệ quy', () {
      final kt = File('android/app/src/main/kotlin/com/in4up/MainActivity.kt')
          .readAsStringSync();
      expect(kt.contains('textScanExecutor.execute'), isTrue);
      expect(kt.contains('"cancelScanTree"'), isTrue);
      expect(kt.contains('val childDirectories = ArrayList<Pair<String, String>>()'),
          isTrue);

      final libraryUi = File('lib/screens/read_mode/widgets/library_screen.dart')
          .readAsStringSync();
      expect(libraryUi.contains('SliverList.builder('), isTrue);
      expect(libraryUi.contains('else ...results.map('), isFalse);
    });

    test('parseAndSortEntries + searchKey xử lý danh sách lớn nhanh và đúng thứ tự', () {
      final raw = List<Map<String, dynamic>>.generate(
        2500,
        (i) => <String, dynamic>{
          'uri': 'content://doc/$i',
          'name': 'Tai_lieu_$i.docx',
          'relativePath': 'ThuMuc_${i % 10}/Tai_lieu_$i.docx',
          'sizeBytes': 1024 * (i + 1),
          'dateModifiedMs': 1700000000000 + i * 1000,
          'ext': 'docx',
        },
      );

      final parsed = TextDeviceEntry.parseAndSortEntries(raw);
      expect(parsed.length, 2500);
      expect(parsed.first.name, 'Tai_lieu_2499.docx');
      expect(parsed.last.name, 'Tai_lieu_0.docx');
      expect(parsed.first.title, 'Tai_lieu_2499');
      expect(parsed.first.searchKey, contains('thumuc_9/tai_lieu_2499.docx'));
    });

    test('TextDeviceProvider báo tiến độ và hủy quét giữa chừng an toàn', () async {
      SharedPreferences.setMockInitialValues({
        'in4up_read_device_tree_uri_v1':
            'content://com.android.externalstorage.documents/tree/primary%3ABooks',
      });
      final scanCompleter = Completer<List<Object?>>();
      final cancelledIds = <String>[];
      String? capturedScanId;

      TextDeviceChannel.invokeOverride = (method, [arguments]) async {
        if (method == 'scanTree') {
          capturedScanId = arguments?['scanId'] as String?;
          return scanCompleter.future;
        }
        if (method == 'cancelScanTree') {
          cancelledIds.add((arguments?['scanId'] ?? '').toString());
          return true;
        }
        return null;
      };

      final provider = TextDeviceProvider(supportedOverride: true);
      await provider.init();

      final scanFuture = provider.scan();
      await Future<void>.delayed(Duration.zero);
      expect(provider.isScanning, isTrue);
      expect(capturedScanId, isNotNull);

      TextDeviceChannel.dispatchProgressForTesting(
        scanId: capturedScanId!,
        count: 350,
        folder: 'Sub/',
      );
      expect(provider.scannedProgressCount, 350);

      await provider.cancelScan();
      expect(provider.isScanning, isFalse);
      expect(cancelledIds, [capturedScanId]);

      scanCompleter.complete([
        {
          'uri': 'content://doc/late',
          'name': 'Late.txt',
          'sizeBytes': 12,
          'dateModifiedMs': 1000,
          'ext': 'txt',
        },
      ]);
      await scanFuture;
      expect(provider.entries, isEmpty,
          reason: 'Kết quả về muộn của lượt quét đã hủy không được ghi đè');
    });
  });

  group('PSRC-207 — mở tài liệu .docx thực tế trong tab đọc', () {
    test('giải nén .docx bật bit 3 (data descriptor, compSize=0 ở local header) qua Central Directory', () {
      // Kịch bản thực tế từ Google Docs / Java ZipOutputStream / LibreOffice:
      // local header để compSize=0, kèm data descriptor 12 byte không chữ ký,
      // thậm chí payload ảnh đứng trước vô tình chứa chuỗi byte giống PK\x01\x02.
      final fakeMediaWithZipMagic = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47,
        0x50, 0x4B, 0x01, 0x02, // bẫy cho bộ quét chữ ký cũ
        0xAA, 0xBB, 0xCC,
      ]);
      final docXml = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>'
        '<w:p><w:r><w:t>Chương 1: Mở đầu</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Nội dung tiếng Việt đầy đủ.</w:t></w:r></w:p>'
        '</w:body></w:document>',
      );
      final zipBytes = _buildStreamingCentralDirZip({
        'word/media/image1.png': fakeMediaWithZipMagic,
        'word/document.xml': Uint8List.fromList(docXml),
      });

      expect(
        TextSourceLoader.docxToPlainText(zipBytes),
        'Chương 1: Mở đầu\n\nNội dung tiếng Việt đầy đủ.',
      );
    });

    test('tự tìm main part word/document2.xml qua [Content_Types].xml', () {
      final contentTypes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Override PartName="/word/document2.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>',
      );
      final mainXml = utf8.encode(
        '<document xmlns="http://purl.oclc.org/ooxml/wordprocessingml/main">'
        '<body><p><r><t>Tài liệu Strict OOXML</t></r></p></body></document>',
      );
      final zipBytes = _buildStreamingCentralDirZip({
        '[Content_Types].xml': Uint8List.fromList(contentTypes),
        'word/document2.xml': Uint8List.fromList(mainXml),
      });

      expect(TextSourceLoader.docxToPlainText(zipBytes), 'Tài liệu Strict OOXML');
    });

    test('bỏ trùng lặp <mc:Fallback>, bỏ <w:del>, hỗ trợ namespace tùy ý và entity >0xFFFF', () {
      const xml = '''
<ns0:document xmlns:ns0="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
              xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
  <ns0:body>
    <ns0:p>
      <mc:AlternateContent>
        <mc:Choice><ns0:r><ns0:t>Khung chữ duy nhất</ns0:t></ns0:r></mc:Choice>
        <mc:Fallback><ns0:r><ns0:t>Khung chữ bị nhân đôi</ns0:t></ns0:r></mc:Fallback>
      </mc:AlternateContent>
    </ns0:p>
    <ns0:p>
      <ns0:del><ns0:r><ns0:t>Chữ đã xoá </ns0:t></ns0:r></ns0:del>
      <ns0:r><ns0:t>Sách &#x1F4D6;</ns0:t></ns0:r>
    </ns0:p>
  </ns0:body>
</ns0:document>
''';

      expect(
        TextSourceLoader.docxXmlToPlainText(xml),
        'Khung chữ duy nhất\n\nSách 📖',
      );
    });

    test('mở được file .docx mất đuôi trong cache SAF và phân biệt .docx khóa mật khẩu / chỉ có ảnh', () async {
      final dir = await Directory.systemTemp.createTemp('psrc207_docx_');
      addTearDown(() => dir.delete(recursive: true));

      final docxBytes = _buildStreamingCentralDirZip({
        'word/document.xml': Uint8List.fromList(
          utf8.encode('<w:p><w:r><w:t>Đọc từ file tạm mất đuôi</w:t></w:r></w:p>'),
        ),
      });
      final noExtFile = File('${dir.path}/msf_10002391');
      await noExtFile.writeAsBytes(docxBytes);

      expect(
        await TextSourceLoader.extractReadableText(noExtFile.path),
        'Đọc từ file tạm mất đuôi',
      );

      final encryptedBytes = Uint8List.fromList([
        0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1,
        ...'EncryptedPackage'.codeUnits,
      ]);
      expect(
        TextSourceLoader.diagnoseOpenFailureBytes(encryptedBytes, path: 'secret.docx'),
        TextSourceLoader.encryptedDocxHint,
      );

      final imageOnlyBytes = _buildStreamingCentralDirZip({
        'word/document.xml': Uint8List.fromList(
          utf8.encode('<w:document><w:body><w:p><w:r><w:drawing/></w:r></w:p></w:body></w:document>'),
        ),
      });
      expect(
        TextSourceLoader.diagnoseOpenFailureBytes(imageOnlyBytes, path: 'scan.docx'),
        TextSourceLoader.imageOnlyDocxHint,
      );
    });
  });
}

Uint8List _buildStreamingCentralDirZip(Map<String, Uint8List> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();

  void u16(BytesBuilder b, int v) {
    b.addByte(v & 0xff);
    b.addByte((v >> 8) & 0xff);
  }

  void u32(BytesBuilder b, int v) {
    b.addByte(v & 0xff);
    b.addByte((v >> 8) & 0xff);
    b.addByte((v >> 16) & 0xff);
    b.addByte((v >> 24) & 0xff);
  }

  var count = 0;
  entries.forEach((entryPath, uncompressed) {
    count++;
    final localOffset = out.length;
    final nameBytes = utf8.encode(entryPath);
    final compressed = Uint8List.fromList(
      ZLibEncoder(raw: true).convert(uncompressed),
    );

    // Local file header với bit 3 bật và compSize = 0 (streaming ZIP)
    out.add([0x50, 0x4B, 0x03, 0x04]);
    u16(out, 20);
    u16(out, 0x0008); // hasDataDescriptor
    u16(out, 8); // deflate
    u16(out, 0);
    u16(out, 0);
    u32(out, 0);
    u32(out, 0); // compSize = 0 ở local header
    u32(out, 0); // uncompSize = 0 ở local header
    u16(out, nameBytes.length);
    u16(out, 0);
    out.add(nameBytes);
    out.add(compressed);
    // Data descriptor 12 byte KHÔNG kèm chữ ký PK\x07\x08
    u32(out, 0);
    u32(out, compressed.length);
    u32(out, uncompressed.length);

    // Central Directory header (luôn có kích thước thật)
    central.add([0x50, 0x4B, 0x01, 0x02]);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0x0008);
    u16(central, 8);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, compressed.length);
    u32(central, uncompressed.length);
    u16(central, nameBytes.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, localOffset);
    central.add(nameBytes);
  });

  final cdOffset = out.length;
  final cdBytes = central.toBytes();
  out.add(cdBytes);

  // End of Central Directory (PK\x05\x06)
  out.add([0x50, 0x4B, 0x05, 0x06]);
  u16(out, 0);
  u16(out, 0);
  u16(out, count);
  u16(out, count);
  u32(out, cdBytes.length);
  u32(out, cdOffset);
  u16(out, 0);
  return out.toBytes();
}
